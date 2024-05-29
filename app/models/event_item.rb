# coding: utf-8
# == Schema Information
#
# Table name: event_items
#
#  id                                                                          :bigint           not null, primary key
#  duration_minute                                                             :float
#  duration_minute_err(in second)                                              :float
#  event_ratio(Event-covering ratio [0..1])                                    :float
#  machine_title                                                               :string           not null
#  note                                                                        :text
#  publish_date(First broadcast date, esp. when the recording date is unknown) :date
#  start_time                                                                  :datetime
#  start_time_err(in second)                                                   :float
#  weight                                                                      :float
#  created_at                                                                  :datetime         not null
#  updated_at                                                                  :datetime         not null
#  event_id                                                                    :bigint           not null
#  place_id                                                                    :bigint
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
  has_many :harami1129s, dependent: :restrict_with_exception  # dependent is a key

  validates_presence_of   :machine_title
  validates_uniqueness_of :machine_title
  %i(start_time_err duration_minute duration_minute_err event_ratio).each do |ec|
    validates ec, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  end
  %i(event_ratio).each do |ec|
    validates ec, numericality: { less_than_or_equal_to: 1 }, allow_blank: true
  end

  attr_accessor :form_start_err
  attr_accessor :form_start_err_unit

  UNKNOWN_TITLE_PREFIXES = UnknownEvent = {
    "en" => 'UnknownEventItem_',
    "ja" => '不明のイベント項目_',
    "fr" => "ÉvénementArticleNonClassé_",
  }.with_indifferent_access

  DEFAULT_UNIQUE_TITLE_PREFIX = "item"

  alias_method :inspect_orig_event_item, :inspect if ! self.method_defined?(:inspect_orig_event_item)
  include ModuleModifyInspectPrintReference

  redefine_inspect(cols_yield: %w(event_id place_id)){ |record, col_name, self_record|
    case col_name
    when "event_id"
      "("+record.title_or_alt(langcode: "en", lang_fallback_option: :either, str_fallback: "")+")"
    when "place_id"
      self_record.inspect_place_helper(record) # defined in module_common.rb
    else
      raise
    end
  }

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
    hs = prepare_create_new_unknown(event)
    find_or_create_by!(**hs)
  end

  def self.create_new_unknown!(event)
    hs = prepare_create_new_unknown(event)
    create!(**hs)
  end

  def self.initialize_new_unknown(event)
    hs = prepare_create_new_unknown(event)
    new(**hs)
  end

  def self.prepare_create_new_unknown(event)
    pre_post_fixes = unknown_machine_title_prefix_postfix(event)
      
    #prepare_create_new_template(event, prefix=unknown_machine_title_prefix_postfix(event).join(""), **kwd)
    prepare_create_new_template(event, prefix=pre_post_fixes[0], postfix: pre_post_fixes[1], separator: "")
  end
  private_class_method :prepare_create_new_unknown

  # Returns a Hash of the default time parameters from the parent Event (if specified)
  #
  # @return [Hash] keys(with_indifferent_access): start_time start_time_err duration_minute etc
  def self.prepare_create_new_template(event=nil, prefix=DEFAULT_UNIQUE_TITLE_PREFIX, **kwd)
    hsret = {
      event: event,
      machine_title: get_unique_title(prefix, **kwd),
      duration_minute:     ((event && hr=event.duration_hour) ? hr.quo(60) : nil),
      duration_minute_err: ((event && er=event.start_time_err) ? er : nil),  # both in units of second
    }

    %i(place_id start_time start_time_err).each do |metho|
      hsret[metho] = event.send metho
    end
    hsret
  end

  def self.initialize_new_template(event=nil, prefix=DEFAULT_UNIQUE_TITLE_PREFIX, postfix: nil, **kwd)
    _, def_postfix = unknown_machine_title_prefix_postfix(event)
    self.new(**prepare_create_new_template(event, prefix, postfix: (postfix || def_postfix), **kwd))
  end

  # Returns the English prefix for EventItem.Unknown for the event
  #
  # This is a long prefix so that it is umlikely to be not unique.
  # Note that the second and third components are Translations and so
  # they are prone to change. Use just UNKNOWN_TITLE_PREFIXES to find one.
  #
  # @param event [Event]
  # @param artit: [Array<String>] to directly give a pair of strings. If given, event is ignored. (used for seeding.)
  # @return [Array<String>] unknown title of Prefix and Postfix, which should be joined with ""
  def self.unknown_machine_title_prefix_postfix(event, artit: nil)
    artit ||= [event, event.event_group].map{|i|
      i.reload
      i.title_or_alt(langcode: "en", lang_fallback_option: :either, str_fallback: nil, article_to_head: true)  # Note that the article "the" , if exists, is broght to the head though it may stay "non"-capitalized.
    }
    artit.pop if /#{Regexp.quote(artit[1])}.?\Z/ =~ artit[0]  # to avoid duplication of EventGroup name; this can happen because Event Translation may well include EventGroup Translation at the tail.
    [UNKNOWN_TITLE_PREFIXES[:en], artit.join("_").gsub(/ +/, "_")]
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
  def self.unknown(event: nil, event_group: nil)
    event ? event.unknown_event_item : Event.unknown(event_group: event_group).unknown_event_item
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

  # Returning a default EventItem in the given context
  #
  # If not matching with Place, an unsaved new record of {Event} is returned
  # unless save_event is true.  In such a case,
  # the caller may save it or discard it, judging with {#new_record?}
  # If {Event} is returned and if it is saved, you can find {EventItem}
  # with +event.unknown_event_item+ as there is obviously no other EventItem
  # belonging to the Event anyway.
  #
  # Note that if the place is a newly created one, usually an unknown Event should be created
  # because each unknown Event has a Place defined.
  #
  # Also, if event_group is unspecified, {EventGroup} may depend on +ref_title+ (and potentially +year+).
  #
  # @example saave_event is false
  #    model = EventItem.default(:Harami1129, place: Place.last, save_event: false)
  #    if model.new_record?
  #       model.save!
  #       model = model.unknown_event_item
  #    end
  #    # Now model is EventItem
  #
  # @example saave_event is true
  #    event_item = EventItem.default(:Harami1129, place: Place.last, save_event: true)
  #    # This possibly creates 2 objects: new Event and associated "unknown" EventItem
  #
  # @example with ref_title
  #    event_item = EventItem.default(:Harami1129, save_event: true, ref_title: "誕生日生配信")
  #    # This usually creates 2 objects: new Event in EventGroup of Live-streamings
  #    # and associated "unknown" EventItem, because live-streamings are usually
  #    # a new Event, except for ones starting right after an unintentional hang-up
  #    # or after-talk for limited (fan-club?) members after a public streaming live.
  #
  # @option context [Symbol, String]
  # @param place: [Place, NilClass]
  # @param event_group: [EventGroup, NilClass]
  # @option save_event: [Boolean] If specified, always return EventItem, where a new Event may be created.
  # @param **kwd [Hash] See {EventGroup.guessed_best_or_nil} and {Event.default} for keywords (:ref_title, :year, :date, :place_confidence)
  # @return [EventItem, Event]
  def self.default(context=nil, place: nil, event_group: nil, save_event: false, **kwd)
    def_event = Event.default(context, place: place, event_group: event_group, **kwd)
    return def_event.unknown_event_item if !def_event.new_record?
    return def_event if !save_event

    def_event.save!
    def_event.reload.unknown_event_item
  end

  # Similar to {EventItem.default} but never returns an existing one (EventItem or possibly Event in some situations).
  #
  # The returned one is {EventItem#unknown?} if Event (in addition to EventItem) is newly created.
  # Otherwise, the {#machine_title} has a prefix of {EventItem::DEFAULT_UNIQUE_TITLE_PREFIX}
  #
  # If {EventGroup} is unspecified, it is automatically chosen based on several
  # contexts; see {EventGroup.guessed_best} for detail.
  #
  # @option context [Symbol, String]
  # @param place: [Place, NilClass]
  # @param event: [Event, NilClass] If specified non-nil, the Event is used without deriving an Event. If this is specified, place and event_group are ignored.
  # @param event_group: [EventGroup, NilClass]
  # @option save_event: [Boolean] If specified, always return EventItem, where a new Event may be created. Unlike {EventItem.default}, the default is true(!)
  # @param **kwd [Hash] See {EventGroup.guessed_best_or_nil} and {Event.default} for keywords (:ref_title, :year, :date, :place_confidence)
  # @return [EventItem, Event] it is guaranteed to be EventItem if save_event is true.
  def self.new_default(context=nil, place: nil, event: nil, event_group: nil, save_event: true, **kwd)
    return new_default_for_event(event, save_event: save_event) if event

    def_event = default(context, place: place, event_group: event_group, save_event: false, **kwd)
    if def_event.class == self
      # get Event from EventItem
      def_event = def_event.event
    else
      return def_event if !save_event
      def_event.save!
      return def_event.reload.unknown_event_item
    end

    new_default_for_event(def_event, save_event: save_event)
  end

  # @option save_event: [Boolean] If specified true, returned EventItem exists; otherwise unsaved new_record?
  # @return [EventItem]
  def self.new_default_for_event(event, save_event: false)
    raise if !event
    evit = initialize_new_template(event)
    return evit if !save_event
    evit.save!
    evit
  end
  private_class_method :new_default_for_event

  # Returns a unique title.
  #
  # A number may be added between prefix and separator + postfix if it is already unique.
  # A separator becomes blank if postfix is blank.
  #
  # @param prefix [String]
  # @param postfix: [String]
  # @param separator: [String]
  # @return [String] unique machine_title
  def self.get_unique_title(prefix, postfix: "", separator: "-")
    get_unique_string(:machine_title, prefix: prefix, postfix: postfix, separator: "", separator2: separator) # defined in /app/models/concerns/module_application_base.rb
  end

  # Wrapper of {EventTitle.get_unique_title}
  #
  # An eaxmple is ""
  #
  # @option prefix [String]
  # @param postfix: [String, Symbol] If :default, a combined title of Event and EventGroup is used.
  # @param separator: [String]
  # @return [String] unique machine_title
  def default_unique_title(prefix=DEFAULT_UNIQUE_TITLE_PREFIX, postfix: :default, separator: "-")
    if :default == postfix
      postfix =
        if event
          artit = [event, event.event_group].map{|model|
            definite_article_to_head(model.title(langcode: "en", lang_fallback: true, str_fallback: "")).gsub(/ +/, "_")
          }
          artit.pop if /#{Regexp.quote(artit[1])}.?\Z/ =~ artit[0]  # to avoid duplication of EventGroup name; this can happen because Event Translation may well include EventGroup Translation at the tail.
          artit.join(separator)
        else
          ""
        end
    end
    self.class.get_unique_title(prefix, postfix: postfix, separator: separator)
  end

  # Not destroyable if self is the last remaining one and {#unknown?}
  # even if there are no child HaramiVids.  In such a case,
  # the parent Event must be destroyed, which cascade-"delete" self.
  # 
  # Basically, {#unknown?} cannot be destroyed on its own.
  # 
  # Justification: Every {Event} must have at least 1 {EventItem}.
  def destroyable?
    return false if harami_vid_event_item_assocs.exists? || harami1129s.exists?
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
