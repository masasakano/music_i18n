class PrefecturesController < ApplicationController
  before_action :set_prefecture, only: [:show, :edit, :update, :destroy]
  before_action :set_cp_all, only: [:index, :new, :edit, :create, :update]
  load_and_authorize_resource

  # String of the main parameters in the Form (except place-related)
  MAIN_FORM_KEYS = %w(note)

  # GET /prefectures
  # GET /prefectures.json
  def index
    @prefectures = Prefecture.all
  end

  # GET /prefectures/1
  # GET /prefectures/1.json
  def show
    @places = @prefecture.places  # redundant as Views now takes care of it.
  end

  # GET /prefectures/new
  def new
    @prefecture = Prefecture.new
  end

  # GET /prefectures/1/edit
  def edit
    @places = @prefecture.places
  end

  # POST /prefectures
  # POST /prefectures.json
  def create
    params.permit!
    params.require(:prefecture).permit(
      :note,
      :country, :country_id,  # **NOTE**: redundant...
      *Translation::TRANSLATION_PARAM_KEYS)
      # :langcode, :is_orig, :title, :ruby, :romaji, :alt_title, :alt_ruby, :alt_romaji,

    hsmain = params[:prefecture].slice(*MAIN_FORM_KEYS)
    @prefecture = Prefecture.new(**(hsmain.merge({country_id: params[:prefecture][:country_id].to_i})))
    add_unsaved_trans_to_model(@prefecture) # defined in application_controller.rb
    def_respond_to_format(@prefecture)      # defined in application_controller.rb
  end

  # PATCH/PUT /prefectures/1
  # PATCH/PUT /prefectures/1.json
  def update
    opts = _get_warning_msg(:updated)
    def_respond_to_format(@prefecture, :updated, **opts){ 
      @prefecture.update(prefecture_params)
    } # defined in application_controller.rb
  end

  # DELETE /prefectures/1
  # DELETE /prefectures/1.json
  #
  # In default, {Prefecture} with significant non-{Place.unknown} child Places
  # are not destroyed.  To destroy it, set
  #
  #    @prefecture.force_destroy = true
  #
  # before +@prefecture.destroy+
  # Ability prohibits non-admin from destroying (and even editing)
  # any Prefectures in Japan or any country in
  # {Prefecture::COUNTRIES_WITH_COMPLETE_PREFECTURES}, in which case
  # the control is redirected to Index.
  #
  # Note that even admin should not easily destroy Prefectures in Japan,
  # but it is handled in the UI before this {#destroy} is called.
  #
  def destroy
    respond_to do |format|
      if @prefecture.destroy  # true (if successfully deleted) or false
        format.html { redirect_to prefectures_url, notice: 'Prefecture was successfully destroyed.' }
        format.json { head :no_content }
      else
        @places = @prefecture.places  # as in "show"
        format.html { render :show, status: :unprocessable_entity }
        format.json { render json: @prefecture.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_prefecture
      @prefecture = Prefecture.find(params[:id])
    end

    # Use callbacks to set all for Countries
    #
    # Necessary for the candidates for HTML select (even for index and show in case of error)
    def set_cp_all
      @countries = Country.all
    end

    # Only allow a list of trusted parameters through.
    def prefecture_params
      params.require(:prefecture).permit(:country_id, :note, :iso3166_loc_code, :start_date, :end_date) # :orig_note (Remarks by HirMtsd) exists in DB.
    end

    # Get Hash for warning message in case it fails.
    #
    # @param created_updated [Symbol]
    # @return [Hash]
    def _get_warning_msg(created_updated)
      jpn = Country['JPN']
      if jpn &&
         ((jpn == @prefecture.country) || (jpn.id == prefecture_params[:country_id].to_i))
        if can?(:manage_prefecture_jp, Prefecture)
          # an admin is allowed to alter parameters for/to Prefectures in Japan, though warning is issued.
          { failed: false, warning: Proc.new{|mdl| get_created_warning_msg(mdl, created_updated, extra_note: " in Japan")} } # defined in application_controller.rb
        else
          { failed: true, alert: "information is not allowed to be altered for/to Prefectures in Japan." }
        end
      else
        {}
      end
    end
end
