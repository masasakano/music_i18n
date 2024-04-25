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

  belongs_to :event_group
  belongs_to :place
  has_one :prefecture, through: :place
  has_one :country, through: :prefecture
  has_many :event_items, dependent: :restrict_with_exception
  has_many :harami_vids, through: :event_items, dependent: :restrict_with_exception
  #has_many :event_items, dependent: :restrict_with_error

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

  UNKNOWN_TITLES = UnknownEvent = {
    "ja" => '不明のイベント',
    "en" => 'UnknownEvent',
    "fr" => "ÉvénementNonClassé",
  }.with_indifferent_access

  # Information of "(Country-Code)" is added.
  # @return [String]

  alias_method :inspect_orig_event, :inspect if ! self.method_defined?(:inspect_orig_event)

  def inspect
    tra = (((eg=event_group) ? eg.title_or_alt(langcode: "en", lang_fallback_option: :either, str_fallback: "") : "") rescue "")  # rescue is unnecessary but just to play safe! (b/c this is inspect)
    super.sub(/, event_group_id: \d+/, '\0'+sprintf("(%s)", tra))
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

  # True if no children or if only descendants are {#unknown?} and no HaramiVid depends on self.
  def destroyable?
    return false if harami_vids.exists?
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
    evti = EventItem.create_new_unknown!(self)
  end

  # Callback to delete the last-remaining "unknown" EventItem
  #
  # Basically, Event#event_items.destroy_all always fails!
  def delete_remaining_unknwon_event_item_callback
    if !destroyable?
      throw(:abort)
    elsif 1 == event_items.size
      event_items.first.delete
    end
  end
  private :delete_remaining_unknwon_event_item_callback

end

class <<  Event
  alias_method :create_basic_bwt!, :create_basic! if !self.method_defined?(:create_basic_bwt!)

  # Wrapper of {BaseWithTranslation.create_basic!}
  def create_basic!(*args, event_group: nil, event_group_id: nil, **kwds, &blok)
    event_group_id ||= (event_group ? event_group.id : EventGroup.create_basic!.id)
    create_basic_bwt!(*args, event_group_id: event_group_id, **kwds, &blok)
  end
end


