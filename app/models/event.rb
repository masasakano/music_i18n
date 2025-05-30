# coding: utf-8

# == Schema Information
#
# Table name: events
#
#  id                        :bigint           not null, primary key
#  duration_hour             :float
#  memo_editor               :text
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
  # polymorphic many-to-many with Url
  include Anchorable

  include ModuleEventAux  # for self.def_event_tra_new etc
  include ModuleWeight  # adds a validation

  # For the translations to be unique (required by BaseWithTranslation).
  MAIN_UNIQUE_COLS = []

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" when "The Beatles" is passed.  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = true

  # Optional constant for a subclass of {BaseWithTranslation}.
  # Here, we implement +validate_translation_unique_within_parent+
  # in +validate_translation_callback+ instead. Hence we disable this.
  TRANSLATION_UNIQUE_SCOPES = :disable

  before_validation :add_parent_in_create_callback
  before_destroy :delete_remaining_unknwon_event_item_callback  # must come before has_many
  # NOTE: after_first_translation_hook

  belongs_to :event_group
  belongs_to :place
  has_one :prefecture, through: :place
  has_one :country, through: :prefecture
  has_many :event_items, dependent: :restrict_with_exception
  has_many :harami_vid_event_item_assocs, through: :event_items, dependent: :restrict_with_exception
  has_many :harami_vids, through: :event_items, dependent: :restrict_with_exception
  has_many :harami1129s, through: :event_items, dependent: :restrict_with_exception
  has_many :artist_collabs, -> {distinct}, through: :event_items, source: :artists
  has_many :music_plays, -> {distinct}, through: :event_items, source: :musics
  # musics can be:  Music.joins(:harami_vids).joins("INNER JOIN harami_vid_event_item_assocs ON harami_vid_event_item_assocs.harami_vid_id = harami_vids.id").joins("INNER JOIN event_items ON harami_vid_event_item_assocs.event_item_id = event_items.id").joins("INNER JOIN events ON event_items.event_id = events.id").where("events.id = ?", self.id).distinct
  # musics through EventItem:  Music.joins(:event_items).joins("INNER JOIN events ON event_items.event_id = events.id").where("events.id = ?", self.id).distinct.count
  has_many :artist_hvids, through: :harami_vids, source: :artists  # no "-> {distinct}" so far because of order in HaramiVid#musics
  has_many :music_hvids, through: :harami_vids, source: :musics  # no "-> {distinct}" so far because of order in HaramiVid#musics

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
    "en" => 'UnknownEvent',   # the order is significant b/c EventItem, for which the machine_title is partially taken from this title of Event, is created as soon as the first Translation of Event is created; If the English title is first as defined here, EventItem#machine_title contains the English one.
    "ja" => '不明のイベント',
    "fr" => "ÉvénementNonClassé",
  }.with_indifferent_access

  ar2tail = [" < ", "%s"]

  # the first three "%s" are the Place/Prefecture/Country title (of the language, if existent)
  # the second "%s" one is meant to be for EventGroup title
  #
  # @example the final title for a default Event
  #    "京都府での一般的イベント < その他のイベント類"
  #    "Event in Kyoto < UncategorizedEventGroup"
  DEF_EVENT_TITLE_FORMATS = {
    "en" => ['Event in %s(%s/%s)'   ]+ar2tail.dup.map(&:dup),
    "ja" => ['%s(%s/%s)でのイベント']+ar2tail.dup.map(&:dup),
  }.with_indifferent_access

  DEF_STREAMING_EVENT_TITLE_FORMATS = {
    "en" => ['Live-streaming on %s']+ar2tail.dup.map(&:dup),  # "en" has a fewer "%s" than "ja"!
    "ja" => ['%s %s', " < ", "%s"  ]+ar2tail.dup.map(&:dup),
  }.with_indifferent_access

  TITLE_UNKNOWN_DATE = "UnknownDate"

  # Various time parameters like offsets and errors
  DEF_TIME_PARAMS = {
    DELAY_BEFORE_PUBLISH: 20.days,  # Default number of days of delay (offset) from an Event day to the publishment day
    UTC_OFFSET_EVENT_BEGIN: 6.hours,       # In Default, an Event starts at 15:00 JST (+09:00)
    ERR_UTC_OFFSET_EVENT_BEGIN: 6.hours,   # its default error
    UTC_OFFSET_STREAMING_BEGIN: 10.hours,  # In Default, a live-streaming starts at 19:00 JST (+09:00)
    ERR_UTC_OFFSET_STREAMING_BEGIN: 3.hours,  # the defalut error of it
    DURATION: 2.hours,         # In Default, an Event lasts for 2 hours
    DURATION_DEF_EVENT: 50.years,   # A general Default Event can last for 50 years ish
  }.with_indifferent_access

  # Default error. The publishment may occur on the same day at earliest
  DEF_TIME_PARAMS[:ERR_DELAY_BEFORE_PUBLISH] = DEF_TIME_PARAMS[:DELAY_BEFORE_PUBLISH]

  # Contexts that are taken into account in {Event.default}
  VALID_CONTEXTS_FOR_DEFAULT = EventGroup::VALID_CONTEXTS_FOR_DEFAULT

  alias_method :inspect_orig_event, :inspect if ! self.method_defined?(:inspect_orig_event)
  include ModuleModifyInspectPrintReference

  redefine_inspect(cols_yield: %w(event_group_id place_id)){ |record, col_name, self_record|
    case col_name
    when "event_group_id"
      "("+record.title_or_alt(langcode: "en", lang_fallback_option: :either, str_fallback: "")+")"
    when "place_id"
      self_record.inspect_place_helper(record) # defined in module_common.rb
    else
      raise
    end
  }

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

  # Unknown {EventItem} belonging to self
  #
  # @param force [Boolean] if true (Def), and if for some reason unknown EventItem is missing, creates one and returns it.
  #    If false, returns nil in such a case, which should (though not quite guaranteed?)
  #    never occur by design (except for a legacy DB).
  # @return [EventItem, NilClass]
  def unknown_event_item(force: true)
    evit = event_items.where("regexp_match(event_items.machine_title, ?, ?) IS NOT NULL", '^'+EventItem::UNKNOWN_TITLE_PREFIXES[:en], '').order(:created_at).first
    return evit if evit || !force

    EventItem.create_new_unknown!(self)  # This guarantees a unique machine_title, even though the check above is not complete (it did not search for the entire EventItem for the identical machine_title).
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
    if event_group.start_date && event_group.start_date_err && event_group.end_date && event_group.end_date_err
      candtime = TimeAux.to_time_midday_utc(event_group.end_date) + event_group.end_date_err.abs.days - (TimeAux.to_time_midday_utc(event_group.start_date) - event_group.start_date_err.abs.days) + 1.days  # TimeZone is tricky, so the UTC-midday is used first, and then a margin of 24 hours is added.
      hsret[:start_time_err] = candtime if candtime > 0
    end

    hsret
  end

  # Returns a new (unsaved) Event with many parameters (like time) filled.
  #
  # If EventGroup is set and if its Place is set, and if Place is not specified,
  # the Place is also set.
  #
  # The arguments are passed to {Event.new} as they are.
  #
  # @example
  #    evt = Event.initialize_with_def_time(event_group: Event_group.unknown, weight: 0.5, duration_hour: 3)
  #    evt.save!
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
  # Also, if event_group is unspecified, {EventGroup} may depend on +ref_title+ (and potentially +year+).
  #
  # A live-streaming event can be judged based on keywords on ref_title (usually by {EventGroup.default}).
  # In that case, make sure to provide the optional parameter +date+ (a rough value is OK).
  #
  # @option context [Symbol, String]
  # @param place: [Place, NilClass]
  # @param event_group: [EventGroup, NilClass]
  # @option save_event: [Boolean] If specified true (Def: false), always return a saved Event, where a new Event may be created.
  # @param ref_title: [String] Title of HaramiVid etc.
  # @param date: [Date] rough date is ok.
  # @param date_for_publish: [Boolean] if true (Def), the given date is the publish date (NOT the date for Event start_time, though they would agree for live-streaming).
  # @param year: [Integer]
  # @param place_confidence: [Symbol] (:highest, :high, :middle, :low) If it is manually specified by an Editor, it is :high (or :highest).  If auto-judged in Harami1129, :low
  # @return [Event]
  def self.default(context=nil, place: nil, event_group: nil, save_event: false, ref_title: nil, date: nil, date_for_publish: true, year: nil, place_confidence: :high)
    year ||= date.year if date
    date ||= Date.new(year, 6, 30) if year
    def_event_group = (event_group || EventGroup.default(context, place: place, ref_title: ref_title, year: year))
    place = revised_place_for_default(place, def_event_group, ref_title, place_confidence: place_confidence) if ref_title

    if "live_streamings" == def_event_group.mname_to_s
      evt = default_streaming_event(place, def_event_group, ref_title, date)
    elsif !place
      return def_event_group.unknown_event
    else
      evt = default_adjust_with_place(context, place, def_event_group, date, date_for_publish: date_for_publish)
    end
    
    return evt if !save_event

    evt.save!
    evt
  end

  # @param place_confidence: [Symbol] (:highest, :high, :middle, :low) If it is manually specified by an Editor, it is :high (or :highest).  If auto-judged in Harami1129, :low
  # @return [Place]
  def self.revised_place_for_default(place, event_group, ref_title, place_confidence: :high)
    method4place = ((:low == place_confidence) ? :less_significant_than? : :encompass_strictly?)
    case event_group.mname_to_s
    when "live_streamings"
      if !place || place.unknown?
        # If the streaming is held in not the default streaming place, the Place must be registered as whatever-name (like a "random studio") but should not be an "unknown" Place in a Prefecture.
        # NOTE: more/less_significant_than does not work well because
        #   Place[default_streaming] belongs_to an "unknwon" Prefecture.
        return Place.find_by_mname(:default_streaming)
      end
    when "uk2024"
      if /ロンドン|\bLondon/i =~ ref_title
        pref = Prefecture.find_by_mname(:london)
        if pref && (!place || place.send(method4place, (pla=pref.unknown_place)))
          return (pla || pref.unknown_place)
        end
      elsif (cnt=Country.find_by(iso3166_n3_code: 826))  # Country["GBR"]
        pla = cnt.unknown_prefecture.unknown_place if !place || Place.unknown == place
      end
    when "paris2023"
      pref = Prefecture.find_by_mname(:paris)
      if pref && (!place || place.send(method4place, (pla=pref.unknown_place)))
        return (pla || pref.unknown_place)
      end
    end
    place
  end
  private_class_method :revised_place_for_default

  # @return [Event] Always new Event
  def self.default_streaming_event(place, event_group, ref_title, date)
    date_str = (date ? date.strftime("%Y-%m-%d") : TITLE_UNKNOWN_DATE)

    unsaved_transs = DEF_STREAMING_EVENT_TITLE_FORMATS.map{ |lc, fmts|
      case lc.to_s
      when "en"
        prefix = sprintf(fmts[0], date_str)  # cannot include ref_title in general because it can (and usually do) violate the "asian_characters" constraint.
      when "ja"
        prefix = sprintf(fmts[0], date_str, ref_title)
      else
        next  # should not happen for now, but playing safe
      end
      def_event_tra_new(prefix, lc, event_group, prefer_en: true)  # defined in ModuleEventAux
    }.compact  # "compact" would be needed only when "next" above is executed, which should never happen, but playing safe

    # initialize a new one
    hsin = {
      event_group: event_group,
      place: place,
    }
    if date
      hsin[:start_time] = date.to_time(:utc) + DEF_TIME_PARAMS[:UTC_OFFSET_EVENT_BEGIN]  # JST 19:00
      hsin[:start_time_err] = DEF_TIME_PARAMS[:ERR_UTC_OFFSET_STREAMING_BEGIN].in_seconds
      hsin[:duration_hour]  = DEF_TIME_PARAMS[:DURATION].in_hours
    end
  
    evt = Event.initialize_with_def_time(**hsin)

    evt.unsaved_translations = unsaved_transs
    evt
  end
  private_class_method :default_streaming_event

  # Set default Event according to Place
  #
  # "date" is taken into account.  Conceptually, general (aka default) Events
  # (in the place) can be held any time, and so the default start-time years ago
  # would be appropriate.  However, in reality, a vast majority of the default
  # Events created would be later assigned to specific Events, which happened
  # some time (days or weeks?) before the publish date. For this reason,
  # this method set the date ({#start_time}) of the Event, unless reusing
  # an existing one, at some fixed days (usually DEF_TIME_PARAMS[:DELAY_BEFORE_PUBLISH])
  # before the published date.
  #
  # However, the default duration is set at 50 years.  So, if an editor modifies the Event
  # later, they mosty likely should modify it.
  #
  # @param date_for_publish: [Boolean] if true (Def), the given date is the publish date (NOT the date for Event start_time, though they would agree for live-streaming).
  # @return [Event] unsaved, unless an exising one is found.
  def self.default_adjust_with_place(context, place, event_group, date, date_for_publish: true)
    # prepares a Hash (primarily for create, but time information is compared with that of the existing candidate if any found
    hsin = {event_group: event_group, place: place}
    if date
      date2pass = date - (date_for_publish ? DEF_TIME_PARAMS[:DELAY_BEFORE_PUBLISH] : 0)
      hsin[:start_time]     = date2pass.to_time(:utc) + DEF_TIME_PARAMS[:UTC_OFFSET_EVENT_BEGIN]  # JST 15:00 if there is publishment delay
      hsin[:start_time_err] = (date_for_publish ? DEF_TIME_PARAMS[:ERR_DELAY_BEFORE_PUBLISH] : 23.hours)
      hsin[:duration_hour]  = (date_for_publish ? DEF_TIME_PARAMS[:DURATION_DEF_EVENT] :  DEF_TIME_PARAMS[:DURATION])
    end

    events = event_group.events.where(place: place)
    if events.exists?
      DEF_EVENT_TITLE_FORMATS.each_key do |lcode|
        existing = select_regex_for_default(context=nil, langcode: lcode, place: place, event_group: event_group).first
        if existing
          if date && (!existing.start_time || date.to_time(:utc)+24.hours < existing.start_time)
            existing.update!(start_time: hsin[:start_time])
            # error and duration are unmodified.
          end
          return existing 
        end
      end
      # Though there are Events in the same EventGroup, none of them are the generalized default Event.
    end

    # initialize a new one
    evt = Event.initialize_with_def_time(**hsin)

    # Prepare Translation
    unsaved_transs = []
    DEF_EVENT_TITLE_FORMATS.each_key do |lc|
      trans = default_unsaved_trans_for_lang(place, event_group, lc)
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
  private_class_method :default_adjust_with_place


  # Returns Relation for Default Events for the given langcode (mandatory), context, place, EventGroup
  #
  # @param langcode: [String] this must be given
  # @param place: [Place] this must be given usually, unless you want the single Default Event (for the context) that has not got a Place.
  # @param event_group: [EventGroup, NilClass, Symbol] :any means any EventGroup, nil means the single default EvengGroup (for the context and Place)
  # @return [ActiveRecord::Relation]
  def self.select_regex_for_default(context=nil, langcode: nil, place: nil, event_group: :any)
    raise ArgumentError, "(${__method__}) langcode must be given." if !langcode
    return where(id: (event_group || EventGroup.default(context, place: place)).unknown_event.id) if !place
    event_group = EventGroup.default(context, place: place) if !event_group

    core = Regexp.quote(default_title_prefix_for_lang(place, langcode))
    base_select_regex = select_regex(:title, /#{core}/, langcode: langcode, sql_regexp: true)

    case event_group
    when :any
      base_select_regex 
    else
      base_select_regex.where(event_group: event_group)
    end
  end

  # @return [Translation]
  def self.default_unsaved_trans_for_lang(place, event_group, langcode)
    prefix = default_title_prefix_for_lang(place, langcode)
    def_event_tra_new(prefix, langcode, event_group, prefer_en: false)  # defined in ModuleEventAux
  end # self.default_unsaved_trans_for_lang(context: nil, place: nil)
  private_class_method :default_unsaved_trans_for_lang

  # Returns a default title or its prefix if specified so.
  #
  # @param place [Place]
  # @return [String]
  def self.default_title_prefix_for_lang(place, langcode)
    hsopts = {prefer_shorter: true, langcode: langcode, lang_fallback_option: :either, str_fallback: ""}
    place_tit = place.title_or_alt(**hsopts)
    prefe_tit = place.prefecture.title_or_alt(**hsopts)
    count_tit = place.country.title_or_alt(**hsopts)
    sprintf(DEF_EVENT_TITLE_FORMATS[langcode][0], place_tit, prefe_tit, count_tit)
  end
  private_class_method :default_title_prefix_for_lang


  # True if self if one of the default Events on the basis of the titles or {#unknown?}
  #
  # If title has been manually modified, they become by definition a human-interacted Event,
  # thus a non-default one.
  #
  # Note that self.default returns an unknown Event in some cases; that is why
  # this method returns true for the unknown.
  # @param context [String, Symbol, Array<String, Symbol>, NilClass] Default: :any. NOTE that nil means the nil-context, which differs from significant contexts!
  def default?(context=:any)
    raise "invalid method (#{__method__}) for a new record." if new_record? || !id
    return true if unknown?

    ar_context =
      if :any == context
        VALID_CONTEXTS_FOR_DEFAULT
      else
        [context].flatten
      end

    ar_context.each do |ea_context|
      DEF_EVENT_TITLE_FORMATS.each_key do |lcode|
        return true if self.class.select_regex_for_default(context=ea_context, langcode: lcode, place: place, event_group: event_group).ids.include?(id)
      end
    end

    if "live_streamings" == event_group.mname_to_s
      re_ini = DEF_STREAMING_EVENT_TITLE_FORMATS["en"][0].sub(/%s/, '(\d{4}-\d{2}-\d{2}|'+Regexp.quote(TITLE_UNKNOWN_DATE)+")")+'(-\d+)?'+Regexp.quote(DEF_STREAMING_EVENT_TITLE_FORMATS["en"][1]+sprintf(DEF_STREAMING_EVENT_TITLE_FORMATS["en"][2], event_group.best_translations["en"].title))
      return true if best_translations["en"].respond_to?(:title) && /\A#{re_ini}/ =~ best_translations["en"].title  # the former is equivalent to .present?
    end

    return false
  end

  # True if no children or if only descendants are {#unknown?} and no HaramiVid depends on self.
  def open_ended?
    !duration_hour || duration_hour > TimeAux::THRE_OPEN_ENDED.in_hours
  end

  # True if no children or if only descendants are {#unknown?} and no HaramiVid depends on self.
  def destroyable?
    return false if harami_vids.exists? || harami1129s.exists? || event_items.count > 1
    !unknown?
  end

  # Returns Hash information of consistency of Date/Time of self (<Event) and EventGroup
  #
  # @return [Hash] {start_time: , start_time_err: , duration_hour: }.with_indifferent_access, where the values are [Boolean, NilClass]. True means consistent. nil means unknown or irrelevant (like duration is nil).
  def period_consistency_with_group
    reths = {
      start_time: nil,
      start_time_err: nil,
      duration_hour: nil,
    }.with_indifferent_access

    return reths if !start_time || !event_group || !event_group.start_date && !event_group.end_date

    reths[:start_time] = true
    if (egd=event_group.start_date)
      evgr_start_time_min = (egd - (event_group.start_date_err ? event_group.start_date_err : 0).days).beginning_of_day
      reths[:start_time] = false if (start_time < evgr_start_time_min)
    end
    if (egd=event_group.end_date)
      evgr_end_time_max = (egd + (event_group.end_date_err ? event_group.end_date_err : 0).days).end_of_day
      reths[:start_time] = false if (evgr_end_time_max < start_time)
    end

    if start_time_err
      if evgr_start_time_min && evgr_end_time_max && evgr_start_time_min < evgr_end_time_max
        duration_max = evgr_end_time_max - evgr_start_time_min
        reths[:start_time_err] = (start_time_err.seconds <= duration_max)
      end
    end

    if duration_hour && evgr_end_time_max
      ev_start_time_min = (start_time_err ? start_time - start_time_err.seconds : start_time)
      reths[:duration_hour] = (ev_start_time_min + duration_hour.hours <= evgr_end_time_max)
    end

    return reths.with_indifferent_access
  end # def period_consistency_with_group
  private :period_consistency_with_group

  # @param [Symbol, String] Attribute (start_time|start_time_err|duration_hour)
  def period_consistent_with_parent_about?(att, reload: false)
    if !@period_consistencies_with_parent || reload
      @period_consistencies_with_parent = period_consistency_with_group
    end
    @period_consistencies_with_parent[att]
  end

  # Array of Attributes that are *inconsistent* 
  #
  # Here, if either of self and EventGroup has a nil period value, it is regarded as NOT inconsistent.
  #
  # @param [Array<Symbol>] (start_time|start_time_err|duration_hour)
  def period_inconsistencies_with_parent(reload: false)
    @period_consistencies_with_parent = period_consistency_with_group if !@period_consistencies_with_parent || reload
    @period_consistencies_with_parent.map{ |ek, ev|
      (false != ev) ? nil : ek.to_sym
    }.compact
  end


  # Number of Musics, counted through HaramiVidMusicAssocs:  Musics -> HaramiVidMusicAssocs -> HaramiVids -> HaramiVidEventItemAssocs -> EventItems -> Event
  def n_musics_used_in_harami_vids
    # Music.joins(:harami_vids).joins("INNER JOIN harami_vid_event_item_assocs ON harami_vid_event_item_assocs.harami_vid_id = harami_vids.id").joins("INNER JOIN event_items ON harami_vid_event_item_assocs.event_item_id = event_items.id").joins("INNER JOIN events ON event_items.event_id = events.id").where("events.id = ?", id).distinct.count
    Music.joins(harami_vids: :event_items).where("event_items.event_id" => id).distinct.count
  end 

  # Number of Musics, counted through ArtistMusicPlays:  Musics -> ArtistMusicPlays -> EventItems (<- HaramiVidEventItemAssocs) ->  Event
  def n_musics_played_in_harami_vids
    # Music.joins(:event_items).joins("INNER JOIN events ON event_items.event_id = events.id").where("events.id = ?", id).distinct.count
    Music.joins(:event_items).where("event_items.event_id" => id).distinct.count
  end 


  # Returns a new candidate pair of {#start_time} and {#start_time_err} or nil (if no need to modify or Event has no HaramiVids)
  #
  # @return [NilClass, Array<Time, Float>] return Time if start_time seems far too early for any of the associated HaramiVid (n.b., start_time_err is bigint on DB)
  def cand_new_time_if_seems_too_early
    return nil if unknown? || default?(:HaramiVid)  # start_time of Unknown or Default must be manually adjusted if ever

    hvid = harami_vids.order(:release_date).first
    return nil if !hvid

    margin = 2.days
    earliest_release_time = (hvid.release_date.to_time(:utc) + 12.hours).in_time_zone
    earliest_cand_time = earliest_release_time - ModuleHaramiVidEventAux::OFFSET_PERIOD_FROM_REFERENCE
    earliest_cand_time_err_sec = (ModuleHaramiVidEventAux::OFFSET_PERIOD_FROM_REFERENCE+24.hours).in_seconds
    if !start_time ||
       (start_time < earliest_cand_time-margin && (!start_time_err || start_time + start_time_err.seconds > earliest_release_time))
      # Basically, true if Event#start_time is months earlier than the earilies associated HaramiVid, yet its error is huge, which suggests Event#start_time is just a default value.
      return [earliest_cand_time, earliest_cand_time_err_sec]
    end

    nil
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
    EventItem.create_new_unknown!(self)
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

end

class <<  Event
  alias_method :create_basic_bwt!, :create_basic! if !self.method_defined?(:create_basic_bwt!)

  # Wrapper of {BaseWithTranslation.create_basic!}
  def create_basic!(*args, event_group: nil, event_group_id: nil, **kwds, &blok)
    event_group_id ||= (event_group ? event_group.id : EventGroup.create_basic!.id)
    super(*args, event_group_id: event_group_id, **kwds, &blok)
  end
end


