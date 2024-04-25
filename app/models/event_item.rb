# coding: utf-8
# == Schema Information
#
# Table name: event_items
#
#  id                                       :bigint           not null, primary key
#  duration_minute                          :float
#  duration_minute_err(in second)           :float
#  event_ratio(Event-covering ratio [0..1]) :float
#  machine_title                            :string           not null
#  note                                     :text
#  start_time                               :datetime
#  start_time_err(in second)                :float
#  weight                                   :float
#  created_at                               :datetime         not null
#  updated_at                               :datetime         not null
#  event_id                                 :bigint           not null
#  place_id                                 :bigint
#
# Indexes
#
#  index_event_items_on_duration_minute  (duration_minute)
#  index_event_items_on_event_id         (event_id)
#  index_event_items_on_event_ratio      (event_ratio)
#  index_event_items_on_machine_title    (machine_title) UNIQUE
#  index_event_items_on_place_id         (place_id)
#  index_event_items_on_start_time       (start_time)
#  index_event_items_on_weight           (weight)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id) ON DELETE => restrict
#  fk_rails_...  (place_id => places.id) ON DELETE => nullify
#
class EventItem < ApplicationRecord
  include ModuleCommon

  before_destroy :prevent_destroy_unknown  # must come before has_many

  belongs_to :event
  belongs_to :place, optional: true
  has_one :event_group, through: :event
  has_one :prefecture, through: :place
  has_one :country, through: :prefecture

  has_many :artist_music_plays, dependent: :destroy  # dependent is a key  # to an Association model! (NOT to Artists/Musics)
  %i(artists musics play_roles instruments).each do |esym|
    has_many esym, -> {distinct}, through: :artist_music_plays
  end

  has_many :harami_vid_event_item_assocs, dependent: :restrict_with_exception  # dependent is a key
       # This setting basically prohibits a deletion of an EventItem associated with at least one user
       # so that a HaramiVid would not become EventItem-less.
       # This means you should merge the EventItem to another or something before destroy.
  has_many :harami_vids, -> {distinct}, through: :harami_vid_event_item_assocs  # if the unique constraint is on for Association, `distinct` is redundant

  validates_uniqueness_of :machine_title
  %i(start_time_err duration_minute duration_minute_err event_ratio).each do |ec|
    validates ec, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  end
  %i(event_ratio).each do |ec|
    validates ec, numericality: { less_than_or_equal_to: 1 }, allow_blank: true
  end

  UNKNOWN_TITLE_PREFIXES = UnknownEvent = {
    "ja" => '不明のイベント項目_',
    "en" => 'UnknownEventItem_',
    "fr" => "ÉvénementArticleNonClassé_",
  }.with_indifferent_access

  # Called from {Event#after_first_translation_hook}
  #
  # Creating a {EventItem.unknown} for the given {Event}.
  #
  # As long as it is called in the callback/hook as intended, "find_by" is redundant.
  # However, in case this is manually called later after a DB accident or something,
  # we are playing safe.
  #
  # @param event [Event]
  # @return [String] unknown title
  def self.find_or_create_new_unknown!(event)
    hs = {
      event: event,
      machine_title: get_unique_title(unknown_machine_title_prefix(event)),
      duration_minute:     ((hr=event.duration_hour) ? hr.quo(60) : nil),
      duration_minute_err: ((er=event.start_time_err) ? er.quo(60) : nil),
    }
    
    %i(place_id start_time start_time_err).each do |metho|
      hs[metho] = event.send metho
    end
    find_or_create_by!(**hs)
  end

  # Returns the English prefix for EventItem.Unknown for the event
  #
  # This is a long prefix so that it is umlikely to be not unique.
  # Note that the second and third components are Translations and so
  # they are prone to change. Use just UNKNOWN_TITLE_PREFIXES to find one.
  #
  # @param event [Event]
  # @param artit: [Array<String>] to directly give a pair of strings. If given, event is ignored. (used for seeding.)
  # @return [String] unknown title
  def self.unknown_machine_title_prefix(event, artit: nil)
    artit ||= [event, event.event_group].map{|i|
      i.title_or_alt(langcode: "en", lang_fallback_option: :either, str_fallback: "")
    }
    UNKNOWN_TITLE_PREFIXES[:en]+artit.join("_")
  end

  # Unknown EventItem in the given event_group (or somewhere in the world)
  #
  # @example anywhere in the world
  #    EventItem.unknown
  #
  # @example unknown event in Event.second
  #    EventItem.unknown(event: Event.second)
  #
  # @param event: [Event]
  # @return [EventItem]
  def self.unknown(event: nil)
    event ? event.unknown_event_item : Event.unknown.unknown_event_item
  end

  # Returns true if self is one of the unknown EVENTs
  def unknown?
    unknown_sibling == self
  end

  # Unknown {EventItem} belonging to the same {Event}
  #
  # @return [EventItem] the unknown one
  def unknown_sibling
    event.unknown_event_item
  end

  # All {EventItem} belonging to the same {Event} but self
  #
  # @return [Relation<EventItem>]
  def siblings
    event.event_items.where.not("event_items.id" => id)
  end

  # @param prefix [String]
  # @return [String] unique machine_title
  def self.get_unique_title(prefix)
    return prefix if !where(machine_title: prefix).exists?

    (0..).each do |postfix|
      trial = prefix+postfix.to_s
      return trial if !where(machine_title: trial).exists?
      raise "(#{__FILE__}:#{__method__}) Postfix exceeded the limit for prefix=#{prefix.inspect}. Contact the code developer." if postfix > 100000  # to play safe.
    end
  end
  private_class_method :get_unique_title

  # Not destroyable if self is the last remaining one and {#unknown?}
  # even if there are no child HaramiVids.  In such a case,
  # the parent Event must be destroyed, which cascade-"delete" self.
  # 
  # Basically, {#unknown?} cannot be destroyed on its own.
  # 
  # Justification: Every {Event} must have at least 1 {EventItem}.
  def destroyable?
    return false if harami_vid_event_item_assocs.exists?
    !unknown?
  end


  ########## callbacks ########## 

  # see {#destroyable?}
  def prevent_destroy_unknown
    if unknown? && !ApplicationRecord.allow_destroy_all
      errors.add(:base, "#{self.class.name}.unknwon cannot be destroyed. It should be cascade-destroyed when the parent Event is destroyed (or ApplicationRecord.allow_destroy_all is set true)")
      throw(:abort) 
    end
  end

end
