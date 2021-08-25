class ArtistsController < ApplicationController
  include ModuleCommon # for split_hash_with_keys

  skip_before_action :authenticate_user!, :only => [:index, :show]
  before_action :set_artist, only: [:show, :edit, :update, :destroy]
  load_and_authorize_resource except: [:index, :show]

  # String of the main parameters in the Form (except "place_id")
  MAIN_FORM_KEYS = %w(sex_id birth_year birth_month birth_day wiki_ja wiki_en note)

  # GET /artists
  # GET /artists.json
  def index
    @artists = Artist.all
  end

  # GET /artists/1
  # GET /artists/1.json
  def show
  end

  # GET /artists/new
  def new
    @artist = Artist.new
    params.permit(:sex_id, :place_id, :birth_year, :birth_month, :birth_day, :wiki_ja, :wiki_en, :note)
    @countries = Country.all
    @prefectures = Prefecture.all
    #@places = Place.all
  end

  # GET /artists/1/edit
  def edit
    @countries = Country.all
    @prefectures = Prefecture.all
    @places = Place.all
  end

  # POST /artists
  # POST /artists.json
  def create
    # Parameters: {"authenticity_token"=>"[FILTERED]", "artist"=>{"langcode"=>"en", "title"=>"AI", "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"", "place.prefecture_id.country_id"=>"3153", "place.prefecture_id"=>"", "place_id"=>"", "sex_id"=>"0", "birth_year"=>"", "birth_month"=>"", "birth_day"=>"", "wiki_en"=>"", "wiki_ja"=>"", "note"=>""}, "commit"=>"Create Artist"}
    params.permit!
    hsprm = params.require(:artist).permit(
      :sex_id, :birth_year, :birth_month, :birth_day, :wiki_ja, :wiki_en, :note,
      :langcode, :is_orig, :title, :ruby, :romaji, :alt_title, :alt_ruby, :alt_romaji,
      :"place.prefecture_id.country_id", :"place.prefecture_id", :place_id)

    hsmain = params[:artist].slice(*MAIN_FORM_KEYS)
    @artist = Artist.new(**(hsmain.merge({place_id: helpers.get_place_from_params(hsprm).id})))

    hsprm_tra, resths = split_hash_with_keys(
                 params[:artist],
                 %w(langcode title ruby romaji alt_title alt_ruby alt_romaji))
    tra = Translation.preprocessed_new(**(hsprm_tra.merge({is_orig: true, translatable_type: Artist.name})))

    @artist.unsaved_translations << tra

    respond_to do |format|
      if @artist.save
        format.html { redirect_to @artist, notice: 'Artist was successfully created.' }
        format.json { render :show, status: :created, location: @artist }
      else
        format.html { render :new }
        format.json { render json: @artist.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /artists/1
  # PATCH/PUT /artists/1.json
  def update
    params.permit!
    hsprm = params.require(:artist).permit(
      :sex_id, :birth_year, :birth_month, :birth_day, :wiki_ja, :wiki_en, :note,
      :"place.prefecture_id.country_id", :"place.prefecture_id", :place_id)

    hsmain = params[:artist].slice(*MAIN_FORM_KEYS)
    hs2pass = hsmain.merge({place_id: helpers.get_place_from_params(hsprm).id})

    respond_to do |format|
      if @artist.update(hs2pass)
        format.html { redirect_to @artist, notice: 'Artist was successfully updated.' }
        format.json { render :show, status: :ok, location: @artist }
      else
        format.html { render :edit }
        format.json { render json: @artist.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /artists/1
  # DELETE /artists/1.json
  def destroy
    @artist.destroy
    respond_to do |format|
      format.html { redirect_to artists_url, notice: 'Artist was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_artist
      @artist = Artist.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def artist_params
      params.require(:artist).permit(:sex_id, :place_id, :birth_year, :birth_month, :birth_day, :wiki_ja, :wiki_en, :note)
    end

end
