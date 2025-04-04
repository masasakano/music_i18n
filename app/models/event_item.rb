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

  attr_accessor :warnings
  attr_accessor :form_start_err
  attr_accessor :form_start_err_unit
  attr_accessor :match_parent

  UNKNOWN_TITLE_PREFIXES = UnknownEvent = {
    "en" => 'UnknownEventItem_',
    "ja" => '不明のイベント項目_',
    "fr" => "ÉvénementArticleNonClassé_",
  }.with_indifferent_access

  DEFAULT_UNIQUE_TITLE_PREFIX = "item"

  # Default duration_minute_err for a new template.
  DEFAULT_NEW_TEMPLATE_DURATION_ERR = 600

  alias_method :inspect_orig_event_item, :inspect if ! self.method_defined?(:inspect_orig_event_item)
  include ModuleModifyInspectPrintReference

  PREFIX_MACHINE_TITLE_DUPLICATE = "copy"  # followed by (potentially a number and) a hyphen "-", as in EventItem default (EventItem.get_unique_title)

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

  # Called from {Event#after_first_translation_hook} and maybe {Event#unknown_event_item} in an unlikely case
  #
  # Internal-use method for creating a {EventItem.unknown} for the given {Event}.
  #
  # Since this calls {EventItem.prepare_create_new_template}, which ensures
  # a unique {#machine_title}, this can always safely create a new EventItem.
  #
  # In other words, you should not call this method unless you are certain
  # there is no {EventItem.unknown} for the given {Event}.
  # If you want a sort of "+find_or_create+ {EventItem.unknown}", call {Event##unknown_event_item} instead
  # (partly because String matching with {#machine_title} has some uncertainty, unlike {Place#unknown}!).
  #
  # @param event [Event]
  # @return [EventItem]
  def self.create_new_unknown!(event)
    raise "Event must be present. Contact the code developer." if !event
    raise "(#{File.basename __FILE__}:#{__method__}) Cannot accept an unsaved Event because the creation of an Event fires a creation of the unknown EventItem, which is identical to that is about to be created, leading to a DB-level unique-constraint violation. Contact the code developer. Event: #{event.inspect}" if !event.id
    hs = prepare_create_new_unknown(event)
    create!(**hs)
  end

  def self.initialize_new_unknown(event)
    hs = prepare_create_new_unknown(event)
    new(**hs)
  end

  def self.prepare_create_new_unknown(event)
    mtitle = default_unknown_machine_title(event)
    prepare_create_new_template(event, machine_title: mtitle)
  end
  private_class_method :prepare_create_new_unknown

  # Default machine title for EventItem for the given Event
  def self.default_unknown_machine_title(event)
    pre_post_fixes = unknown_machine_title_prefix_postfix(event)
    get_unique_title(pre_post_fixes[0], postfix: pre_post_fixes[1], separator: "")
  end

  # Returns a Hash of the default time parameters from the parent Event (if specified)
  #
  # @param kwd [Hash] machine_title, postfix, separator etc. If machine_title is specified, all the kwd AND prefix are ignored.
  # @return [Hash] keys(with_indifferent_access): start_time start_time_err duration_minute etc
  def self.prepare_create_new_template(event=nil, prefix=DEFAULT_UNIQUE_TITLE_PREFIX, machine_title: nil, **kwd)
    hsret = {
      event: event,
      machine_title: (machine_title || get_unique_title(prefix, **kwd)),
      duration_minute:     ((event && hr=event.duration_hour) ? hr*60 : nil),
      duration_minute_err: ((event && hr.respond_to?(:error) && hr.error) ? hr.error : DEFAULT_NEW_TEMPLATE_DURATION_ERR),  # in second
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

  # Returns the (English) prefix and postfix for EventItem.Unknown for the event
  #
  # This is a long prefix so that it is unlikely to be not unique.
  # Note that the second and third components are Translations and so
  # they are prone to change. Use just UNKNOWN_TITLE_PREFIXES to find one.
  #
  # Because it contains a Translation of the Event, if the Event has only
  # a Japanese Translation, the returned postfix also contains Japanese characters.
  #
  # @param event [Event]
  # @param artit: [Array<String>] to directly give a pair of strings. If given, event is ignored. (used for seeding.)
  # @return [Array<String>] unknown title of Prefix and Postfix, which should be joined with ""
  def self.unknown_machine_title_prefix_postfix(event, artit: nil)
    evgr = nil
    artit ||= [event, event.event_group].map{|evkind|
      evgr = (evkind.id ? evkind.reload : evkind)
      evgr.title_or_alt(langcode: "en", lang_fallback_option: :either, str_fallback: nil, article_to_head: true)  # Note that the article "the" , if exists, is broght to the head though it may stay "non"-capitalized.
    }

    # to avoid duplication of EventGroup title; this can happen because Event Translation may well include EventGroup Translation at the tail.
    # Note that the EventGroup title contained in the Event title may be either Japanese or English.
    # So, handling only an English duplication is not enough.
    evgr_titles = {
      en: artit[1],
      ja: evgr && evgr.title_or_alt(langcode: "ja", lang_fallback_option: :never, str_fallback: nil, article_to_head: true),  # maybe identical to "en" IF Event has only "ja". evgr is nil if artit is given as an argument.
    }.with_indifferent_access

    if evgr && evgr_titles[:ja].present? && !evgr_titles[:ja].strip.empty? && /#{Regexp.quote(evgr_titles[:ja])}.?\Z/ =~ artit[0]
      if artit[1].present? && !artit[1].strip.empty?  # should be always the case, but playing safe.
        artit[0].sub!(/#{Regexp.quote(evgr_titles[:ja])}(.?)\Z/, artit[1].strip+'\1')
        artit.pop
      end
    else # if !evgr || 1 == evgr_titles.values.uniq.size  # evgr is nil if artit is given as an argument.
      artit.pop if /#{Regexp.quote(artit[1])}.?\Z/ =~ artit[0]
    end

    [UNKNOWN_TITLE_PREFIXES[:en], artit.join("_").gsub(/ +/, "_").gsub(/__+/, "_")]
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
  # @param force: [Boolean] if true (Def: false), and if unknown sibling is not found, create it.
  # @return [EventItem, NilClass] the unknown one
  def unknown_sibling(force: false)
    event.unknown_event_item(force: force)
  end

  # All {EventItem} belonging to the same {Event} but self (and optionally, unknown)
  #
  # @param exclude_unknown: [Boolean] if true, (Def: false), EventItem#unknown? is also excluded.
  # @return [Relation<EventItem>]
  def siblings(exclude_unknown: false)
    except_ids = [id]
    except_ids << unknown_sibling.id if exclude_unknown && unknown_sibling
    event.event_items.where.not("event_items.id" => except_ids)
    #event.event_items.where.not("event_items.id" => id)
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
    elsif !def_event  # should never happen...
      raise "#{File.basename __FILE__}:(#{__method__}) unexpectedly nil is returned from #{self.name}.default(#{context.inspect}, place: #{place ? place.title.inspect : 'nil'}, event_group: #{event_group ? [event_group.id, event_group.title].inspect : 'nil'}, save_event: false, #{kwd.inspect})"
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
    raise "Contact the code developer (wrong argument for method)." if !event
    evit = initialize_new_template(event)
    if !evit  # should never happen...
      raise "#{File.basename __FILE__}:(#{__method__}) unexpectedly nil is returned from #{self.name}.initialize_new_template(#{event.inspect})"
    end
    return evit if !save_event
    evit.save!
    evit
  end
  private_class_method :new_default_for_event

  # Returns a unique title.
  #
  # Wrapper of +get_unique_string+ (defined in +/app/models/concerns/module_application_base.rb+)
  # so you don't have to type much in most cases!
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
            definite_article_to_head(model.title(langcode: "en", lang_fallback: true, str_fallback: "")).gsub(/ +/, "_").gsub(/__+/, "_")
          }
          artit.pop if /#{Regexp.quote(artit[1])}.?\Z/ =~ artit[0]  # to avoid duplication of EventGroup name; this can happen because Event Translation may well include EventGroup Translation at the tail.
          artit.join(separator)
        else
          ""
        end
    end
    self.class.get_unique_title(prefix, postfix: postfix, separator: separator)
  end

  # True if all the ArtistMusicPlay-s are "duplicated", meaning
  # they all are associated for different EventItems as well.
  # 
  def associated_amps_all_duplicated?
    artist_music_plays.all?{|amp|
      amp.sames_but(event_item: self).exists?
    }
  end

  # @example 
  #    evit.duration_err_with_unit.in_seconds  # => 120.0 (Float), when evit.duration_minute_err == 2.0
  #
  # @return [ActiveSupport::Duration]
  def duration_err_with_unit
    duration_minute_err.present? ? duration_minute_err.seconds : nil
  end

  # Returns duration_minute_err to be set for the ActiveRecord (EventItem) and hence DB
  #
  # This is a class method!
  #
  # @param val_with_unit [ActiveSupport::Duration, NilClass]
  # @return [Float, NilClass] in seconds at the time of writing
  def self.num_with_unit_to_db_duration_err(val_with_unit)
    val_with_unit.present? ? val_with_unit.in_seconds : nil
  end

  # True if no children or if only descendants are {#unknown?} and no HaramiVid depends on self.
  def open_ended?
    !duration_minute || duration_minute > TimeAux::THRE_OPEN_ENDED.in_minutes
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

  # Import data from parent Event or associated {HaramiVid}-s
  #
  # This may set @warnings[key]
  #
  # @param key [String, Symbol] key (column name or one without ID)
  # @return [Object] nil if no update is needed
  def imported_data_from_associates(key)
    return nil if !event  # should never happen, but playing safe
    orig_val = send(key)

    retval = 
      case key.to_sym
      when :start_time
        val=event.start_time
        (val && (!orig_val || orig_val < val)) ? val : nil
      when :start_time_err
        val=event.start_time_err
        (val && (!orig_val || orig_val > val)) ? val : nil
      when :duration_minute
        val=event.duration_hour
        (val && (!orig_val || orig_val > val*60)) ? val*60 : nil
      when :publish_date
        nil
      when :place
        val=event.place
        (val && (!orig_val || orig_val.encompass_strictly?(val) || !orig_val.not_disagree?(val))) ? event.place : nil
      else
        raise ArgumentError, "#{File.basename __FILE__}:(#{__method__}) Wrong key (#{key})."
      end

    if !harami_vids.exists?
      _set_warnings(key, retval || orig_val)
      return retval 
    end

    # May adjust according to associated HaramiVid-s
    case key.to_sym
    when :publish_date
      if last_release_date && (!orig_val || orig_val > last_release_date)
        retval = first_release_date
      end
    when :place
      retval ||= least_significant_hvid_place if !orig_val
    end

    _set_warnings(key, retval || orig_val)  # n.b., retval is nil if no update (for orig_val) is needed.
    return retval 
  end

  # this sets @warnings, too.
  #
  # @return [Hash] (with_indifferent_access) key to value of a newly imported value,
  #    which is nil if no update is required.
  def data_to_import_parent
    return({}.with_indifferent_access) if !event  # should never happen, but playing safe
    %i(start_time start_time_err duration_minute publish_date place).map{|ek|
      [ek, imported_data_from_associates(ek)]
    }.to_h.with_indifferent_access
  end

  # Last release_date among the associated {HaramiVid}-s
  def all_release_dates
    @all_release_dates ||= (harami_vids.exists? && harami_vids.pluck(:release_date).flatten.compact.sort)
  end

  # First release_date among the associated {HaramiVid}-s
  def first_release_date
    @first_release_date ||= (all_release_dates && all_release_dates.first)
  end

  # Last release_date among the associated {HaramiVid}-s
  def last_release_date
    @last_release_date ||= (all_release_dates && all_release_dates.last)
  end

  # All associated HaramiVid-s' Places
  #
  # @return [Array<Place>, NilClass] nil only when there are no associated HaramiVid-s, otherwise always Array is returned.
  def hvid_places
    @hvid_places ||= (harami_vids.exists? && harami_vids.pluck(:place_id).flatten.compact.uniq.map{|plaid| Place.find(plaid)})
  end

  # One of the least significant Place-s among those of all associated HaramiVid-s
  #
  # @return [Place, NilClass] nil only when there are no associated HaramiVid-s, otherwise always Array is returned.
  def least_significant_hvid_place
    hvid_places && hvid_places.sort{|a, b|
      if a.more_significant_than?(b)
        -1
      elsif b.more_significant_than?(a)
        1
      else
        0
      end
    }.last
  end

  # "Deep" copy/duplication
  #
  # WARNING & TODO: Rails defines Hash#deep_dup (and also ActiveRecord#deep_dup which works in a similar way as dup), so this method name is confusing!
  #
  # Returns a dup of self (EventItem), where
  #   * machine_title is (has to be) unique
  #   * weight is nil
  #   * All the other direct parameters are same, except for the primary ID and timestamps.
  #   * All the associated ArtistMusicPlay-s are copied and inherited (obviously except for *event_item_id*)
  #   * All the associated HaramiVidEventItemAssoc-s are copied and inherited (because it is easier to destroy the association later if the user wants than to re-create an association)
  #
  # @return [EventItem]
  def deep_dup
    evit = dup

    evit.machine_title = _get_unique_copied_machine_title
      # => e.g., "copy-unk_Event_in_Tocho(...)", "copy2-Hitori-20240101_Tocho_<_Single-shotStreetpianoPlaying"

    evit.weight = nil  # Only weight

    harami_vids.each do |ehv|
      evit.harami_vids << ehv
    end

    artist_music_plays.each do |eamp|
      amp_new = eamp.dup
      amp_new.event_item = nil
      evit.artist_music_plays << amp_new
    end

    evit
  end

  # @param with: [ActiveRecord, Place] Event or HaramiVid (or Place, directly) whose place should encomapss self's plae.
  def place_consistent?(with: event)
    place_ref = (with.respond_to?(:place) ? with.place : with)
    ((!!place ^! !!place_ref) && (!place_ref || place_ref.encompass?(place)))
  end

  # @example
  #    _get_unique_copied_machine_title
  #      # => e.g., "copy-unk_Event_in_Tocho(...)", "copy2-Hitori-20240101_Tocho_<_Single-shotStreetpianoPlaying"
  #
  # @return [String] machine_title guaranteed to be unique.
  def _get_unique_copied_machine_title
    mtit = machine_title.dup
    EventItem::UNKNOWN_TITLE_PREFIXES.values.each do |prefix|
      # In the case of "Unknown" (prefix is like "UnknownEventItem_" for "en"),
      # the prefix is replaced.
      mat = /(.*)([_\-]+)\z/.match prefix
      root = Regexp.quote(mat ? mat[0] : prefix)
      separator_regex = (mat ? Regexp.quote(mat[1]) : "")
      mtit.sub!(/\A#{root}#{separator_regex}/, "unk"+(mat ? mat[1].tr_s("_\-", "_\-") : "_"))
    end

    EventItem.get_unique_title(PREFIX_MACHINE_TITLE_DUPLICATE, postfix: mtit)
  end
  private :_get_unique_copied_machine_title

  # Set @warnings for all keys with the current status of self
  #
  # @return [Array] @warnings
  def set_all_warnings
    %i(start_time start_time_err duration_minute publish_date place).each do |ek|
      _set_warnings(ek, send(ek))
    end
    @warnings
  end

  # Set @warnings
  #
  # @param key [String, Symbol]
  # @param val [Object] if nil, it is taken from self.
  # @return [String, NilClass] String (message) if a warning is set, else nil. (But you may not use the returned value anyway.)
  def _set_warnings(key, val=nil)
    @warnings ||= {}.with_indifferent_access
    val ||= send(key)
    return !val  # If value is nil, this method does nothing.  The caller should handle it.

    case key.to_sym
    when :start_time
      if val > Time.current
        return(@warnings[key] = "Start time is in the future.")
      elsif last_release_date && last_release_date < val.to_date
        return(@warnings[key] = "Start time is later than the (latest) release-date of the associated video(s).")
      end
    when :start_time_err
        # do nothing
    when :duration_minute
      if event && event.duration_hour*60 < val
        return(@warnings[key] = "Duration is longer than that of the parent Event.")
      end
    when :publish_date
      if last_release_date && last_release_date < val
        return(@warnings[key] = "Publish date is later than the (latest) release-date of the associated video(s).")
      elsif last_release_date == Date.current
        return(@warnings[key] = "Publish date is today (Ignore this warning if it is what you intended).")
      end
    when :place
      if event && event.place && !event.place.encompass?(val)
        return(@warnings[key] = "Place is inconsistent with Event's Place.")
      elsif harami_vids.exists? && hvid_places.all?{|pla| pla.not_disagree?(other, allow_nil: false)}
        return(@warnings[key] = "Place is inconsistent with any of the associated video(s).")
      end
    else
      raise ArgumentError, "#{File.basename __FILE__}:(#{__method__}) Wrong key (#{key})."
    end
    nil
  end
  private :_set_warnings

  ########## callbacks ########## 

  # see {#destroyable?}
  def prevent_destroy_unknown
    if unknown? && !ApplicationRecord.allow_destroy_all
      errors.add(:base, "#{self.class.name}.unknwon cannot be destroyed. It should be cascade-destroyed when the parent Event is destroyed (or ApplicationRecord.allow_destroy_all is set true)")
      throw(:abort) 
    end
  end

end
