class HaramiVidsController < ApplicationController
  skip_before_action :authenticate_user!, :only => [:index, :show]
  before_action :set_harami_vid, only: [:show, :edit, :update, :destroy]

  # GET /harami_vids
  # GET /harami_vids.json
  def index
    @harami_vids = HaramiVid.all

    # May raise ActiveModel::UnknownAttributeError if malicious params are given.
    # It is caught in application_controller.rb
    HaramiVidsGrid.current_user = current_user
    HaramiVidsGrid.is_current_user_moderator = (current_user && current_user.moderator?)
#logger.debug "DEBUG:moderator?=#{HaramiVidsGrid.is_current_user_moderator.inspect}"
    @grid = HaramiVidsGrid.new(grid_params) do |scope|
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
    @harami_vid = HaramiVid.new(harami_vid_params)

    def_respond_to_format(@harami_vid)      # defined in application_controller.rb
  end

  # PATCH/PUT /harami_vids/1
  # PATCH/PUT /harami_vids/1.json
  def update
    def_respond_to_format(@harami_vid, :updated){
      @harami_vid.update(harami_vid_params)
    } # defined in application_controller.rb
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
      params.require(:harami_vid).permit(:release_date, :duration, :uri, :place_id, :flag_by_harami, :uri_playlist_ja, :uri_playlist_en, :music_timing, :note)
    end
end
