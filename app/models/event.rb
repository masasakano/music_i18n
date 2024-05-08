# coding: utf-8

# == Schema Information
#
# Table name: events
#
#  id                        :bigint           not null, primary key
#  duration_hour             :float
#  note                      :text
#  start_time                :datetime
#  start_time_err(in second) :bigint
#  weight                    :float
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  event_group_id            :bigint           not null
#  place_id                  :bigint
#
# Indexes
#
#  index_events_on_duration_hour   (duration_hour)
#  index_events_on_event_group_id  (event_group_id)
#  index_events_on_place_id        (place_id)
#  index_events_on_start_time      (start_time)
#  index_events_on_weight          (weight)
#
# Foreign Keys
#
#  fk_rails_...  (event_group_id => event_groups.id) ON DELETE => restrict
#  fk_rails_...  (place_id => places.id) ON DELETE => nullify
#
class Event < BaseWithTranslation
  # For the translations to be unique (required by BaseWithTranslation).
  MAIN_UNIQUE_COLS = []

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" when "The Beatles" is passed.  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = true

  before_validation :add_parent_in_create_callback
  before_destroy :delete_remaining_unknwon_event_item_callback  # must come before has_many
  # NOTE: after_first_translation_hook

  belongs_to :event_group
  belongs_to :place
  has_one :prefecture, through: :place
  has_one :country, through: :prefecture
  has_many :event_items, dependent: :restrict_with_exception
  has_many :harami_vids, through: :event_items, dependent: :restrict_with_exception
  has_many :harami1129s, through: :event_items, dependent: :restrict_with_exception

  # Validates if a {Translation} is unique within the parent
  #
  # Fired from {Translation}
  # @param record [Translation]
  def validate_translation_callback(record)
    validate_translation_unique_within_parent(record)
  end

  %i(duration_hour).each do |ec|
    validates ec, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  end

  attr_accessor :form_start_err
  attr_accessor :form_start_err_unit

  UNKNOWN_TITLES = UnknownEvent = {
    "ja" => '不明のイベント',
    "en" => 'UnknownEvent',
    "fr" => "ÉvénementNonClassé",
  }.with_indifferent_access

  # the first three "%s" are the Place/Prefecture/Country title (of the language, if existent)
  # the second "%s" one is meant to be for EventGroup title
  #
  # @example the final title for a default Event
  #    "京都府での一般的イベント < その他のイベント類"
  #    "Event in Kyoto < UncategorizedEventGroup"
  DEF_EVENT_TITLE_FORMATS = {
    "ja" => ['%s(%s/%s)でのイベント', " < ", "%s"],
    "en" => ['Event in %s(%s/%s)', " < ", "%s"],
  }.with_indifferent_access

  # Information of "(Country-Code)" is added.
  # @return [String]

  alias_method :inspect_orig_event, :inspect if ! self.method_defined?(:inspect_orig_event)

  def inspect
    tra1 = (((eg=event_group) ? eg.title_or_alt(langcode: "en", lang_fallback_option: :either, str_fallback: "") : "") rescue "")  # rescue is unnecessary but just to play safe! (b/c this is inspect)
    tra2 = inspect_place_helper(place) # defined in module_common.rb
    super.sub(/, event_group_id: (\d+|nil)/, '\0'+sprintf("(%s)", tra1)).sub(/, place_id: (\d+|nil)/, '\0'+tra2)
  end

  # Unknown Event in the given event_group (or somewhere in the world)
  #
  # @example anywhere in the world
  #    Event.unknown
  #
  # @example unknown event in EventGroup.second
  #    Event.unknown(event_group: EventGroup.second)
  #
  # @param event_group: [EventGroup]
  # @return [Event]
  def self.unknown(event_group: nil)
    event_group ? event_group.unknown_event : EventGroup.unknown.unknown_event
  end

  # Returns true if self is one of the unknown EVENTs
  def unknown?
    %w(en ja fr).each do |lcode|
      return true if title(langcode: lcode) == UNKNOWN_TITLES[lcode]
    end
    false
  end

  # Unknown {Event_Item} belonging to self
  #
  # @return [Event_Item]
  def unknown_event_item
    event_items.where("regexp_match(event_items.machine_title, ?, ?) IS NOT NULL", '^'+EventItem::UNKNOWN_TITLE_PREFIXES[:en], '').order(:created_at).first
  end

  # Unknown {Event} belonging to self
  #
  # @return [Event]
  def unknown_sibling
    self.event_group.unknown_event
  end


  # Returns a Hash of the default time parameters from the parent EventGroup
  #
  # @return [Hash] keys(with_indifferent_access): start_time start_time_err duration_hour
  def self.def_time_parameters(event_group=nil)
    hsret = {
      start_time: TimeAux::DEF_FIRST_DATE_TIME,
      start_time_err: TimeAux::MAX_ERROR,
      duration_hour: nil,  # This is unknown, hence nil.
    }.with_indifferent_access

    return hsret if !event_group || !event_group.start_date

    hsret[:start_time]     = TimeAux.to_time_midday_utc(event_group.start_date)  # to make it midday in UTC/GMT
    hsret[:start_time_err] = TimeAux.to_time_midday_utc(event_group.end_date) - hsret[:start_time] if (event_group.end_date)

    hsret
  end

  # Returns a new (unsaved) Event with many parameters (like time) filled.
  #
  # If EventGroup is set and if its Place is set, and if Place is not specified,
  # the Place is also set.
  #
  # @example
  #    evt = Event.initialize_with_def_time(event_group: Event_group.unknown, weight: 0.5, duration_hour: 3)
  #    evt.save!
  #
  #
  #
  # @return [Event]
  def self.initialize_with_def_time(*args, **kwds)
    record = self.new(*args, **kwds)
    record.place  ||= record.event_group.place if record.event_group
    record.weight ||= Float::INFINITY

    hstime = def_time_parameters(record.event_group)
    %w(start_time start_time_err duration_hour).each do |metho|
      record.send(metho+"=", hstime[metho]) if !record.send(metho)
    end

    record
  end

  # Returning a default Event in the given context
  #
  # If not matching with Place, an *unsaved* new record of {Event} is returned.
  # The caller may save it or discard it, judging with {#new_record?}
  #
  # Note that if the place is new, usually an unknown Event should be created
  # because each unknown Event has a Place defined.
  #
  # @option context [Symbol, String]
  # @return [EventItem, Event]
  def self.default(context=nil, place: nil)
    def_event_group = EventGroup.default(context, place: place)
    return def_event_group.unknown_event if !place

    # place is guaranteed to exist.

    events = def_event_group.events.where(place: place)
    if events.exists?
      DEF_EVENT_TITLE_FORMATS.each_key do |lcode|
        core = Regexp.quote(default_title_prefix_for_lang(place, lcode))
        existing = self.select_regex(:title, /#{core}/, langcode: lcode, sql_regexp: true).where(event_group: def_event_group).first
        return existing if existing
      end
      # Though there are Events in the same EventGroup, none of them are the generalized default Event.
    end

    # initialize a new one
    evt = Event.initialize_with_def_time(event_group: def_event_group, place: place)

    # Prepare Translation
    unsaved_transs = []
    DEF_EVENT_TITLE_FORMATS.each_key do |lc|
      trans = default_unsaved_trans_for_lang(place, def_event_group, lc)
      trans.valid?
      next if trans.errors.full_messages.any?{|i| i.include?("Asian characters")}
      unsaved_transs << trans
      # Translation is often not valid, because of {Translation#asian_char_validator} validator,
      # leaving "Title contains Asian characters (東京都本庁舎)" etc.
      # Such Translation-s are not added.
      #
      # Note that these translations are always invalid because of
      #  ["Translatable must exist"].
      # For this reason we cannot filter out, relying on "valid?"
      #
      # As a result, many of the new Default Event with a specified Place,
      # English translations may not exist.  Since Title has to be unique within
      # an EventGroup, the full Place name (with Prefecture and Country) must be given
      # to guarantee its uniqueness.  Anyway it is a default Event and so it does not matter much.
    end

    evt.unsaved_translations = unsaved_transs
    evt
  end

  # @return [Translation]
  def self.default_unsaved_trans_for_lang(place, event_group, langcode)
    prefix = default_title_prefix_for_lang(place, langcode)
    fmt = DEF_EVENT_TITLE_FORMATS[langcode][1..-1].join("")
    title = prefix + sprintf(fmt, event_group.title_or_alt(langcode: langcode, lang_fallback_option: :either, str_fallback: ""))
    Translation.new(
      title:    title,
      langcode: langcode,
      is_orig:  nil,
      weight: 0,
    )
  end # self.default_unsaved_trans_for_lang(context: nil, place: nil)
  private_class_method :default_unsaved_trans_for_lang

  # Returns a default title or its prefix if specified so.
  #
  # @param place [Place]
  # @return [String]
  def self.default_title_prefix_for_lang(place, langcode)
    hsopts = {langcode: langcode, lang_fallback_option: :either, str_fallback: ""}
    place_tit = place.title_or_alt(**hsopts)
    prefe_tit = place.prefecture.title_or_alt(**hsopts)
    count_tit = place.country.title_or_alt(prefer_alt: true, **hsopts)
    sprintf(DEF_EVENT_TITLE_FORMATS[langcode][0], place_tit, prefe_tit, count_tit)
  end
  private_class_method :default_title_prefix_for_lang


  # True if no children or if only descendants are {#unknown?} and no HaramiVid depends on self.
  def destroyable?
    return false if harami_vids.exists? || harami1129s.exists?
    !unknown?
  end

  ########## callbacks ########## 

  def add_parent_in_create_callback
    self.event_group = EventGroup.unknown if !event_group
    self.place = event_group.place if !place
  end
  private :add_parent_in_create_callback

  # Adds EventItem(UnknownEventItem) after the first Translation creation of EventGroup
  #
  # Called by an after_create callback in {Translation}
  # NOTE: This should never be a private method!!
  #
  # @return [Event]
  def after_first_translation_hook
    self.reload  # Essential!
    evti = EventItem.find_or_create_new_unknown!(self)
  end

  # Callback to delete the last-remaining "unknown" EventItem
  #
  # Basically, Event#event_items.destroy_all always fails!
  def delete_remaining_unknwon_event_item_callback
    if !destroyable? && !ApplicationRecord.allow_destroy_all
      if unknown?
        errors.add(:base, "#{self.class.name}.unknwon cannot be destroyed. It should be cascade-destroyed when the parent EventGroup is destroyed (or ApplicationRecord.allow_destroy_all is set true).")
      else
        errors.add(:base, "#{self.class.name} with significant descendants cannot be destroyed. Destroy all dependent HaramiVids and not-unknown EventItem first.")
      end
      throw(:abort)
    elsif 1 == event_items.size
      event_items.first.delete
      self.reload  # Essential!! Without this, ActiveRecord::DeleteRestrictionError would be raised as the deletion is not recognised by the Rails cache.
    end
  end
  private :delete_remaining_unknwon_event_item_callback

  # Validates if a {Translation} is unique within the parent ({Prefecture})
  #
  # Fired from {Translation}
  def validate_translation_callback(record)
    validate_translation_unique_within_parent(record)
  end
end

class <<  Event
  alias_method :create_basic_bwt!, :create_basic! if !self.method_defined?(:create_basic_bwt!)

  # Wrapper of {BaseWithTranslation.create_basic!}
  def create_basic!(*args, event_group: nil, event_group_id: nil, **kwds, &blok)
    event_group_id ||= (event_group ? event_group.id : EventGroup.create_basic!.id)
    create_basic_bwt!(*args, event_group_id: event_group_id, **kwds, &blok)
  end
end


