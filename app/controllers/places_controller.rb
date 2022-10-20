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

    add_unsaved_trans_to_model(@place) # defined in application_controller.rb
    def_respond_to_format(@place)      # defined in application_controller.rb
  end

  # PATCH/PUT /places/1
  # PATCH/PUT /places/1.json
  def update
    def_respond_to_format(@place, :updated){
      @place.update(place_params)
    } # defined in application_controller.rb
  end

  # DELETE /places/1
  # DELETE /places/1.json
  def destroy
    if !(s=@place.children_class_names).empty?
      return _respond_destroy_fail("Cannot destroy Place because it has one or more dependent children of "+s.join(" and "))
    end

    begin
      @place.destroy
    rescue ActiveRecord::InvalidForeignKey => err
      # This should not happen...
      logger.error sprintf("(DELETE Place: %s) Place(ID=%d, title_or_alt=%s) has uncaught dependent children: error-message=%s", err.class.name, @place.id, @place.title_or_alt.inspect, err.message)
      return _respond_destroy_fail("Cannot destroy Place because it seems to have one or more dependent children.")
    end

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
      params.require(:place).permit(:prefecture_id, :note)  # adding "prefecture.country_id" would cause <400: Bad Request>
    end

    def _respond_destroy_fail(msg)
      respond_to do |format|
        case request.path  # Go back to the original page...
        when edit_place_path(@place.id)
          format.html { render :edit, status: :unprocessable_entity, alert: msg }
        when      place_path(@place.id)
          format.html { render :show, status: :unprocessable_entity, alert: msg }
        else
          format.html { redirect_to places_url, alert: msg }
        end
        format.json { render json: mdl.errors, status: :unprocessable_entity }
      end
    end
end
