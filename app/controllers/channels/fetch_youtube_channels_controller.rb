# coding: utf-8
# require "unicode/emoji"
# require "google/apis/youtube_v3"
#
# == NOTE
#
# * ENV["YOUTUBE_API_KEY"] is essential.
# * ENV["UPDATE_YOUTUBE_MARSHAL"] : set this if you want to *update* the marshal-ed Youtube data.
# * ENV["SKIP_YOUTUBE_MARSHAL"] : In testing, if this is set, marshal-ed data are not used.
class Channels::FetchYoutubeChannelsController < ApplicationController
  include ApplicationHelper
  include HaramiVidsHelper # for set_event_event_items (common with HaramiVidsController)
  include ModuleGuessPlace  # for guess_place
  include ModuleYoutubeApiAux # defined in /app/controllers/concerns/module_youtube_api_aux.rb

  # edits a HaramiVid according to information fetched via Youtube API
  def update
    set_channel  # set @channel
    authorize! __method__, @channel

    ActiveRecord::Base.transaction(requires_new: true) do
      update_channel_with_youtube_api
      result = def_respond_to_format(@channel, :updated, render_err_path: "channels") # No update is run if @channel.errors.any? ; defined in application_controller.rb
      raise ActiveRecord::Rollback, "Force rollback." if !result
    end
  end

  private

    # set @channel from a given URL parameter
    def set_channel
      @channel = nil
      safe_params = params.require(:channel).require(:fetch_youtube_channel).permit(
        :use_cache_test, :uri_youtube, :id_at_platform, :id_human_at_platform)

      @use_cache_test = get_bool_from_params(safe_params[:use_cache_test]) # defined in application_helper.rb
      @uri_youtube = safe_params[:uri_youtube]
      @uri_youtube = nil if @uri_youtube.blank?
      @remote_ids = [:id_at_platform, :id_human_at_platform].map{|ek|
        (tmp=safe_params[ek]).blank? ? nil : PrmChannelRemote.new(tmp, kind: ek)
      }  # 1 or 2 elements

      channel_id = params[:id]
      return if channel_id.blank?  # should never happen
      @channel = Channel.find(channel_id)
    end

    # this is within a DB transaction (see {#update})
    def update_channel_with_youtube_api
      set_youtube  # sets @youtube; defined in ModuleYoutubeApiAux
      if @uri_youtube.present?
        pcr = PrmChannelRemote.new_from_any(@uri_youtube, platform_fallback: :youtube, normalize: true)
        @yt_channel = pcr.yt_channel
      end

      get_yt_channel((pcr || @channel), set_instance_var: true, use_cache_test: @use_cache_test) if !@yt_channel  # sets @yt_channel # defined in module_youtube_api_aux.rb
      return if !@yt_channel

      #snippet = api.items[0].snippet
      snippet = @yt_channel.snippet
      _adjust_ids

      ret_msg = adjust_youtube_titles(snippet, model: @channel)  # Translation(s) updated or created. # defined in ModuleYoutubeApiAux
      return if !ret_msg  # Error has been raised in saving/updating Translation(s)
      flash[:notice] ||= []
      flash[:notice] << ret_msg
    end

    # Sets both Youtube machine-ID and handle (human-readable ID like @adam_smith)
    def _adjust_ids
      flash[:notice] ||= []
      %w(id_at_platform id_human_at_platform).each do |ek|
        existing = @channel.send(ek)
        other = get_id_ytresponse(ek)  # defined in ModuleYoutubeApiAux
        if existing != other
          @channel.send(ek.to_s+"=", other)
          msg =
            if existing.blank?
              sprintf("%s is set to %s", ek, other.inspect)
            else
              sprintf("%s is updated from %s to %s", ek, existing.inspect, other.inspect)
            end
          flash[:notice] << msg
        end
      end
    end


end
