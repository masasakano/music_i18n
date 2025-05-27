# coding: utf-8
# require "unicode/emoji"
#
class EventItems::ResettleNewEventsController < ApplicationController
  include ModuleCommon  # for preprocess_space_zenkaku
  include ModuleHaramiVidEventAux # for _hs_adjust_event_item_duration
  include ModuleEventAux::ClassMethods # for self.def_event_title_postfix
  include ModuleHaramiVidEventAux  # for _update_event_item_from_harami_vid

  # When Event Title is not found AT ALL (which should never happen), this is used.
  FALLBACK_EVENT_TITLE = "EventWithNoTitle"

  # Default Duration ratio of Event to EventItem
  DEF_DURATION_RATIO_EVENT_TO_ITEM = 2

  def update
    set_event_item  # sets @event_item
    authorize! __method__, @event_item  # this suffices b/c if one is allowed to update EventItem, they should be allowed to create an Event for it, too.

    ActiveRecord::Base.transaction(requires_new: true) do
      # NOTE: This transaction should not need to accommodate the first half of the block below
      #   before def_respond_to_format().  But, playing safe.
      if set_harami_vid  # sets @harami_vid
        set_new_event  # sets @event.  It is new and unsaved, yet.
        # raise "EventItem should have errors when Event has errors!!! Check it out. Errs=#{@event.errors.inspect}" if @event_item.errors.any?  # sanity check

raise if @event.id
        if @event
          update_event_item_no_save # if @event && !@event.errors.any? && !@event_item.errors.any?
          if @event_item.duration_minute && (!@event.duration_hour || @event.duration_hour > 5.days.in_hours)
            # If Event#duration_hour is default, it should be updated.
            @event.duration_hour = (@event_item.duration_minute*DEF_DURATION_RATIO_EVENT_TO_ITEM).minutes.in_hours
          end
        end
      else
        @event_item.errors.add :base, "No HaramiVid is defined. Hence no Event can be created for this EventItem."
      end

      result = def_respond_to_format(@event_item, :updated, render_err_path: "event_items"){ 
        break nil if !@event
        if @event.save
          @event_item.event = @event  # This is actually redundant because the unsaved one is already set.
          @event_item.save
        else
          @event.errors.full_messages.each do |emsg|
            @event_item.errors.add :base, "Error in saving a new Event: "+emsg
          end
          false
        end
      } # defined in application_controller.rb
      raise ActiveRecord::Rollback, "Force rollback." if !result
    end
  end

  private

    # set @event_item from a given URL parameter
    def set_event_item
      @event_item = nil
      # safe_params = params.require(:event_item).require(:resettle_new_event).permit(:...)

      event_item_id = params[:id]
      return if event_item_id.blank?  # should never happen. This will fail in authorization.
      @event_item = EventItem.find(event_item_id)
    end

    # sets @harami_vid
    #
    # @return [HaramiVid, NilClass] returns @harami_vid
    def set_harami_vid
      if !@event_item.harami_vids.exists?
        @event_item.errors.add :base, "No HavamiVid is associated to this EventItem, hence failing in creating a new Event based on it."
        return
      elsif @event_item.harami_vids.count != 1
        @event_item.errors.add :base, "Multiple HavamiVids are associated to this EventItem. You must manually create a new parent Event, should you wish."
        return
      end
      @harami_vid = @event_item.harami_vids.first
    end


    # set the new @event from @event_item
    #
    def set_new_event
      old_event = @event_item.event

      # If EventItem has only one HaramiVid, its start_time may be modified.  EventItem is updated on DB here.
      if 1 == @event_item.harami_vids.count && (evitstt=@event_item.start_time) && (evgrstd=@event_item.event_group&.start_date) && (evitstt.to_date - evgrstd).abs <= 10
        hvid = @event_item.harami_vids.first
        set_event_item_duration(skip_update_start_time: false)
        if hvid.errors.any?
          add_flash_message(:warning, hvid.errors.full_messages)
        end
      end

      # old_event.dup has pretty much all the information, because only direct :has_many
      # of an Event are EventItem-s and Translation-s, and the rest is through
      # EventItems. The EventItem will migrate (resettle) to the new Event in this Controller.
      # Translation will be of course created.
      @event = old_event.dup
      @event.start_time     = @event_item.start_time     if @event_item.start_time 
      @event.start_time_err = @event_item.start_time_err if @event_item.start_time_err
      @event.duration_hour = 
        if @event_item.duration_minute
          @event_item.duration_minute * 60
        else
          [(@event.duration_hour || Event::DEF_TIME_PARAMS[:DURATION]), Event::DEF_TIME_PARAMS[:DURATION]].min
        end

      @event.unsaved_translations = _new_evt_tras
      @event.place = _most_significant_place
      msg = sprintf("Resettled from %s (pID=%d) on %s",
                    ActionController::Base.helpers.link_to("EventItem", event_item_path(@event_item)),
                    @event_item.id,
                    Date.current.to_s)
      @event.memo_editor = [((existing=@event.memo_editor).blank? ? nil : existing), msg].join(" ") 
    end

    def update_event_item_no_save
      return if !@event
      @event_item.machine_title = _updated_machine_title
      @event_item.event = @event
      @event_item.place = @event.place  # most significant one should have been set already
      set_event_item_duration
    end

    # Update (without save) publish_date, (optionally) start_time, duration and their erros of an EventItem, using information from the HaramiVid
    #
    # The default parity for Option skip_update_start_time is opposite to in the original module_harami_vid_event_aux.rb
    def set_event_item_duration(harami_vid=@harami_vid, skip_update_start_time: false)
      return if !harami_vid
      hs2update, ret_msgs = _hs_update_event_item_from_harami_vid(@event_item, harami_vid, skip_update_start_time: skip_update_start_time, force_update_start_time: false)  # defined in module_harami_vid_event_aux.rb
      if ret_msgs.present?
        flash[:warning] ||= []
        flash[:warning].concat ret_msgs
      end

      hs2update.each_pair do |ek, ev|
        @event_item.send(ek.to_s+"=", ev)
      end
    end

    # New Translations for the Event
    #
    # @return [Array<Translation>] may be empty.
    def _new_evt_tras
      arret = []
      @harami_vid.best_translations.keys do |langcode|
        arret << _new_evt_tra(langcode.to_s)
      end

      return arret if !arret.compact.empty?

      [_new_evt_tra("ja", lang_fallback_option: :either)]
    end

    # New Translation (for Event) for the language
    #
    # @param langcode [String]
    # @param lang_fallback_option: [Symbol] :never (Dev), :eitheretc. See BaseWithTranslation
    # @return [Translation, NilClass] If the title of the Translation for the language is not found, returns nil.
    def _new_evt_tra(langcode, lang_fallback_option: :never)
      tra = @harami_vid.best_translations[langcode]
      str_fallback = ((:never == lang_fallback_option) ? nil : FALLBACK_EVENT_TITLE)
      str = @harami_vid.title_or_alt(prefer_shorter: true, langcode: langcode, lang_fallback_option: lang_fallback_option, str_fallback: str_fallback, article_to_head: true)
      return nil if !str

      tit_prefix = preprocess_space_zenkaku(str.gsub(Unicode::Emoji::REGEX, " "), article_to_tail=false, strip_all: true)  # Regex in require "unicode/emoji"
      ##tit = tit_prefix + self.try_load(langcode, @event.event_group, prefer_en: true) 
      #tit = tit_prefix + def_event_title_postfix(langcode, @event.event_group, prefer_en: true) 
      ret_lcode = (contain_asian_char?(tit_prefix) ? "ja" : langcode) # defiend in ModuleCommon

      Translation.new(langcode: ret_lcode, is_orig: (tra ? tra.is_orig : nil), title: tit_prefix)
    end

    # EentItem.place should be the narrowest.
    def _most_significant_place
      pla_cand = (@event_item.place || Place.unknown)
      pla = @event.place 
      pla_cand = pla if pla && pla_cand.encompass_strictly?(pla)
      if @harami_vid.respond_to?(:place)  # future-proof
        pla = @harami_vid.place 
        pla_cand = pla if pla && pla_cand.encompass_strictly?(pla)
      end
      pla_cand
    end

    # Default Prefix is the Music title of HaramiVid, else "item"
    #
    # @return [String] New machine_title. Uniqueness is guaranteed; this ultimately calls get_unique_string in /app/models/concerns/module_application_base.rb
    def _updated_machine_title
      _, postfix = EventItem.unknown_machine_title_prefix_postfix(@event)
      prefix = (@event_item.music_prefix_for_nominal_unique_title(harami_vid: @harami_vid) || DEFAULT_UNIQUE_TITLE_PREFIX)  # cf. EventItem#nominal_unique_title

      EventItem::get_unique_title(prefix, postfix: postfix)
    end

end
