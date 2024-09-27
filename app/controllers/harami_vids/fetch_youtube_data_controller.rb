# coding: utf-8
# require "unicode/emoji"
# require "google/apis/youtube_v3"
#
# == NOTE
#
# * ENV["YOUTUBE_API_KEY"] is essential.
# * ENV["UPDATE_YOUTUBE_MARSHAL"] : set this if you want to update the marshal-led Youtube data.
class HaramiVids::FetchYoutubeDataController < ApplicationController
  include ApplicationHelper

  FROOT_YOUTUBE_ZENZENZENSE = {
    snippet:        "youtube_zenzenzense_snippet",
    contentDetails: "youtube_zenzenzense_contentDetails",
  }.with_indifferent_access

  # creates/edits a HaramiVid according to information fetched via Youtube API
  def create
    set_new_harami_vid  # set @harami_vid
    authorize! :create, HaramiVid
    authorize! __method__, HaramiVid

    create_harami_vid_from_youtube_api  # unsaved_translations are added.
    result = def_respond_to_format(@harami_vid)      # defined in application_controller.rb

    if result
      extra_str = sprintf(" / URI=<%s>", @harami_vid.uri)
      logger_after_create(@harami_vid, extra_str: extra_str, method_txt: __method__)  # defined in application_controller.rb
    end
#    result = def_respond_to_format(@harami_vid, created_updated: :created, back_html: "&ldquo;HaramiVid&rdquo; page") # defined in application_controller.rb
#
#    # Adjusts each Translation's update_user and updated_at if there is an equivalent user.
#    # These are not critical and so not included in DB-Transaction in the save above.
#    if result
#      @harami_vid.update_user_for_equivalent_harami_vid
#    end
  end

  # edits a HaramiVid according to information fetched via Youtube API
  def update
    set_harami_vid  # set @harami_vid
    authorize! __method__, @harami_vid

    ActiveRecord::Base.transaction(requires_new: true) do
      update_harami_vid_with_youtube_api
      result = def_respond_to_format(@harami_vid)      # No update is run if @harami_vid.errors.any? ; defined in application_controller.rb
    end
  end

  private
    # set @harami_vid from a given URL parameter
    def set_new_harami_vid
      @harami_vid = nil
      safe_params = params.require(:harami_vid).require(:fetch_youtube_data).permit(:uri_youtube, :use_cache_test)
      @use_cache_test = !!safe_params[:use_cache_test]
      uri = safe_params[:uri_youtube]
      return if uri.blank? 
      @harami_vid = HaramiVid.new(uri: ApplicationHelper.uri_youtube(uri, with_http: false))
    end

    # set @harami_vid from a given URL parameter
    def set_harami_vid
      @harami_vid = nil
      safe_params = params.require(:harami_vid).require(:fetch_youtube_datum).permit(:use_cache_test)
      @use_cache_test = !!safe_params[:use_cache_test]

      harami_vid_id = params.require(:harami_vid)[:id]
      return if harami_vid_id.blank?
      @harami_vid = HaramiVid.find(harami_vid_id)
    end

    # set @youtube
    def set_youtube
      @youtube = Google::Apis::YoutubeV3::YouTubeService.new
      @youtube.key = ENV["YOUTUBE_API_KEY"]  # or else
      if @youtube.blank?
        msg = "ERROR: ENV[YOUTUBE_API_KEY] undefined."
        logger.error()
        raise msg
      end
    end

    def create_harami_vid_from_youtube_api
      set_youtube  # sets @youtube
      api = _get_youtube_api_videos  # This sets @id_youtube
      return if !api

      snippet = api.items[0].snippet
      channel = _get_channel(snippet)
      return _return_no_channel_err(snippet) if !channel

      @harami_vid.channel = channel
      @harami_vid.duration = _get_youtube_duration.in_seconds

      titles = _get_youtube_titles(snippet)
      tras = []
      titles.each_pair do |lc, tit|
        next if tit.blank? || tit.strip.blank?
        tras << Translation.preprocessed_new(title: tit, langcode: lc.to_s, is_orig: (lc.to_s == snippet.default_language))
      end
      @harami_vid.unsaved_translations = tras
    end

    # Returns 2-element Array of @youtube.list_videos and fullpath, if recovering them from marshalled
    #
    # @param root_kwd [String] root filename for the marshal-led data.
    # @return [Array<Hash,String,NilClass>] 2-element Array of [Hash(Google::Apis::YoutubeV3), String(full-path)] or [nil, nil]
    def _get_youtuberet_fullpath(root_kwd)
      return [nil, nil] if !@use_cache_test 

      fullpath = get_fullpath_test_data(/^#{Regexp.quote(root_kwd)}/)  # defined in application_helper.rb
      return [nil, nil] if !fullpath

      [Marshal.load(IO.read(fullpath)), fullpath]
    end

    # Save the marshal-led Youtube-API-Hash if all the conditions satisfy.
    #
    # The data are saved if :
    #
    # * The given +fullpath+ is present, AND
    # * +ENV["UPDATE_YOUTUBE_MARSHAL"]+ is set.
    #
    # @param hsdata [Hash] Youtube API return
    # @param fullpath [String] to save.
    # @return [String, NilClass>] If saved, the given fullpath is returned, else nil.
    def _may_save_youtuberet_martial(hsdata, fullpath)
      return nil if !(fullpath && is_env_set_positive?("UPDATE_YOUTUBE_MARSHAL"))
      open(fullpath, "w"){|io|
        io.write(Marshal.dump(hsret))
      }
      return fullpath
    end

    #
    # If use_cache_test is specified and ENV["UPDATE_YOUTUBE_MARSHAL"] is set,
    # the test data in /fixture/data is updated.
    #
    # @return [Google::Apis::YoutubeV3, NilClass] Youtube-API object or nil if the platform is not Youtube
    def _get_youtube_api_videos
      @id_youtube = ApplicationHelper.get_id_youtube_video(@harami_vid.uri)

      if @id_youtube.respond_to?(:platform) && :youtube != @id_youtube.platform
        @harami_vid.errors.add :base, "Non-Youtube video is unsupported."
        return nil
      end

      part = "snippet"
      hsret, fullpath = _get_youtuberet_fullpath(FROOT_YOUTUBE_ZENZENZENSE[part])

      hsret ||= @youtube.list_videos("snippet", id: @id_youtube, hl: "en")  # maxResults is invalid with "id"
      _may_save_youtuberet_martial(hsret, fullpath)
      hsret
    end

    # Returns ActiveSupport::Duration of the Youtube video
    #
    # If use_cache_test is specified and ENV["UPDATE_YOUTUBE_MARSHAL"] is set,
    # the test data in /fixture/data is updated.
    #
    # @return [ActiveSupport::Duration]
    def _get_youtube_duration
      part = "contentDetails"
      hsret, fullpath = _get_youtuberet_fullpath(FROOT_YOUTUBE_ZENZENZENSE[part])

      hsret ||= @youtube.list_videos(part, id: @id_youtube, hl: "en")  # duration etc.
      _may_save_youtuberet_martial(hsret, fullpath)

      # Duration is in ISO8601 format, e.g., "PT4M5S"
      ActiveSupport::Duration.parse(hsret.items[0].content_details.duration)
    end
    
    # @return [Channel, NilClass]
    def _get_channel(snippet)
      channel = Channel.find_by(id_at_platform: snippet.channel_id)
      return channel if channel

      chan_type_youtube = ChannelType.select_by_translations(en: {title: 'Youtube'}).first
      return Channel.where(channel_type_id: chan_type_youtube.id).select_regex(:title, /^#{Regexp.quote(snippet.channel_title)}\b/, langcode: snippet.default_language, sql_regexp: true).first  # based on the human-readable Channel name.  nil is returned if not found.
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
      channel = _get_channel(snippet)
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
    # @return [Hash] e.g., {"ja" => "Some1", "en" => nil}
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

    #
    # @return [String, NilClass]
    def _adjust_youtube_titles(snippet)
      raise if !current_user  # should never happen in normal calls.
      ret_msgs = []
      titles = _get_youtube_titles(snippet)
      [snippet.default_language, "ja", "en"].uniq.each do |elc|
        tras = @harami_vid.translations.where(langcode: elc)
        next if tras.where(title: titles[elc]).or.where(alt_title: titles[elc]).exists?  # Skip if an identical Translation exists whoever owns it.

        tra0 = tras.where(create_user_id: current_user.id).or.where(update_user_id: current_user.id).first
        if tra0 || diff_emoji_only?(tra0.title, titles[elc])  # defined in module_common.rb
          tra0.title = titles[elc]
          tra = tra0
          ret_msgs << "Title[#{elc}] updated."
        else
          tra = Translation.preprocessed_new(title: titles[elc], langcode: elc, is_orig: (elc == snippet.default_language))
          ret_msgs << "New Title[#{elc}] added."
        end

        result = tra.save
        if !result
          ret_msgs.pop
          msg = sprintf("ERROR: Failed to save a Translation[%s]: %s", elc, titles[elc])
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

    def update_harami_vid_with_youtube_api
      set_youtube  # sets @youtube
      api = _get_youtube_api_videos  # This sets @id_youtube
      return if !api  # @harami_vid.errors is set.

      snippet = api.items[0].snippet
      _check_and_set_channel(snippet)

      ret = _adjust_youtube_titles(snippet)  # Translation(s) updated or created.
      return if ret.blank?
      flash[:notice] ||= []
      flash[:notice] << ret

      _adjust_date(snippet)

      duration_s = _get_youtube_duration.in_seconds
      if @harami_vid.duration != duration_s 
        @harami_vid.duration = duration_s 
        flash[:notice] << "Duration is updated to #{duration_s} [s]"
      end
    end

end
