# coding: utf-8

# == Schema Information
#
# Table name: event_groups
#
#  id                                                                                          :bigint           not null, primary key
#  end_date(if null, end date is undefined.)                                                   :date
#  end_date_err(Error of end-date in day. 182 or 183 days for one with only a known year.)     :integer
#  note                                                                                        :text
#  order_no(Serial number for a series of Event Group, e.g., 5(-th))                           :integer
#  start_date(if null, start date is undefined.)                                               :date
#  start_date_err(Error of start-date in day. 182 or 183 days for one with only a known year.) :integer
#  created_at                                                                                  :datetime         not null
#  updated_at                                                                                  :datetime         not null
#  place_id                                                                                    :bigint
#
# Indexes
#
#  index_event_groups_on_end_date    (end_date)
#  index_event_groups_on_order_no    (order_no)
#  index_event_groups_on_place_id    (place_id)
#  index_event_groups_on_start_date  (start_date)
#
# Foreign Keys
#
#  fk_rails_...  (place_id => places.id) ON DELETE => nullify
#
class EventGroup < BaseWithTranslation
  # @note See {#delete_remaining_unknwon_event_callback} and its docs
  #    to see how {ApplicationRecord.allow_destroy_all} affects behaviours
  #    of the destroy action.

  # defines {#unknown?} and +self.class.unknown+
  include ModuleUnknown

  before_create :add_place_in_create_callback
  before_destroy :delete_remaining_unknwon_event_callback  # must come before has_many
  # NOTE: after_first_translation_hook

  # For the translations to be unique (required by BaseWithTranslation).
  MAIN_UNIQUE_COLS = []

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" when "The Beatles" is passed.  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = true

  belongs_to :place, optional: true
  has_one :prefecture, through: :place
  has_one :country, through: :prefecture
  has_many :events, dependent: :restrict_with_exception  # EventGroup should not be deleted easily.
  has_many :event_items, through: :events, dependent: :restrict_with_exception
  has_many :harami_vids, through: :event_items, dependent: :restrict_with_exception
  has_many :harami1129s, through: :event_items, dependent: :restrict_with_exception

  attr_accessor :mname  # defined occasionally for later use (by the caller).

  UNKNOWN_TITLES = UnknownEventGroup = {
    "en" => 'UncategorizedEventGroup',
    "ja" => 'その他のイベント類',
    "fr" => "Groupe d'événements non classé",
  }.with_indifferent_access

  # Contexts that are taken into account in {EventGroup.default}
  VALID_CONTEXTS_FOR_DEFAULT = ["harami_vid", "harami1129", nil]

  # The Regexps to identify existing (seeded) EvengGroups; see /db/seeds/seeds_event_group.rb
  #
  # The key is mname.
  REGEXP_IDENTIFY_EVGR = {
    single_streets: /(単発.*|独立)ストリート(ピアノ|演奏)|street +(music|play)/i,
    street_events: /street +event/i,
    harami_guests: /ハラミちゃんゲスト|HARAMIchan.+guest|guest.+HARAMIchan/i,
    harami_concerts: /ハラミちゃん主催|single-shot +solo/i,
    live_streamings: /^(生配信|Live[\- ]stream(ings?)?\b)/i,
    radio: /^(ラジオ局|\bradio\b.+\b(station|studio)s?\b)/i,
    tv: /^(テレビ局|\b(television|tv)\b.+\b(station|studio)s?\b)/i,
    paris2023: /パリ.*2023|2023.*パリ|\bParis\b.+\b2023/i,
    uk2024: /(英国|イギリス|イングランド|ロンドン|UK(訪問|.+旅)).*2024|2024.*(英国|イギリス|イングランド|ロンドン|UK(訪問|.+旅))|\bLondon\b.+\b2024/i,
  }.with_indifferent_access

  # Validates if a {Translation} is unique within the parent
  #
  # Fired from {Translation}
  # @param record [Translation]
  def validate_translation_callback(record)
    validate_translation_unique_within_parent(record)
  end

  %i(start_date_err end_date_err).each do |ec|
    validates ec, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  end

  validate :start_end_dates_order_must_be_valid

  # Check the order for validation
  def start_end_dates_order_must_be_valid
    if (start_date.present? && 
        start_date_err.present? && 
        end_date.present? && 
        end_date_err.present?)
      if (  end_date + end_date_err.day <
          start_date - start_date_err.day)
        msg = "start_date can't be later than end_date beyond the errors"
        ch_attrs = changed_attributes  # like {"order_no"=>nil} ("nil" is the value before changed)
        flagchanged = false
        %w(start_date start_date_err end_date end_date_err).each do |ek|
          if ch_attrs.has_key?(ek)
            errors.add(ek.to_sym, msg)
            flagchanged = true
          end
        end
        errors.add(:start_date, msg) if !flagchanged
      end
    end
  end

  alias_method :uncategorized?, :unknown? if ! self.method_defined?(:uncategorized?)


  # Unknown {Event} belonging to self
  #
  # @return [Event]
  def unknown_event
    events.joins(:translations).where("translations.langcode='en' AND translations.title = ?", Event::UNKNOWN_TITLES['en']).first
  end

  # Unknown {EventGroup}
  #
  # @return [EventGroup]
  def unknown_sibling
    self.class.unknown
  end

  # Returning a default EventGroup in the given context
  #
  # See {EventGroup.guessed_best_or_nil} for keywords.
  #
  # @option context [Symbol, String]
  # @return [EventItem, Event]
  def self.default(context=nil, **kwd)
    guessed = guessed_best_or_nil(context, **kwd)
    return guessed if guessed

    case context.to_s.underscore.singularize
    when *(%w(harami_vid harami1129))  # see VALID_CONTEXTS_FOR_DEFAULT
      ret = (self.select_regex(:title, /single-?shot +street(-?piano)? +play(ing|s)?/i, langcode: "en", sql_regexp: true).first ||
             self.select_regex(:title, /単発ストリート(ピアノ)?の?演奏/i, langcode: "ja", sql_regexp: true).first)
      if ret
        ret.mname = "single_streets"
        return ret
      end
      logger.warn("WARNING(#{__FILE__}:#{__method__}): Failed to identify the default Streetpiano EvengGroup!")
    end

    self.unknown
  end

  # Returning the best-guess EventGroup in the given conditions.
  #
  # If nothing particularly likely is found, nil is returned.
  #
  # @option context [Symbol, String]
  # @param place: [Place]
  # @param ref_title: [String] Title of HaramiVid etc.
  # @param year: [Integer]
  # @return [EventGroup, NilClass]
  def self.guessed_best_or_nil(context=nil, place: nil, ref_title: nil, year: nil)
    ref_title = nil if ref_title.blank? || ref_title.strip.blank?

    evgr_cands = REGEXP_IDENTIFY_EVGR.map{|ek, ea_re|
      [ek, select_regex(:titles, ea_re, sql_regexp: true).first]
    }.to_h.with_indifferent_access

    if ref_title && /生配信/ =~ ref_title && (evgr=evgr_cands[k=:live_streamings])
      evgr.mname = k.to_s
      return evgr
    elsif ref_title && /テレビ/ =~ ref_title && (evgr=evgr_cands[k=:tv])
      evgr.mname = k.to_s
      return evgr
    elsif ref_title && /ラジオ/ =~ ref_title && (evgr=evgr_cands[k=:radio])
      evgr.mname = k.to_s
      return evgr
    end

    if (ref_title && /パリ|フランス/ =~ ref_title || place && (cnt=Country.find_by(iso3166_n3_code: 250)) && cnt.encompass?(place)) && (evgr=evgr_cands[k=:paris2023]) && (!year || year && (2023..2028).cover?(year))
      evgr.mname = k.to_s
      return evgr
    elsif (ref_title && /(英国|イギリス|イングランド|ロンドン|ブリティッシュ)/ =~ ref_title || place && (cnt=Country.find_by(iso3166_n3_code: 826)) && cnt.encompass?(place)) && (evgr=evgr_cands[k=:uk2024]) && (!year || year && (2024..2029).cover?(year))
      evgr.mname = k.to_s
      return evgr
    end

    nil
  end

  # True if no children or if only descendants are {#unknown?} and no HaramiVid depends on self.
  def destroyable?
    return false if harami_vids.exists? || harami1129s.exists?
    1 == events.count && 1 == event_items.size && events.first.unknown? && !unknown?
  end

  # @return [String] mname.to_s if mname.present?  If not, judge it according to Translation.
  def mname_to_s
    if mname.present? && !(s=mname.to_s.strip).empty?
      return s
    end

    REGEXP_IDENTIFY_EVGR.each_pair do |ek, ea_re|
      (alltras = best_translations).values.each do |tra|
        %i(title alt_title).each do |metho|
          return ek.to_s if (s=tra.send(metho)).present? && ea_re =~ s
        end
      end
    end

    (best_translations["en"] || best_translations["ja"]).slice(:title, :alt_title).values.map{|i| (i.present? && i.strip.present?) ? i : nil}.compact.first || ""  # should never be an empty String in normal operations, but playing safe.
  end


  ########## callbacks ########## 

  def add_place_in_create_callback
    self.place = Place.unknown if !place
  end

  # Adds Event(UnknownEvent) after the first Translation creation of EventGroup
  #
  # Called by an after_create callback in {Translation}
  #
  # @todo
  #    The core should be moved into event.rb (?) That is how this is implemented in the Event-to-EventItem.
  #
  # @return [Event]
  def after_first_translation_hook
    hstrans = best_translations
    hs2pass = {}
    unsaved_transs = []
    Event::UNKNOWN_TITLES.each_pair do |lc, ea_title|
      unsaved_transs << Translation.new(
        title: [ea_title].flatten.first,
        alt_title: [ea_title].flatten[1],
        langcode: lc,
        is_orig:  (hstrans.key?(lc) && hstrans[lc].respond_to?(:is_orig) ? hstrans[lc].is_orig : nil),
        weight: 0,
      )
    end

    evt = Event.initialize_with_def_time(event_group: self)
    evt.unsaved_translations = unsaved_transs
    self.events << evt
  end

  # Callback to delete the last-remaining "unknown" Event
  #
  # Basically, EventGroup#events.destroy_all always fails!
  #
  # @note If {ApplicationRecord.allow_destroy_all} is set true
  #    (in Rails console etc), {EventGroup.destroy_all}, {Event.destroy_all}
  #    and {EventItem.destroy_all} are allowed.
  def delete_remaining_unknwon_event_callback
    if !destroyable? && !ApplicationRecord.allow_destroy_all
      errors.add(:base, "#{self.class.name} with significant descendants cannot be destroyed. Destroy all dependent HaramiVids and not-unknown  descendants (EventItem, Event) first.")
      throw(:abort)
    elsif 1 == events.size
      # Both a grandchild and child will be deleted.
      event_items.first.delete  # Without this, ActiveRecord::DeleteRestrictionError is raised as an orphan would remain.
      events.first.translations.destroy_all  # Essential. Else, orphan Translations would remain.
      events.first.delete
    end
  end
  private :delete_remaining_unknwon_event_callback
end

class << EventGroup 
  alias_method :uncategorized, :unknown if ! self.method_defined?(:uncategorized)

  alias_method :create_basic_bwt!, :create_basic! if !self.method_defined?(:create_basic_bwt!)
  alias_method :initialize_basic_bwt, :initialize_basic if !self.method_defined?(:initialize_basic_bwt!)

  # Wrapper of {BaseWithTranslation.create_basic!}
  def create_basic!(*args, start_date: TimeAux::DEF_FIRST_DATE_TIME, start_date_err: nil, end_date: TimeAux::DEF_LAST_DATE_TIME, end_date_err: nil, **kwds, &blok)
    start_date_err ||= TimeAux::MAX_ERROR.in_days.ceil + 1  # = 3652060 [days]
    end_date_err   ||= TimeAux::MAX_ERROR.in_days.ceil + 1
    create_basic_bwt!(*args, start_date: start_date, start_date_err: start_date_err, end_date: end_date, end_date_err: end_date_err, **kwds, &blok)
  end

  # Wrapper of {BaseWithTranslation.initialize_basic!}
  # Unlike {#create_basic!}, an existing Sex is used, which is assumed to exist.
  def initialize_basic(*args, start_date: TimeAux::DEF_FIRST_DATE_TIME, start_date_err: nil, end_date: TimeAux::DEF_LAST_DATE_TIME, end_date_err: nil, **kwds, &blok)
    start_date_err ||= TimeAux::MAX_ERROR.in_days.ceil + 1  # = 3652060 [days]
    end_date_err   ||= TimeAux::MAX_ERROR.in_days.ceil + 1
    initialize_basic_bwt(*args, start_date: start_date, start_date_err: start_date_err, end_date: end_date, end_date_err: end_date_err, **kwds, &blok)
  end
end


