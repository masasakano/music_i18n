class InstrumentsController < ApplicationController
  include BaseWithTranslationControllerMethods  # for model_params, set_kind_from_params etc

  #before_action :set_instrument, only: %i[ show edit update destroy ]
  load_and_authorize_resource except: [:create] # This sets @instrument
  before_action :instrument_params_three, only: [:create, :update]

  # Symbol of the main parameters in the Form (except "place_id"), which exist in DB
  MAIN_FORM_KEYS = %i(weight note)

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = MAIN_FORM_KEYS
  # these will be handled in instrument_params_three()

  # Required in {BaseWithTranslationControllerMethods}: +[:disallow_nil, :allow_nil, :always_nil]+
  ORIG_LOCALE_TYPE_ON_CREATE = :always_nil

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

  # Now defined in base_with_translation_controller_methods.rb
  ## POST /instruments or /instruments.json
  #def create
  #end

  # Now defined in base_with_translation_controller_methods.rb
  ## PATCH/PUT /instruments/1 or /instruments/1.json
  #def update
  #  def_respond_to_format(@instrument, :updated){
  #    @instrument.update(@hsmain)
  #  } # defined in application_controller.rb
  #end

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
