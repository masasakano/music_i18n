class EngagePlayHowsController < ApplicationController
  #before_action :set_engage_play_how, only: %i[ show edit update destroy ]
  load_and_authorize_resource except: [:create] # This sets @engage_play_how
  before_action :engage_play_how_params_three, only: [:create, :update]

  # Symbol of the main parameters in the Form (except "place_id"), which exist in DB
  MAIN_FORM_KEYS = %i(weight note)

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = MAIN_FORM_KEYS
  # these will be handled in event_params_two()

  # GET /engage_play_hows or /engage_play_hows.json
  def index
    @engage_play_hows = EngagePlayHow.order(:weight)
  end

  # GET /engage_play_hows/1 or /engage_play_hows/1.json
  def show
  end

  # GET /engage_play_hows/new
  def new
    @engage_play_how = EngagePlayHow.new
  end

  # GET /engage_play_hows/1/edit
  def edit
  end

  # POST /engage_play_hows or /engage_play_hows.json
  def create
    @engage_play_how = EngagePlayHow.new(@hsmain)
    authorize! __method__, @engage_play_how

    add_unsaved_trans_to_model(@engage_play_how, @hstra) # defined in application_controller.rb
    def_respond_to_format(@engage_play_how)              # defined in application_controller.rb
  end

  # PATCH/PUT /engage_play_hows/1 or /engage_play_hows/1.json
  def update
    def_respond_to_format(@engage_play_how, :updated){
      @engage_play_how.update(@hsmain)
    } # defined in application_controller.rb
  end

  # DELETE /engage_play_hows/1 or /engage_play_hows/1.json
  def destroy
    def_respond_to_format_destroy(@engage_play_how)  # defined in application_controller.rb
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_engage_play_how
      @engage_play_how = EngagePlayHow.find(params[:id])
    end

    # Sets @hsmain and @hstra and @prms_all from params
    #
    # +action_name+ (+create+ ?) is checked inside!
    #
    # @return NONE
    def engage_play_how_params_three
      hsall = set_hsparams_main_tra(:engage_play_how) # defined in application_controller.rb
    end
end
