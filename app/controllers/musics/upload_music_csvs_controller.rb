# coding: utf-8

# Controller to populate an uploaded file to the DB
class Musics::UploadMusicCsvsController < ApplicationController
 
  before_action :authorize_for_edit, only: [:create]

  # Allowed maximum lines (including blank lines!)
  MAX_LINES = 250

  # POST /musics/upload_music_csvs
  # POST /musics/upload_music_csvs.json (???)
  def create
    params.permit!
    uploaded_io = params[:file]

    if uploaded_io.blank?
      csv_str = nil
      msg_alert = 'No CSV file is specified.' 
      respond_to do |format|
        format.html { redirect_to new_music_url, alert: msg_alert } # , notice: msg_alert
        format.json { head :no_content }
      end
      return
    end

    csv_str = uploaded_io.read.force_encoding('UTF-8')
    msg = sprintf "CSV file (Size=%d[bytes]) uploaded by User(ID=%d): (%s)", csv_str.bytesize, current_user.id, uploaded_io.original_filename
    logger.info msg

    if !csv_str.valid_encoding?
      msg_alert ||= 'Uploaded file contains an invalid sequence as UTF-8 encoding.'
      respond_to do |format|
        format.html { redirect_to musics_url, notice: msg_alert, alert: msg_alert }
        format.json { head :no_content }
      end
      return
    end

    nlines = csv_str.chomp.split.size
    msg = sprintf "CSV file (%s): nLines=%d, nChars=%d", uploaded_io.original_filename, nlines, csv_str.size
    logger.info msg

    begin
      if nlines > MAX_LINES
        csv_str = csv_str.chomp.split[0, MAX_LINES].join("\n")
      end
      hsret = Music.populate_csv(csv_str)
    rescue => er
      # Without rescuing, the error message might not be recorded anywhere.
      msg = "ERROR in Music.populate_csv: err="+er.inspect
      logger.error msg
      warn msg
      raise
    end

    @input_lines, @changes, @csv, @artists, @musics, @engages = hsret.slice(*(%i(input_lines changes csv artists musics engages))).values
    @errors = @musics.map.with_index{ |mus, i|
      msgs = []
      if @musics[i] && @musics[i].errors.present?
        msgs.push sprintf "Music: (%s)", @musics[i].errors.full_messages.join(" ")
      end
      if @artists[i] && @artists[i].errors.present?
        msgs.push sprintf "Artist: (%s)", @artists[i].errors.full_messages.join(" ")
      end
      msgs.empty? ? '' : msgs.join(";")
    }

    respond_to do |format|
      format.html { render :index, status: :ok, notice: 'CSV uploaded.' }
      format.json { render :index, status: :ok, location: @harami1129 }
    end
  end

  protected

  private
    def upload_music_csvs_params
      params.permit(:id, :harami1129_id)
      # params.require(:harami1129).permit(:id, :harami1129_id)
    end

    def authorize_for_edit
      if !current_user
        head :unauthorized
        raise ActionController::RoutingError.new('Not authenticated...')
      elsif !current_user.qualified_as?(:editor)
        logger.info sprintf('(%s#%s) User (ID=%d) access forbidden', self.class.name, __method__, current_user.id)
        render(:file => File.join(Rails.root, 'public/403.html'), :status => :forbidden, :layout => false)
        #render status: :forbidden
        raise ActionController::RoutingError.new('Not authorized...')
      end
    end
end
