class SexesController < ApplicationController
  before_action :set_sex, only: [:show, :edit, :update, :destroy]
  load_and_authorize_resource

  # GET /sexes
  # GET /sexes.json
  def index
    @sexes = Sex.all
  end

  # GET /sexes/1
  # GET /sexes/1.json
  def show
  end

  # GET /sexes/new
  def new
    @sex = Sex.new
  end

  # GET /sexes/1/edit
  def edit
  end

  # POST /sexes
  # POST /sexes.json
  def create
    @sex = Sex.new(sex_params)
    def_respond_to_format(@sex)  # defined in application_controller.rb
  end

  # PATCH/PUT /sexes/1
  # PATCH/PUT /sexes/1.json
  def update
    def_respond_to_format(@sex, :updated){ 
      @sex.update(sex_params)
    } # defined in application_controller.rb
  end

  # DELETE /sexes/1
  # DELETE /sexes/1.json
  def destroy
    @sex.destroy
    respond_to do |format|
      format.html { redirect_to sexes_url, notice: 'Sex was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_sex
      @sex = Sex.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def sex_params
      params.require(:sex).permit(:iso5218, :note)
    end
end
