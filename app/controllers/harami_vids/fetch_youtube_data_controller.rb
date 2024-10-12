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
  include ModuleGuessPlace  # for guess_place
  include ModuleYoutubeApiAux # defined in /app/controllers/concerns/module_youtube_api_aux.rb

  before_action :set_countries, only: [:create, :update] # defined in application_controller.rb

  # creates/edits a HaramiVid according to information fetched via Youtube API
  def create
    set_new_harami_vid  # set @harami_vid
    authorize! __method__, HaramiVid

    result = nil
    ActiveRecord::Base.transaction(requires_new: true) do
      create_harami_vid_from_youtube_api  # EventItem is created. unsaved_translations are added.
      result = def_respond_to_format(@harami_vid, render_err_path: "harami_vids")      # defined in application_controller.rb
      raise ActiveRecord::Rollback, "Force rollback." if !result
    end

    if result
      extra_str = sprintf(" / URI=<%s>", @harami_vid.uri)
      logger_after_create(@harami_vid, extra_str: extra_str, method_txt: __method__)  # defined in application_controller.rb
    end
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
      set_youtube  # sets @youtube; defined in ModuleYoutubeApiAux
      get_yt_video(@harami_vid, set_instance_var: true, model: true, use_cache_test: @use_cache_test) # sets @yt_video # defined in module_youtube_api_aux.rb
      return if !@yt_video

      snippet = @yt_video.snippet
      get_yt_channel(snippet.channel_id, kind: :id_at_platform) # setting @yt_channel
      channel = get_channel(snippet)
      return _return_no_channel_err(snippet) if !channel

      @harami_vid.channel = channel
      @harami_vid.duration = ActiveSupport::Duration.parse(@yt_video.content_details.duration).in_seconds
      _adjust_date(snippet)

      titles = get_youtube_titles(snippet)
      tras = []
      titles.each_pair do |lc, tit|
        next if tit.blank? || tit.strip.blank?
        tras << Translation.preprocessed_new(title: tit, langcode: lc.to_s, is_orig: (lc.to_s == snippet.default_language))
      end
      @harami_vid.unsaved_translations = tras

      @harami_vid.place = self.class.guess_place(titles["ja"])
      _set_up_event_item_and_associate()  # setting EventItem association; this should come after @harami_vid.place is set up.
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

    # @return [NilClass]
    def _return_no_channel_err(snippet)
      msg = sprintf("Channel is not found. Define the channel first: ID=\"%s\", Name=\"%s\" [%s]", snippet.channel_id, snippet.channel_title, (snippet.default_language || nil))
      @harami_vid.errors.add :base, msg
      nil
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

    def _adjust_date(snippet)
      date = snippet.published_at.to_date # => DateTime
      if @harami_vid.release_date != date
        flash[:notice] ||= []
        flash[:notice] << "Release-Date is updated to #{date}"
        @harami_vid.release_date = date
      end
    end

end
