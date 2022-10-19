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
  end

  # GET /prefectures/new
  def new
    @prefecture = Prefecture.new
  end

  # GET /prefectures/1/edit
  def edit
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
    def_respond_to_format(@prefecture, :updated){ 
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
      params.require(:prefecture).permit(:country_id, :note)
    end
end
