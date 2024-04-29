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
  # defines {#unknown?} and +self.class.unknown+
  include ModuleUnknown

  before_create :add_place_in_create_callback
  before_destroy :delete_remaining_unknwon_event_callback  # must come before has_many

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

  UNKNOWN_TITLES = UnknownEventGroup = {
    "ja" => 'その他のイベント類',
    "en" => 'UncategorizedEventGroup',
    "fr" => "Groupe d'événements non classé",
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
  # place is ignored so far.
  #
  # @option context [Symbol, String]
  # @return [EventItem, Event]
  def self.default(context=nil, place: nil)
    case context.to_s.underscore.singularize
    when *(%w(harami_vid harami1129))
      ret = (self.select_regex(:title, /single-?shot +street(-?piano)? +play(ing|s)?/i, langcode: "en", sql_regexp: true).first ||
             self.select_regex(:title, /単発ストリート(ピアノ)?の?演奏/i, langcode: "ja", sql_regexp: true).first)
      return ret if ret
      logger.warn("WARNING(#{__FILE__}:#{__method__}): Failed to identify the default Streetpiano EvengGroup!")
    end

    self.unknown
  end

  # True if no children or if only descendants are {#unknown?} and no HaramiVid depends on self.
  def destroyable?
    return false if harami_vids.exists? || harami1129s.exists?
    1 == events.count && 1 == event_items.size && events.first.unknown? && !unknown?
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

    #  hstime = Event.def_time_parameters(self)
    #  evt = Event.new(
    #    start_time:     hstime[:start_time],
    #    start_time_err: hstime[:start_time_err],
    #    duration_hour:  hstime[:duration_hour],
    #    weight: Float::INFINITY,
    #    place: place,
    #  )

    #start_time = (start_date ? start_date.to_time : nil)
    #if start_date && end_date
    #  duration_hour = (end_date - start_date).quo(86400)
    #  if start_date_err && end_date_err
    #    start_time_err = Math.sqrt(start_date_err**2 + end_date_err**2)*86400
    #  end
    #end

    #evt = Event.new(
    #  start_time: start_time,
    #  start_time_err: start_time_err,
    #  weight: Float::INFINITY,
    #  place: place,
    #)
    evt.unsaved_translations = unsaved_transs
    self.events << evt
  end

  # Callback to delete the last-remaining "unknown" Event
  #
  # Basically, EventGroup#events.destroy_all always fails!
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
end

