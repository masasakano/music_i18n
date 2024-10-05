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
  include HaramiVidsHelper # for set_event_event_items (common with HaramiVidsController)
  include ModuleGuessPlace  # for guess_place
  include ModuleYoutubeApiAux # defined in /app/models/concerns/module_youtube_api_aux.rb

  before_action :set_countries, only: [:create, :update] # defined in application_controller.rb

  # creates/edits a HaramiVid according to information fetched via Youtube API
  def create
    set_new_harami_vid  # set @harami_vid
    authorize! __method__, HaramiVid

    result = nil
    ActiveRecord::Base.transaction(requires_new: true) do
      create_harami_vid_from_youtube_api  # EventItem is created. unsaved_translations are added.
      result = def_respond_to_format(@harami_vid, render_err_path: "harami_vids")      # defined in application_controller.rb
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
      get_yt_channel(snippet.channel_id, filter_kind: "id") # setting @yt_channel
      channel = get_channel(snippet)
      return _return_no_channel_err(snippet) if !channel

      @harami_vid.channel = channel
      @harami_vid.duration = ActiveSupport::Duration.parse(@yt_video.content_details.duration).in_seconds
      _adjust_date(snippet)

      titles = _get_youtube_titles(snippet)
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
      return if !@yt_video

      #snippet = api.items[0].snippet
      snippet = @yt_video.snippet
      _check_and_set_channel(snippet)

      ret_msg = _adjust_youtube_titles(snippet)  # Translation(s) updated or created.
      return if !ret_msg  # Error has been raised in saving/updating Translation(s)
      flash[:notice] ||= []
      flash[:notice] << ret_msg

      _adjust_date(snippet)

      duration_s = ActiveSupport::Duration.parse(@yt_video.content_details.duration).in_seconds
      if @harami_vid.duration != duration_s 
        @harami_vid.duration = duration_s 
        flash[:notice] << "Duration is updated to #{duration_s} [s]"
      end
    end

    # Saves a new EventItem and associates it to HaramiVid
    #
    # This method is imported from HaramiVidsController#set_up_event_item_and_associate
    #
    # @todo refactoring to make this routine common!
    #
    def _set_up_event_item_and_associate()
      evit = EventItem.new_default(:HaramiVid, place: @harami_vid.place, save_event: true)

      hsopts = { publish_date: @harami_vid.release_date }
      if @harami_vid.release_date
        hsopts.merge!({start_time: @harami_vid.release_date.to_time - 30.days,
                       start_time_err: 30.days.in_seconds,})
      end
      if @harami_vid.duration
        hsopts.merge!({duration_minute:     @harami_vid.duration.seconds.in_minutes,
                       duration_minute_err: @harami_vid.duration/2.0,})
      end
      evit.update!(**hsopts)  # EventItem is always new, hence this is OK.

      @harami_vid.event_items << evit if !@harami_vid.event_items.include?(evit)
      @harami_vid.event_items.reset
    end

    # @return [NilClass]
    def _return_no_channel_err(snippet)
      msg = sprintf("Channel is not found. Define the channel first: ID=\"%s\", Name=\"%s\" [%s]", snippet.channel_id, snippet.channel_title, snippet.default_language)
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

    # Assumes the Youtube title has the default language of Japanese and it may have English title but no others.
    #
    # If the default language is English, the existence of Japanese title is not checked.
    # Also, "en-GB" etc are not taken into account (though Youtube's fallback mechanism should work).
    #
    # @return [Hash] e.g., {"ja" => "Some1", "en" => nil} (with_indifferent_access)
    def _get_youtube_titles(snippet)
      # titles = {"ja" => nil, "en" => nil}.with_indifferent_access
      titles = {}.with_indifferent_access
      titles[snippet.default_language] = preprocess_space_zenkaku(snippet.title)
      
      if "en" == snippet.default_language || snippet.localized.title == snippet.title
        # do nothing
      else
        titles["en"] = preprocess_space_zenkaku(snippet.localized.title)
      end
      titles
    end

    # Update or add {Channel.translations} according to Youtube.
    #
    # @return [String, NilClass]
    def _adjust_youtube_titles(snippet)
      raise if !current_user  # should never happen in normal calls.
      ret_msgs = []
      titles = _get_youtube_titles(snippet)  # duplication is already eliminated if present.
      [snippet.default_language, "ja", "en"].uniq.each do |elc|
        next if titles[elc].blank?
        tras = @harami_vid.translations.where(langcode: elc)
        next if tras.where(title: titles[elc]).or(tras.where(alt_title: titles[elc])).exists?  # Skip if an identical Translation exists whoever owns it.

        tra0 = tras.where(create_user_id: current_user.id).or(tras.where(update_user_id: current_user.id)).first
        if tra0 && diff_emoji_only?(tra0.title, titles[elc])  # defined in module_common.rb
          result = tra.update(title: titles[elc])
          ret_msgs << "Title[#{elc}] updated."
        else
          tra = Translation.preprocessed_new(title: titles[elc], langcode: elc, is_orig: (elc == snippet.default_language))
          @harami_vid.translations << tra
          ret_msgs << "New Title[#{elc}] added."
          result = tra.id  # Integer or nil if failed to save and associate.
        end

        if !result
          # Failed to save a Translation. The parent should rollback everything.
          msg_err = tra.errors.full_messages.join("; ") # +" / "+titles.inspect
          msg = [sprintf("ERROR: Failed to save a Translation[%s]: %s", elc, titles[elc]), msg_err].join(" / ")
          @harami_vid.errors.add :base, msg
          return nil
        end
      end

      ret_msgs.join(" ")
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
