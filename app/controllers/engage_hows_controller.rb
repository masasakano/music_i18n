class EngageHowsController < ApplicationController
  before_action :set_engage_how, only: %i[ show edit update destroy ]
  load_and_authorize_resource except: [:create] # This sets @engage_how
  before_action :model_params_multi, only: [:create, :update]

  # Symbol of the main parameters in the Form (except "place_id"), which exist in DB
  MAIN_FORM_KEYS ||= []
  MAIN_FORM_KEYS.concat %i(weight note)

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = MAIN_FORM_KEYS
  # these will be handled in channel_type_params_multi()

  # GET /engage_hows or /engage_hows.json
  def index
    @engage_hows = EngageHow.order(:weight) # Same as EngageHow.all.sort, but DB-level sort
  end

  # GET /engage_hows/1 or /engage_hows/1.json
  def show
  end

  # GET /engage_hows/new
  def new
    @engage_how = EngageHow.new
  end

  # GET /engage_hows/1/edit
  def edit
  end

  # POST /engage_hows or /engage_hows.json
  def create
#logger.debug "DEBUG:Start: EngageHow.count="+EngageHow.count.to_s
    @engage_how = EngageHow.new(@hsmain)  # defined in model_params_multi
    authorize! __method__, @engage_how

    add_unsaved_trans_to_model(@engage_how, @hstra, force_is_orig_true: false) # defined in application_controller.rb
    ensure_trans_exists_in_params("engage_how")  # defined in application_controller.rb
    def_respond_to_format(@engage_how)              # defined in application_controller.rb
  end

  # PATCH/PUT /engage_hows/1 or /engage_hows/1.json
  def update
    def_respond_to_format(@engage_how, :updated){
      @engage_how.update(@hsmain)
    } # defined in application_controller.rb
    #respond_to do |format|
    #  if @engage_how.update(params.require(:engage_how).permit(:weight, :note))
    #    format.html { redirect_to @engage_how, notice: "Engage how was successfully updated." }
    #    format.json { render :show, status: :ok, location: @engage_how }
    #  else
    #    format.html { render :edit, status: :unprocessable_entity }
    #    format.json { render json: @engage_how.errors, status: :unprocessable_entity }
    #  end
    #end
  end

  # DELETE /engage_hows/1 or /engage_hows/1.json
  def destroy
    def_respond_to_format_destroy(@engage_how)  # defined in application_controller.rb
    #@engage_how.destroy
    #respond_to do |format|
    #  format.html { redirect_to engage_hows_url, notice: "EngageHow was successfully destroyed." }
    #  format.json { head :no_content }
    #end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_engage_how
      @engage_how = EngageHow.find(params[:id])
    end

    # Sets @hsmain and @hstra and @prms_all from params
    #
    # +action_name+ (+create+ ?) is checked inside!
    #
    # @return NONE
    def model_params_multi
      #set_hsparams_main_tra(:engage_how) # defined in application_controller.rb
      hsall = set_hsparams_main_tra(:engage_how) # defined in application_controller.rb
    end
end
