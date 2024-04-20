class ChannelTypesController < ApplicationController
  #before_action :set_channel_type, only: %i[ show edit update destroy ]
  load_and_authorize_resource except: [:create] # This sets @channel_type
  before_action :channel_type_params_multi, only: [:create, :update]

  # Symbol of the main parameters in the Form (except "place_id"), which exist in DB
  MAIN_FORM_KEYS = %i(mname weight note)

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = MAIN_FORM_KEYS
  # these will be handled in channel_type_params_multi()

  # GET /channel_types or /channel_types.json
  def index
    @channel_types = ChannelType.order(:weight)
  end

  # GET /channel_types/1 or /channel_types/1.json
  def show
  end

  # GET /channel_types/new
  def new
    @channel_type = ChannelType.new
    @channel_type.weight = ChannelType.new_unique_max_weight  # Default
  end

  # GET /channel_types/1/edit
  def edit
  end

  # POST /channel_types or /channel_types.json
  def create
    @channel_type = ChannelType.new(@hsmain)
    authorize! __method__, @channel_type

    add_unsaved_trans_to_model(@channel_type, @hstra) # defined in application_controller.rb
    def_respond_to_format(@channel_type)              # defined in application_controller.rb
  end

  # PATCH/PUT /channel_types/1 or /channel_types/1.json
  def update
    def_respond_to_format(@channel_type, :updated){
      @channel_type.update(@hsmain)
    } # defined in application_controller.rb
  end

  # DELETE /channel_types/1 or /channel_types/1.json
  def destroy
    def_respond_to_format_destroy(@channel_type)  # defined in application_controller.rb
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_channel_type
      @channel_type = ChannelType.find(params[:id])
    end

    # Sets @hsmain and @hstra and @prms_all from params
    #
    # +action_name+ (+create+ ?) is checked inside!
    #
    # @return NONE
    def channel_type_params_multi
      hsall = set_hsparams_main_tra(:channel_type) # defined in application_controller.rb
    end
end
