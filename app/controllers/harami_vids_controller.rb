class HaramiVidsController < ApplicationController
  skip_before_action :authenticate_user!, :only => [:index, :show]
  before_action :set_harami_vid, only: [:show, :edit, :update, :destroy]

  # GET /harami_vids
  # GET /harami_vids.json
  def index
    @harami_vids = HaramiVid.all
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

    respond_to do |format|
      if @harami_vid.save
        format.html { redirect_to @harami_vid, notice: 'Harami vid was successfully created.' }
        format.json { render :show, status: :created, location: @harami_vid }
      else
        format.html { render :new }
        format.json { render json: @harami_vid.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /harami_vids/1
  # PATCH/PUT /harami_vids/1.json
  def update
    respond_to do |format|
      if @harami_vid.update(harami_vid_params)
        format.html { redirect_to @harami_vid, notice: 'Harami vid was successfully updated.' }
        format.json { render :show, status: :ok, location: @harami_vid }
      else
        format.html { render :edit }
        format.json { render json: @harami_vid.errors, status: :unprocessable_entity }
      end
    end
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
    # Use callbacks to share common setup or constraints between actions.
    def set_harami_vid
      @harami_vid = HaramiVid.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def harami_vid_params
      params.require(:harami_vid).permit(:release_date, :duration, :uri, :place_id, :flag_by_harami, :uri_playlist_ja, :uri_playlist_en, :music_timing, :note)
    end
end
