class ChannelOwnersController < ApplicationController
  #before_action :set_channel_owner, only: %i[ show edit update destroy ]
  load_and_authorize_resource except: [:create] # This sets @channel_owner
  before_action :model_params_multi, only: [:create, :update]

  # Symbol of the main parameters in the Form (except "place_id"), which exist in DB
  MAIN_FORM_KEYS = %i(themselves note)

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = MAIN_FORM_KEYS
  # these will be handled in model_params_multi()

  # GET /channel_owners or /channel_owners.json
  def index
    @channel_owners = ChannelOwner.all
  end

  # GET /channel_owners/1 or /channel_owners/1.json
  def show
  end

  # GET /channel_owners/new
  def new
    @channel_owner = ChannelOwner.new
  end

  # GET /channel_owners/1/edit
  def edit
  end

  # POST /channel_owners or /channel_owners.json
  def create
    @channel_owner = ChannelOwner.new(@hsmain)
    authorize! __method__, @channel_owner

    add_unsaved_trans_to_model(@channel_owner, @hstra) # defined in application_controller.rb
    def_respond_to_format(@channel_owner)              # defined in application_controller.rb
  end

  # PATCH/PUT /channel_owners/1 or /channel_owners/1.json
  def update
    def_respond_to_format(@channel_owner, :updated){
      @channel_owner.update(@hsmain)
    } # defined in application_controller.rb
  end

  # DELETE /channel_owners/1 or /channel_owners/1.json
  def destroy
    def_respond_to_format_destroy(@channel_owner)  # defined in application_controller.rb
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_channel_owner
      @channel_owner = ChannelOwner.find(params[:id])
    end

    # Sets @hsmain and @hstra and @prms_all from params
    #
    # +action_name+ (+create+ ?) is checked inside!
    #
    # @return NONE
    def model_params_multi
      hsall = set_hsparams_main_tra(:channel_owner) # defined in application_controller.rb
    end
end

