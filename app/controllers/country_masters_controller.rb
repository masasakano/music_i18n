class CountryMastersController < ApplicationController
  before_action :set_country_master, only: %i[ show edit update destroy ]
  load_and_authorize_resource

  # GET /country_masters or /country_masters.json
  def index
    @country_masters = CountryMaster.all
  end

  # GET /country_masters/1 or /country_masters/1.json
  def show
  end

  # GET /country_masters/new
  def new
    @country_master = CountryMaster.new
  end

  # GET /country_masters/1/edit
  def edit
  end

  # POST /country_masters or /country_masters.json
  def create
    @country_master = CountryMaster.new(country_master_params)

    respond_to do |format|
      if @country_master.save
        format.html { redirect_to @country_master, notice: "Country master was successfully created." }
        format.json { render :show, status: :created, location: @country_master }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @country_master.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /country_masters/1 or /country_masters/1.json
  def update
    respond_to do |format|
      if @country_master.update(country_master_params)
        format.html { redirect_to @country_master, notice: "Country master was successfully updated." }
        format.json { render :show, status: :ok, location: @country_master }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @country_master.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /country_masters/1 or /country_masters/1.json
  def destroy
    @country_master.destroy
    respond_to do |format|
      format.html { redirect_to country_masters_url, notice: "Country master was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_country_master
      @country_master = CountryMaster.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def country_master_params
      params.require(:country_master).permit(:code_a2, :code_a3, :code_n3, :name_ja_full, :name_ja_short, :name_en_full, :name_en_short, :name_fr_full, :name_fr_short, :independent, :territory, :remark, :note, :start_date, :end_date)
    end
end
