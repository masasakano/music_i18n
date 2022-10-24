class PrefecturesController < ApplicationController
  before_action :set_prefecture, only: [:show, :edit, :update, :destroy]
  load_and_authorize_resource

  # GET /prefectures
  # GET /prefectures.json
  def index
    @prefectures = Prefecture.all
  end

  # GET /prefectures/1
  # GET /prefectures/1.json
  def show
    @places = @prefecture.places
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
    @prefecture = Prefecture.new(prefecture_params)
    def_respond_to_format(@prefecture)  # defined in application_controller.rb
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
  def destroy
    @prefecture.destroy
    respond_to do |format|
      format.html { redirect_to prefectures_url, notice: 'Prefecture was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_prefecture
      @prefecture = Prefecture.find(params[:id])
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
          { failed: false, warning: get_created_warning_msg(@prefecture, created_updated, extra_note: " in Japan") } # defined in application_controller.rb
        else
          { failed: true, alert: "information is not allowed to be altered for/to Prefectures in Japan." }
        end
      else
        {}
      end
    end
end
