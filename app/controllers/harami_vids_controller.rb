class HaramiVidsController < ApplicationController
  skip_before_action :authenticate_user!, :only => [:index, :show]
  before_action :set_harami_vid, only: [:show, :edit, :update, :destroy]

  # GET /harami_vids
  # GET /harami_vids.json
  def index
    @harami_vids = HaramiVid.all

    # May raise ActiveModel::UnknownAttributeError if malicious params are given.
    # It is caught in application_controller.rb
    @grid = HaramiVidsGrid.new(order: :release_date, descending: true, **grid_params) do |scope|
      nmax = BaseGrid.get_max_per_page(grid_params[:max_per_page])
      scope.page(params[:page]).per(nmax)
    end
  end

  # GET /harami_vids/1
  # GET /harami_vids/1.json
  def show
  end

  # GET /harami_vids/new
  def new
    @harami_vid = HaramiVid.new
    params.permit(:release_date, :duration, :uri, :place_id, :flag_by_harami, :uri_playlist_ja, :uri_playlist_en, :music_timing, :note)
    @countries = Country.all
    @prefectures = Prefecture.all
    @places = Place.all
  end

  # GET /harami_vids/1/edit
  def edit
    @countries = Country.all
    @prefectures = Prefecture.all
    @places = Place.all
  end

  # POST /harami_vids
  # POST /harami_vids.json
  def create
    @harami_vid = HaramiVid.new(sliced_harami_vid_params)
    hvid_respond_to_format(@harami_vid, :created)
  end

  # PATCH/PUT /harami_vids/1
  # PATCH/PUT /harami_vids/1.json
  def update
    hvid_respond_to_format(@harami_vid, :updated)
  end

  # DELETE /harami_vids/1
  # DELETE /harami_vids/1.json
  def destroy
    @harami_vid.destroy
    respond_to do |format|
      format.html { redirect_to harami_vids_url, notice: 'Harami vid was successfully destroyed.' }
      format.json { head :no_content }
    end
  end


  # Common routine for create and update
  #
  # @see application_controller.rb
  #
  # @param mdl [ApplicationRecord]
  # @param created_updated [Symbol] Either :created(Def) or :updated
  # @param failed [Boolean] if true (Def: false), it has already failed.
  # @param redirected_path [String, NilClass] Path to be redirected if successful, or nil (Default)
  # @param back_html [String, NilClass] If the path specified (Def: nil) and if successful, HTML (likely a link to return) preceded with "Return to" is added to a Flash mesage; e.g., '<a href="/musics/5">Music</a>'
  # @param alert [String, NilClass] alert message if any
  # @param warning [String, NilClass] warning message if any
  # @param notice [String, NilClass] notice message if any
  # @param success [String, NilClass] success message if any. Default is "%s was successfully %s." but it is overwritten if specified.
  # @return [void]
  def hvid_respond_to_format(mdl, created_updated=:created, failed: false, redirected_path: nil, back_html: nil, alert: nil, **inopts)
    ret_status, render_err =
      case created_updated.to_sym
      when :created
        [:created, :new]
      when :updated
        [:ok, :edit]
      else
        raise 'Contact the code developer.'
      end

    begin
      ActiveRecord::Base.transaction do
        case created_updated.to_sym
        when :created
          mdl.save!
        when :updated
          mdl.update!(sliced_harami_vid_params)
        else
          raise 'Contact the code developer.'
        end

        ####### Make sure to add any errors to "mdl"
        ####### Make sure to fail in Exception (not mdl.save but mdl.save!)
        #### Save Artist
        #### Save Music
        #### Save HaramiVidMusicAssoc
      end
    rescue
      ## Transaction failed.
      return respond_to do |format|
        mdl.errors.add :base, alert  # alert is included in the instance
        opts = flash_html_safe(alert: alert, **inopts)  # defined in application_controller.rb
        opts.delete :alert  # because alert is contained in the model itself.
        hsstatus = {status: :unprocessable_entity}
        format.html { render render_err,       **(hsstatus.merge opts) } # notice (and/or warning) is, if any, passed as an option.
        format.json { render json: mdl.errors, **hsstatus }
      end
    end

    respond_to do |format|
      inopts = inopts.map{|k,v| [k, (v.respond_to?(:call) ? v.call(mdl) : v)]}.to_h
      alert = (alert.respond_to?(:call) ? alert.call(mdl) : alert)

      msg = sprintf '%s was successfully %s.', mdl.class.name, created_updated.to_s  # e.g., Article was successfully created.
      msg << sprintf('  Return to %s.', back_html) if back_html
      opts = flash_html_safe(success: msg.html_safe, alert: alert, **inopts) # "success" defined in /app/controllers/application_controller.rb
      format.html { redirect_to (redirected_path || mdl), **opts }
      format.json { render :show, status: ret_status, location: mdl }
    end
  end

  private
    def grid_params
      params.fetch(:harami_vids_grid, {}).permit!
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_harami_vid
      @harami_vid = HaramiVid.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def harami_vid_params
      params.require(:harami_vid).permit(:release_date, :duration, :uri, :"place.prefecture_id.country_id", :"place.prefecture_id", :place, :flag_by_harami, :uri_playlist_ja, :uri_playlist_en, :artist, :engage_how2, :music, :music_timing, :note)
    end

    # Only those that are direct parameters of HaramiVid
    def sliced_harami_vid_params
      prmret = harami_vid_params.slice(:release_date, :duration, :uri, :flag_by_harami, :uri_playlist_ja, :uri_playlist_en, :note)
      {place_id: harami_vid_params[:place]}.merge prmret
    end
end
