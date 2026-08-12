# coding: utf-8
# require "unicode/emoji"
# require "google/apis/youtube_v3"
#
# == NOTE
#
# * ENV["YOUTUBE_API_KEY"] is essential.
# * ENV["UPDATE_YOUTUBE_MARSHAL"] : set this if you want to *update* the marshal-ed Youtube data.
# * ENV["SKIP_YOUTUBE_MARSHAL"] : In testing, if this is set, marshal-ed data are not used.
class HaramiVids::FetchYoutubeDataController < ApplicationController
  include ApplicationHelper
  include ModuleHaramiVidEventAux # some constants and methods common with HaramiVids::FetchYoutubeDataController
  include HaramiVidsHelper # for set_event_event_items (common with HaramiVidsController)
  include ModuleYoutubeApiAux # defined in /app/controllers/concerns/module_youtube_api_aux.rb

  before_action :set_countries, only: [:create, :update] # defined in application_controller.rb

  # creates/edits a HaramiVid according to information fetched via Youtube API
  def create
    set_new_harami_vid  # set @harami_vid
    authorize! __method__, HaramiVid

    result = nil
    ActiveRecord::Base.transaction(requires_new: true) do
      # create_harami_vid_from_youtube_api  # EventItem is created. unsaved_translations are added.
      new_harami_vid_from_youtube_api(@harami_vid, uri: nil, flash_on_error: true, use_cache_test: @use_cache_test) # may issue warning about the lack of the registered Channel # defined in ModuleYoutubeApiAux
      _chk_translation_after_youtube_loading  # Additional Translation-s appended to HaramiVid#note

      result = _set_respond_to_format(@harami_vid)
      raise ActiveRecord::Rollback, "Force rollback." if !result
    end

    preheader = (result ? "Loaded" : "Something went wrong during preparing a new HaramiVid by importing information")
    extra_str = sprintf(" / URI=<%s>", @harami_vid.uri)
    logger_after_create(@harami_vid, extra_str: extra_str, method_txt: "HaramiVids::FetchYoutubeDataController#"+__method__.to_s, header_txt: preheader+" from Youtube for")  # defined in application_controller.rb
  end

  # edits a HaramiVid according to information fetched via Youtube API
  def update
    set_harami_vid  # set @harami_vid
    authorize! __method__, @harami_vid

    ActiveRecord::Base.transaction(requires_new: true) do
      update_harami_vid_with_youtube_api
      result = def_respond_to_format(@harami_vid, :updated, render_err_path: "harami_vids")      # No update is run if @harami_vid.errors.any? ; defined in application_controller.rb
      raise ActiveRecord::Rollback, "Force rollback." if !result
    end
  end

  private
    # set @harami_vid from a given URL parameter
    def set_new_harami_vid
      @harami_vid = HaramiVid.new  # If returns nil below, this will eventually raise an ERROR with non-existtent URI
      safe_params = params.require(:harami_vid).require(:fetch_youtube_datum).permit(:uri_youtube, :use_cache_test)
      @use_cache_test = get_bool_from_params(safe_params[:use_cache_test]) # defined in application_helper.rb
      uri = safe_params[:uri_youtube]
      return if uri.blank?
      @harami_vid = HaramiVid.new(uri: ApplicationHelper.uri_youtube(uri, with_http: false))
    end

    # set @harami_vid from a given URL parameter
    def set_harami_vid
      @harami_vid = nil
      safe_params = params.require(:harami_vid).require(:fetch_youtube_datum).permit(:use_cache_test)
      @use_cache_test = get_bool_from_params(safe_params[:use_cache_test]) # defined in application_helper.rb

      harami_vid_id = params[:id]
      return if harami_vid_id.blank?  # should never happen
      @harami_vid = HaramiVid.find(harami_vid_id)
      set_event_event_items  # sets @event_event_items  defined in harami_vids_helper.rb
    end

    # this is within a DB transaction (see {#create})
    def create_harami_vid_from_youtube_api
      new_harami_vid_from_youtube_api(@harami_vid, uri: nil, flash_on_error: false, use_cache_test: @use_cache_test) # defined in ModuleYoutubeApiAux
      return if !@harami_vid.channel

      # _set_up_event_item_and_associate()  # setting EventItem association; this should come after @harami_vid.place is set up.
    end

    # this is within a DB transaction (see {#update})
    def update_harami_vid_with_youtube_api
      set_youtube  # sets @youtube; defined in ModuleYoutubeApiAux
      get_yt_video(@harami_vid, set_instance_var: true, model: true, use_cache_test: @use_cache_test) # sets @yt_video # defined in module_youtube_api_aux.rb
      if !@yt_video
        @harami_vid.errors.add :base, "URI appears to be either wrong (non-existent) or a non-Youtube one: #{@harami_vid.uri}"
        return
      end

      snippet = @yt_video.snippet
      _check_and_set_channel(snippet)

      ret_msg = adjust_youtube_titles(snippet, model: @harami_vid)  # Translation(s) updated or created.
      return if !ret_msg  # Error has been raised in saving/updating Translation(s)
      flash[:notice] ||= []
      flash[:notice] << ret_msg if ret_msg.present?

      _adjust_date(snippet)

      duration_s = ActiveSupport::Duration.parse(@yt_video.content_details.duration).in_seconds
      if @harami_vid.duration != duration_s 
        @harami_vid.duration = duration_s 
        flash[:notice] << "Duration is updated to #{duration_s} [s]"
      end

      msgs = adjust_event_item_duration(@harami_vid, skip_update_start_time: false)  # defined in concerns/module_harami_vid_event_aux.rb  # Update the start_time/err as well.
      if !msgs.empty?
        flash[:warning] ||= []
        flash[:warning].concat msgs
      end
    end

    # Saves a new EventItem and associates it to a new HaramiVid
    #
    # == OBSOLETE (called by none) ==
    #
    # This method is imported from HaramiVidsController#set_up_event_item_and_associate
    #
    # @todo refactoring to make this routine common!
    #
    def _set_up_event_item_and_associate()
      evt_kind =  EventItem.new_default(:harami1129, place: @harami_vid.place, save_event: false,
                                        ref_title: @harami_vid.unsaved_translations.first.title,
                                        date: @harami_vid.release_date, place_confidence: :low)  # Either Event or EventItem

      evit, msgs = create_event_item_from_harami_vid(evt_kind, harami_vid=@harami_vid)  # defined in concerns/module_harami_vid_event_aux.rb

      if evit && msgs.present?  # evit should be always present when msgs is present, but playing safe
        flash[:warning] ||= []
        flash[:warning].concat msgs if msgs.present?
      end
      return if !evit || evit.errors.any?

      @harami_vid.event_items << evit if !@harami_vid.event_items.include?(evit)
      @harami_vid.event_items.reset
    end

    # For update. @harami_vid.channel is set if possible.
    # @return [void]
    def _check_and_set_channel(snippet)
      channel = get_channel(snippet)
      if @harami_vid.channel && channel && @harami_vid.channel == channel
        # Fully consistent. do nothing
      elsif !@harami_vid.channel && channel
        @harami_vid.channel = channel
        logger.info "Channel (ID=#{channel.id}: #{channel.title}) is newly defined for HaramiVid (ID=#{@harami_vid.id})."
      else
        ch = @harami_vid.channel
        msg = sprintf("WARNING: The currently associated Channel (ID=%s: %s) to HaramiVid (ID=%d) is inconsistent with that (ID=%s) inferred from Youtube (ID=%s: %s)", (ch ? ch.id : "nil"), (ch ? ch.title_or_alt(lang_fallback_option: :either, article_to_head: true).inspect : '""'), @harami_vid.channel.id, (channel ? channel.id : "nil"), snippet.channel_id, snippet.channel_title)
        flash[:warning] ||= []
        flash[:warning] << msg
        logger.warn msg
      end
    end

    # Check Translation-s after loading from Youtube
    #
    # From Youtube, you may load titles in multiple languages.
    # However, in HarmaiVid :new, you cannot reflect multiple-language {Translation}-s.
    # This method writes {HarmaiVid#note} when multiple Translation-s are available.
    def _chk_translation_after_youtube_loading
      return if (ntrans=@harami_vid.unsaved_translations.size) <= 1
      @harami_vid.note ||= ""
      @harami_vid.note += " <br>" if @harami_vid.note.present?
      exclude_langcode = @harami_vid.best_translation.langcode
      notes2add = []
      flash[:warning] ||= []
      lcodes = []
      @harami_vid.unsaved_translations.each do |ea_tra|
        next if exclude_langcode == ea_tra.langcode
        lcodes << ea_tra.langcode
        msg = ERB::Util.html_escape(sprintf("[%s] %s", ea_tra.langcode, ea_tra.title))
        notes2add << msg
        flash[:warning] << ("Not added Translation " + msg).html_safe
      end
      @harami_vid.note += notes2add.join(" <br>")  ## NOTE: method "<<" does not work?
      flash[:warning] << sprintf("WARNING: multiple (=%d) Translations are found. Appended to note Translations in %s", ntrans, lcodes.inspect)
    end

    # respond_to_format
    #
    # This does NOT save the instance.
    #
    # @return [Boolean] true if normal ends (no errors)
    def _set_respond_to_format(harami_vid)
      result = !harami_vid.errors.any?
      respond_to do |format|
        if result
          msg = 'Remote parameters were successfully loaded.'
          opts = get_html_safe_flash_hash(success: msg.html_safe)
          flash[:success] = opts[:success]
          format.html { render "harami_vids/new", **opts}
          format.json { render "harami_vids/new", status: :ok, location: new_harami_vid_path }
        else
          hsstatus = {status: :unprocessable_content}
          format.html { render "harami_vids/new",     **hsstatus }
          format.json { render json: harami_vid.errors, **hsstatus }
        end
      end
      result
    end
end
