# coding: utf-8
require 'open-uri'

# Controller to download data over the Internet to add to the table harami1129s.
class Harami1129s::DownloadHarami1129sController < ApplicationController
  #load_and_authorize_resource

  DOWNLOAD_FORM_SUBMIT_NAME = 'FetchData'
  DOWNLOAD_FORM_STEP = {
    download: 'download',
    internal_insert: 'internal_insert',
    populate: 'populate',
    populate_only: 'populate_only',
  }
  PERMITTED_COLUMNS = [DOWNLOAD_FORM_SUBMIT_NAME.to_sym]+%i(debug init_entry_fetch max_entries_fetch step_to)
  MAX_ENTRIES = 500

  # GET /harami1129s/download_harami1129s/new
  def new
    Translation.skip_set_user_callback = true  # in order NOT to set create_user_id in Translation
    is_populate_only = (DOWNLOAD_FORM_STEP[:populate_only] == params[:step_to].strip.downcase)
    if !is_populate_only
      if Harami1129sController::URI2FETCH.blank?
        @msg = @alert = "No server to retrieve the data is defined. Contact the site administrator."
        redirect_to harami1129s_path, notice: @msg, alert: @alert
        return
      end
      set_harami1129s
    end
#puts "DEBUG-download01:"+params.inspect
#puts "DEBUG-download02:"+params[:max_entries_fetch].inspect
#logger.debug "DEBUG-download01:"+params.inspect
    # This sets @harami1129s
    ini_n = params[:init_entry_fetch]
    ini_n = 1 if ini_n.blank? || ini_n && ini_n.to_i < 1
    ini_n = ini_n.to_i
    max_n = params[:max_entries_fetch]
    max_n = nil if max_n.blank? || max_n && max_n.to_i < 0
    max_n = MAX_ENTRIES if !max_n && !(current_user && current_user.an_admin?)

    if is_populate_only
      @alert ||= nil
      @harami1129s = Harami1129.offset(ini_n-1)
      @harami1129s = @harami1129s.limit(max_n) if max_n
    else
      var6 = Harami1129s::DownloadHarami1129.download_put_harami1129s(init_entry_fetch: ini_n, max_entries_fetch: max_n, execute_class: self.class, method_txt: __method__, user: current_user, debug: (params[:debug].to_i > 0))  # var6 < Harami1129s::DownloadHarami1129::Ret (defined in /app/models/harami1129s/download_harami1129.rb)
      %w(last_err msg alert num_errors harami1129 harami1129s).each do |es|
        # Sets @harami1129s, @alert etc.
        instance_variable_set('@'+es, var6.send(es))
      end
    end

    #download_put_harami1129s(max_entries_fetch: params[:max_entries_fetch], debug: (params[:debug].to_i > 0))
    @msg = [@msg].flatten
    @msg.unshift "Downloaded #{@harami1129s.size} (max specified: #{max_n || 'nil'})."
#puts "DEBUG-download11:harami1129s="+@harami1129s.map{|i| [i.singer, i.song]}.inspect if (params[:debug].to_i > 0)
    messages = []
    if params[:step_to] != DOWNLOAD_FORM_STEP[:download]
      @harami1129s.each do |h1129|
        if params[:step_to][0..15] == DOWNLOAD_FORM_STEP[:internal_insert]
          h1129.fill_ins_column!
        elsif is_populate_only
          h1129.populate_ins_cols_default(messages: messages, execute_class: self.class, method_txt: __method__, user: current_user)
        else  # Download -> Insert (fill_ins_column) -> Populate (to Artist/Music/Engage/HarmaiVid/HaramiVidMusicAssoc/EventItem/HaramiVidEventItemAssoc/ArtistMusicPlay)
          h1129.insert_populate(messages: messages, execute_class: self.class, method_txt: __method__, user: current_user)
        end
      end
    end

    respond_to do |format|
      format.html { redirect_to harami1129s_path, notice: @msg, alert: (@alert.blank? ? nil : @alert) }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_harami1129s
      @harami1129s = Harami1129.all
      download_harami1129s_params
      # NOTE: params[:debug] is either 0 (false) or 1 (true).
    end


    # Only allow a list of trusted parameters through.
    def download_harami1129s_params
      params.permit(*PERMITTED_COLUMNS)
      params.permit!
    end

end
