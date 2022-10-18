class PlacesController < ApplicationController
  before_action :set_place, only: [:show, :edit, :update, :destroy]
  before_action :set_cp_all, only: [:index, :new, :edit, :create, :update]
  load_and_authorize_resource

  # String of the main parameters in the Form (except place-related)
  MAIN_FORM_KEYS = %w(note)

  # GET /places
  # GET /places.json
  def index
    @places = Place.all
  end

  # GET /places/1
  # GET /places/1.json
  def show
  end

  # GET /places/new
  def new
    @place = Place.new
  end

  # GET /places/1/edit
  def edit
  end

  # POST /places
  # POST /places.json
  def create
    # Parameters: {"authenticity_token"=>"[FILTERED]", "place"=>{"langcode"=>"ja", "title"=>"", "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"", "prefecture.country_id"=>"5798", "prefecture"=>"", "note"=>""}, "commit"=>"Create Place", "controller"=>"places", "action"=>"create", "locale"=>"en"}
    params.permit!
    #hsprm = params.require(:place).permit(
    params.require(:place).permit(
      :note,
      :langcode, :is_orig, :title, :ruby, :romaji, :alt_title, :alt_ruby, :alt_romaji,
      :"prefecture.country_id", :prefecture, :prefecture_id )  # **NOTE**: redundant...

    hsmain = params[:place].slice(*MAIN_FORM_KEYS)
    # pref = (pref_id_str.blank? ? nil : Prefecture.find(params[:place][:prefecture].to_i))
    @place = Place.new(**(hsmain.merge({prefecture_id: params[:place][:prefecture].to_i})))

    hsprm_tra, _ = split_hash_with_keys(
                 params[:place],
                 %w(langcode title ruby romaji alt_title alt_ruby alt_romaji))
    tra = Translation.preprocessed_new(**(hsprm_tra.merge({is_orig: true, translatable_type: Place.name})))

    @place.unsaved_translations << tra

    respond_to do |format|
      if @place.save
        format.html { redirect_to @place, notice: 'Place was successfully created.' }
        format.json { render :show, status: :created, location: @place }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @place.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /places/1
  # PATCH/PUT /places/1.json
  def update
    respond_to do |format|
      if @place.update(place_params)
        format.html { redirect_to @place, notice: 'Place was successfully updated.' }
        format.json { render :show, status: :ok, location: @place }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @place.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /places/1
  # DELETE /places/1.json
  def destroy
    @place.destroy
    respond_to do |format|
      format.html { redirect_to places_url, notice: 'Place was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_place
      @place = Place.find(params[:id])
    end

    # Use callbacks to set all for Country and Prefecture
    #
    # Necessary for the candidates for HTML select (even for create and update in case of error)
    def set_cp_all
      @countries = Country.all
      @prefectures = Prefecture.all
    end

    # Only allow a list of trusted parameters through.
    def place_params
      params.require(:place).permit(:prefecture_id, :note)
    end
end
