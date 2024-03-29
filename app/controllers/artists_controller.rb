# coding: utf-8
class ArtistsController < ApplicationController
  include ModuleCommon # for split_hash_with_keys

  skip_before_action :authenticate_user!, :only => [:index, :show]
  before_action :set_artist,    only: [:show, :edit, :update, :destroy]
  before_action :set_countries, only: [:new, :create, :edit, :update] # defined in application_controller.rb
  load_and_authorize_resource except: [:index, :show]

  # String of the main parameters in the Form (except "place_id")
  MAIN_FORM_KEYS = %w(sex_id birth_year birth_month birth_day wiki_ja wiki_en note)

  # GET /artists
  # GET /artists.json
  def index
    @artists = Artist.all

    # May raise ActiveModel::UnknownAttributeError if malicious params are given.
    # It is caught in application_controller.rb
    @grid = ArtistsGrid.new(**grid_params) do |scope|
      nmax = BaseGrid.get_max_per_page(grid_params[:max_per_page])
      if grid_params[:order].blank?
        harami = Artist['ハラミちゃん', "ja"]  # Haramichan always comes first!
        scope = scope.order(Arel.sql("CASE artists.id WHEN #{harami.id rescue 0} THEN 0 ELSE 1 END, created_at DESC"))
      end
      scope.page(params[:page]).per(nmax)
    end
  end

  # GET /artists/1
  # GET /artists/1.json
  def show
  end

  # GET /artists/new
  def new
    @artist = Artist.new
    params.permit(:sex_id, :place_id, :birth_year, :birth_month, :birth_day, :wiki_ja, :wiki_en, :note)
    #@places = Place.all
  end

  # GET /artists/1/edit
  def edit
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

    add_unsaved_trans_to_model(@artist) # defined in application_controller.rb
    def_respond_to_format(@artist)      # defined in application_controller.rb
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

    def_respond_to_format(@artist, :updated){
      @artist.update(hs2pass)
    } # defined in application_controller.rb
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
    def grid_params
      params.fetch(:artists_grid, {}).permit!
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_artist
      @artist = Artist.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def artist_params
      params.require(:artist).permit(:sex_id, :place_id, :birth_year, :birth_month, :birth_day, :wiki_ja, :wiki_en, :note)
    end
end
