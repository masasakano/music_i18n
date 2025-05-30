# -*- coding: utf-8 -*-

# Common module to implement HaramiVid and EventItem-related methods
#
# @example
#   include ModuleHaramiVidEventAux
#
# == NOTE
#
# * ENV["YOUTUBE_API_KEY"] is essential.
# * ENV["SKIP_YOUTUBE_MARSHAL"] : In testing, if this is set, marshal-ed data are not used,
#   but it accesses the remote Google/Youtube API.
# * ENV["UPDATE_YOUTUBE_MARSHAL"] : set this if you want to update the marshal-led Youtube data.
#   If this is set, ENV["SKIP_YOUTUBE_MARSHAL"] is ignored.
#   NOTE even if this is set, it does NOT create a new one but only updates an existing one(s).
#   Use instead: bin/rails save_marshal_youtube
# * +Rails.logger+ as opposed to +logger+ is preferred, becase
#   this module is included in {PrmChannelRemote}, in which case
#   +logger+ is undefined.
#
module ModuleHaramiVidEventAux
  #def self.included(base)
  #  base.extend(ClassMethods)
  #end
  extend ActiveSupport::Concern  # In Rails, the 3 lines above can be replaced with this.

  include ApplicationHelper

  # Default duration ratio of an associated EventItem to HaramiVid
  DEF_DURATION_RATIO_EVIT_TO_HVID = 1.5

  # Duration ratio error of an associated EventItem to HaramiVid.
  # For example, when this value is 1.4 and DEF_DURATION_RATIO_EVIT_TO_HVID==1.5,
  # each associated EventItem should last for at least 10% (=0.1=1.5-1.4) of
  # the duration of HaramiVid.
  DEF_DURATION_ERR_RATIO_EVIT_TO_HVID = 1.4

  # If the present start-time of EventItem is earlier than this duration,
  # it will be updated with {HaramiVid#release_date}, providing it is present,
  # as long as it does not contradict release_date of the related HaramiVids.
  # This usually happens an EventItem for a default Event is assigned to a HaramiVid,
  # where the start time of the Event is often (though not always) much earlier.
  THRE_DURATION_UPDATE_EVENT_START_TIME = 5.months

  # Automatically-assigned start-date/time is earlier than the reference point than this period
  #
  # This must be smaller than THRE_DURATION_UPDATE_EVENT_START_TIME
  OFFSET_PERIOD_FROM_REFERENCE = 1.months

  module ClassMethods
    # Returns true if {EventItem#start_time} should be updated according to HaramiVid
    #
    # == Algorithm
    #
    # New start-time would be, if updated, Reference point (that is roughly harami_vid.release_date)
    # minus OFFSET_PERIOD_FROM_REFERENCE.
    # Here, let us call it cand_epoch.
    #
    # * False if cand_epoch is (altually already) equal to or earlier than evit.start_time
    # * False if cand_epoch is later than (EarliestEpoch = Reference minus THRE_DURATION_UPDATE_EVENT_START_TIME)
    # * False if cand_epoch is later than the earliest `HaramiVid#release_date` of HaramiVids associated to evit, because cand_epoch would definitely contradict the fact the content had been published by the epoch of cand_epoch.
    # * False if cand_epoch is later than the earliest `HaramiVid#release_date` of HaramiVids that belong to the evit.event and has one of the Musics associated to evit.  In fact, if the same Music is played more than once in the Event in completely saparate occassions, this will wrongly return false, but such a situation should not happen (if ideally).
    def should_update_event_item_start_time?(evit, harami_vid)
      return false if !harami_vid.release_date
      cand_epoch = candidate_new_start_time(harami_vid)
      return false if cand_epoch <= evit.start_time  # Already adjusted or manually set

      earliest_epoch = utc_middle_of_day(harami_vid.release_date) - THRE_DURATION_UPDATE_EVENT_START_TIME # utc_middle_of_day() defined in module_common.rb
      # return false if cand_epoch < earliest_epoch  # should never happen by definition of both values
      t = evit.harami_vids.where.not("harami_vids.id = ?", harami_vid.id).pluck(:release_date).flatten.compact.sort.first 
      return false if t && t < cand_epoch

      return true if (evt=evit.event) && !evt.new_record? && evt.default?  # If Event is a default one, the next condition does not make sense because there can be many HaramiVids whose start_time/date is earlier. 

      t = evit.event.harami_vids.joins(events: {harami_vids: :harami_vid_music_assocs}).where("harami_vid_music_assocs.music_id" => evit.musics.ids).distinct.pluck(:release_date).flatten.compact.sort.first
                               # joins("INNER JOIN harami_vid_music_assocs ON harami_vid_music_assocs.harami_vid_id = harami_vids.id")
      return false if t && t < cand_epoch
      true
    end

    def candidate_new_start_time(harami_vid)
      utc_middle_of_day(harami_vid.release_date) - OFFSET_PERIOD_FROM_REFERENCE # defined in module_common.rb
    end
  end

  # Attempts to save and if fails, add errors to @harami_vid
  #
  # Check the result with @harami_vid.errors.any?
  #
  # @param model [ApplicationRecord]
  # @param harami_vid [HaramiVid]
  # @param form_attr [Symbol] usually the form's name
  # @return [ApplicationRecord, NilClass] nil if failed to save.
  def _save_or_add_error(model, harami_vid=@harami_vid, form_attr: :base)
    return model if model.save  # The returned value is not used apart from its trueness.

    # With UI, the above save should not usually fail (it is never with Channel, probably not for Music).
    model.errors.full_messages.each do |msg|
      harami_vid.errors.add form_attr, ": Existing #{model.class.name} is not found, yet failed to create a new one: "+msg
    end
    return
  end

  # Creates EventItem that will be associated to the HaramiVid by the caller
  #
  # Wrapper of {#_update_event_item_from_harami_vid}
  #
  # If failed in updating (for some reason, unexpectedly?), {HaramiVid#errors} are set for the given model.
  #
  # @param event [Event, EventItem] can be an unsaved one
  # @param harami_vid [HaramiVid]
  # @param music_name: [String, NilClass] Music title, used for a new EventItem#machine_title
  # @return [NilClass, Array<EventItem, Array<String>>] 2-elements Array or nil (if not processed at all). 1st is the created EventItem to associate to HaramiVid. 2nd is an Array of Flash messages for :warning (or nil)
  def create_event_item_from_harami_vid(evt_kind, harami_vid=@harami_vid, music_name: nil)
    evt_kind = _new_event_or_item_for_harami_vid(evt_kind, harami_vid, music_name: music_name) if evt_kind.respond_to?(:event_items) && evt_kind.id
    # The above is run in HaramiVid#create, where an existing Event is given as evt_kind.
    # When called from FetchYoutubeDataController, it is either an unsaved Event or EventItem

    if evt_kind.new_record?  # It should be always new_record?
      return if !_save_or_add_error(evt_kind)
    end

    evit = ((EventItem == evt_kind.class) ? evt_kind.reload : evt_kind.unknown_event_item)
    msgs = _update_event_item_from_harami_vid(evit, harami_vid, skip_update_start_time: false)  # defined in concerns/module_harami_vid_event_aux.rb
    [evit, msgs]
  end


  # Adjusts EventItem parameters, if there is only one associated to HaramiVid
  #
  # Duration of the EventItem is either longer or shorter than that of HaramiVid.
  # So, as long as the duration is within a reasonable range, it should not be automatically modified.
  # If not, the duration should be (usually) close to the duration of HaramiVid.
  #
  # This method updates Duration of (all) the associated EventItems, except for
  # the completely unknown EventItem.
  #
  # @param skip_update_start_time: [Boolean] if true (Def), skips updating start-time. This has a higher priority than force_update_start_time
  # @param harami_vid [HaramiVid]
  # @return [Array<String>] messages for flash[:warniing]
  def adjust_event_item_duration(harami_vid=@harami_vid, skip_update_start_time: true)
    ret_msgs = []
    return [] if harami_vid.duration.blank?

    harami_vid.event_items.reset
    harami_vid.event_items.each do |evit|
      ret_msgs.concat( _update_event_item_from_harami_vid(evit, harami_vid, skip_update_start_time: skip_update_start_time) ) # defined in concerns/module_harami_vid_event_aux.rb
    end
    ret_msgs
  end

  ################ methods for mostly internal use

  # Returns a new unsaved Event or unsaved EventItem for HaramiVid
  #
  # @param event [Event]
  # @param harami_vid [HaramiVid]
  # @param music_name: [String, NilClass] Music title, used for a new EventItem#machine_title
  # @return [Event, EventItem] Either unsaved Event or unsaved EventItem
  def _new_event_or_item_for_harami_vid(event, harami_vid=@harami_vid, music_name: nil)
    opts = 
      if event.default? && harami_vid.place.present? && (!event.place || event.place.encompass_strictly?(harami_vid.place))
        {place: harami_vid.place, event_group: event.event_group} # => unsaved Event or unsaved EventItem
      else
        {event: event} # => unsaved EventItem
      end
    EventItem.new_default(:HaramiVid, music_name, save_event: false, **opts)
  end

  # Updates publish_date, (optionally) start_time, duration and their erros of the EventItem, using information from the HaramiVid
  #
  # The EventItem should be associated to the HaramiVid.
  #
  # Basically, for a new EventItem, +skip_update_start_time+ should be explicitly set false.
  #
  # If failed in updating (for some reason, unexpectedly?), {HaramiVid#errors} are set for the given model.
  #
  # @param evit [EventItem]
  # @param harami_vid [HaramiVid]
  # @param skip_update_start_time: [Boolean] if true (Def), skips updating start-time. This has a higher priority than force_update_start_time
  # @param force_update_start_time: [Boolean] if true (Def: false), start-time is always updated as long as {HaramiVid#release_date} is present.
  # @return [NilClass, Array<String>] Array of String messages for Flash[:warning] or nil
  def _update_event_item_from_harami_vid(evit, harami_vid=@harami_vid, skip_update_start_time: true, force_update_start_time: false)
    hsin, ret_msgs = _hs_update_event_item_from_harami_vid(evit, harami_vid, skip_update_start_time: skip_update_start_time, force_update_start_time: force_update_start_time)

    if !hsin.empty? && !evit.update(hsin)
      evit.errors.full_messages.each do |em|
        harami_vid.errors.add :base, "Failed in updating an EventItem: "+em
      end
    end

    ret_msgs
  end


  # Returns a Hash to be used to update publish_date, (optionally) start_time, duration and their erros of an EventItem, using information from the HaramiVid
  #
  # The EventItem should be associated to the HaramiVid.
  #
  # @param evit [EventItem]
  # @param harami_vid [HaramiVid]
  # @param skip_update_start_time: [Boolean] if true (Def), skips updating start-time. This has a higher priority than force_update_start_time
  # @param force_update_start_time: [Boolean] if true (Def: false), start-time is always updated as long as {HaramiVid#release_date} is present.
  # @return [Array<Hash, Array<String>>] 2-elements Array of Hash and an Array of String messages for Flash[:warning]
  def _hs_update_event_item_from_harami_vid(evit, harami_vid=@harami_vid, skip_update_start_time: true, force_update_start_time: false)
    hsin = {}.with_indifferent_access
    if harami_vid.release_date && (!evit.publish_date || (harami_vid.release_date < evit.publish_date))
       hsin[:publish_date] = harami_vid.release_date 
    end

    ret_msgs = []
    hs, msg = _hs_adjust_event_item_start_time(evit, harami_vid, force_update: force_update_start_time) if !skip_update_start_time
    hsin.merge!(hs) if hs
    ret_msgs << msg if msg

    hs, msg = _hs_adjust_event_item_duration(evit, harami_vid)
    hsin.merge!(hs) if hs.present?
    ret_msgs << msg if msg

    [hsin, ret_msgs]
  end

  # Retuns a Hash to update StartTime and error of the (would-be) associated EventItem based on HaramiVid
  #
  # @param evit [EventItem]
  # @param harami_vid [HaramiVid]
  # @param force_update: [Boolean] if true (Def: false), start-time is always updated as long as {HaramiVid#release_date} is present.  This is ignored in updating Duration.
  # @return [NilClass, Array<Hash, String>] 2-elements Array or nil (if not processed at all). 1st is the Hash to update a model. 2nd is a Flash message (or nil)
  def _hs_adjust_event_item_start_time(evit, harami_vid=@harami_vid, force_update: false)
    return if !force_update && !self.class.should_update_event_item_start_time?(evit, harami_vid)

    new_start_time = self.class.candidate_new_start_time(harami_vid)
    hvid_time = (harami_vid.release_date ? harami_vid.release_date : Date.current).beginning_of_day
    ev_err = ((er=(evit.event ? evit.event.start_time_err : evit.start_time_err)) ? er : Float::INFINITY).seconds
    if (new_start_time < evit.start_time) ||
       (evit.start_time < new_start_time && ev_err.in_milliseconds != Float::INFINITY && (evit.start_time + ev_err) < hvid_time) # nb., (Time + Float::INFINITY).seconds) would return FloatDomainError
      hsret = {start_time: evit.start_time, start_time_err: ((ev_err.in_milliseconds/1000.0 == Float::INFINITY) ? [OFFSET_PERIOD_FROM_REFERENCE, ].max.seconds : ev_err).in_milliseconds/1000.0} # NOTE: Float::INFINITY.seconds.in_seconds raises FloatDomainError
      return [hsret, nil]
    end

    hsret = {start_time: new_start_time, start_time_err: (new_err=OFFSET_PERIOD_FROM_REFERENCE).in_seconds}.with_indifferent_access
    msg = sprintf("Start time of the (newly created?) EventItem (pID=%d) is adjusted to (%s) with an error of %f days, based on the release-date (%s) of the HaramiVid. If it is incorrect (in rare cases), edit the EventItem.", evit.id, new_start_time, new_err.in_days, harami_vid.release_date)
    [hsret, msg]
  end
      

  # Retuns a Hash to update Duration and error of the (would-be) associated EventItem based on HaramiVid
  #
  # @param evit [EventItem]
  # @param harami_vid [HaramiVid]
  # @return [NilClass, Array<Hash, String>] 2-elements Array or nil (if not processed at all). 1st is the Hash to update a model. 2nd is a Flash message (or nil)
  def _hs_adjust_event_item_duration(evit, harami_vid=@harami_vid)
    msg = nil
    hsret = {}.with_indifferent_access
    return if !harami_vid.duration ||
              (harami_vid.duration < 1.5) ||  # [seconds] -- unreasonably small
              (evit.unknown? && evit.event.unknown?)  # If a completely unknown EventItem, leaves its duration

    evit_min_num = ((dum=evit.duration_minute) ? dum : Float::INFINITY)
    new_duration_minute = [(harami_vid.duration.seconds.in_minutes * DEF_DURATION_RATIO_EVIT_TO_HVID).ceil,
                           evit_min_num].min.to_f

    if evit.open_ended? || evit.duration_minute < 0.9  # evit.duration_minute is defined if NOT open_ended, 
      # Continue processing
    else
      if evit.event.duration_hour
        return if (evit.event.duration_hour*60*0.99 > evit.duration_minute)
      else
        return if (evit.duration_minute > new_duration_minute)
        msg = :should_be_set
      end
    end

    msg_add = ""
    if evit.unknown?
      msg = :should_be_set 
      msg_add = "('Unknown') "
    end

    hsret[:duration_minute] = new_duration_minute

    # Error value adjustment
    vnow = evit.duration_err_with_unit
    if vnow.blank? || vnow > TimeAux::THRE_OPEN_ENDED || (vnow == EventItem::DEFAULT_NEW_TEMPLATE_DURATION_ERR)
      val = [(harami_vid.duration.seconds.in_minutes * DEF_DURATION_ERR_RATIO_EVIT_TO_HVID).ceil, evit_min_num].min.to_f
      hsret[:duration_minute_err] = EventItem.num_with_unit_to_db_duration_err(val.minutes)
    end

    msg &&= sprintf("Duration of %sEventItem (pID=%d) is adjusted from (%s) to (%f) [min] with an error of %s, based on the duration (%f [min]) of the HaramiVid. If it is incorrect (in rare cases), edit the EventItem.",
                    msg_add,
                    evit.id,
                    evit.duration_minute.inspect,
                    new_duration_minute,
                    vnow.inspect,
                    harami_vid.duration.seconds.in_minutes)
    [hsret, msg]
  end

end

