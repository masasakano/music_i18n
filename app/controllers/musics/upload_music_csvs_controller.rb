# coding: utf-8

# Controller to populate an uploaded file to the DB
class Musics::UploadMusicCsvsController < ApplicationController
 
  include ModuleUploadCsv

  before_action :authorize_for_edit, only: [:create]

  # Allowed maximum lines (including blank lines!)
  MAX_LINES = 250

  # POST /musics/upload_music_csvs
  # POST /musics/upload_music_csvs.json (???)
  def create
    params.permit!
    uploaded_io = params[:file]

    hsret = populate_csv_file(uploaded_io, in_redirect_path: new_music_url, in_redirect_path_invalid_encoding: musics_path){ |csv_str|
      # the latter path should be new_music_url, too; but leaving it as musics_path for now for the sake of testing...
      Music.populate_csv(csv_str)
    }
    return if !hsret

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
