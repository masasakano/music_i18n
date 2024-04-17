class InstrumentsController < ApplicationController
  #before_action :set_instrument, only: %i[ show edit update destroy ]
  load_and_authorize_resource except: [:create] # This sets @instrument
  before_action :instrument_params_three, only: [:create, :update]

  # Symbol of the main parameters in the Form (except "place_id"), which exist in DB
  MAIN_FORM_KEYS = %i(weight note)

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = MAIN_FORM_KEYS
  # these will be handled in instrument_params_three()

  # GET /instruments or /instruments.json
  def index
    @instruments = Instrument.order(:weight)
  end

  # GET /instruments/1 or /instruments/1.json
  def show
  end

  # GET /instruments/new
  def new
    @instrument = Instrument.new
  end

  # GET /instruments/1/edit
  def edit
  end

  # POST /instruments or /instruments.json
  def create
    @instrument = Instrument.new(@hsmain)
    authorize! __method__, @instrument

    add_unsaved_trans_to_model(@instrument, @hstra) # defined in application_controller.rb
    def_respond_to_format(@instrument)              # defined in application_controller.rb
  end

  # PATCH/PUT /instruments/1 or /instruments/1.json
  def update
    def_respond_to_format(@instrument, :updated){
      @instrument.update(@hsmain)
    } # defined in application_controller.rb
  end

  # DELETE /instruments/1 or /instruments/1.json
  def destroy
    def_respond_to_format_destroy(@instrument)  # defined in application_controller.rb
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_instrument
      @instrument = Instrument.find(params[:id])
    end

    # Sets @hsmain and @hstra and @prms_all from params
    #
    # +action_name+ (+create+ ?) is checked inside!
    #
    # @return NONE
    def instrument_params_three
      hsall = set_hsparams_main_tra(:instrument) # defined in application_controller.rb
    end
end
