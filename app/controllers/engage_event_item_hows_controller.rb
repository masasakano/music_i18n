class EngageEventItemHowsController < ApplicationController
  #before_action :set_engage_event_item_how, only: %i[ show edit update destroy ]
  load_and_authorize_resource  # except: [:index, :show]  # This sets @engage_event_item_hows.

  # GET /engage_event_item_hows or /engage_event_item_hows.json
  def index
    @engage_event_item_hows = EngageEventItemHow.all
  end

  # GET /engage_event_item_hows/1 or /engage_event_item_hows/1.json
  def show
  end

  # GET /engage_event_item_hows/new
  def new
    @engage_event_item_how = EngageEventItemHow.new
  end

  # GET /engage_event_item_hows/1/edit
  def edit
  end

  # POST /engage_event_item_hows or /engage_event_item_hows.json
  def create
    @engage_event_item_how = EngageEventItemHow.new(engage_event_item_how_params)

    respond_to do |format|
      if @engage_event_item_how.save
        format.html { redirect_to engage_event_item_how_url(@engage_event_item_how), notice: "EngageEventItemHow was successfully created." }
        format.json { render :show, status: :created, location: @engage_event_item_how }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @engage_event_item_how.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /engage_event_item_hows/1 or /engage_event_item_hows/1.json
  def update
    respond_to do |format|
      if @engage_event_item_how.update(engage_event_item_how_params)
        format.html { redirect_to engage_event_item_how_url(@engage_event_item_how), notice: "EngageEventItemHow was successfully updated." }
        format.json { render :show, status: :ok, location: @engage_event_item_how }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @engage_event_item_how.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /engage_event_item_hows/1 or /engage_event_item_hows/1.json
  def destroy
    @engage_event_item_how.destroy

    respond_to do |format|
      format.html { redirect_to engage_event_item_hows_url, notice: "EngageEventItemHow was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_engage_event_item_how
      @engage_event_item_how = EngageEventItemHow.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def engage_event_item_how_params
      params.require(:engage_event_item_how).permit(:mname, :weight, :note)
    end
end
