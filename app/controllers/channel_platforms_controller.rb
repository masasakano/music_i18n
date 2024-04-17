class ChannelPlatformsController < ApplicationController
  #before_action :set_channel_platform, only: %i[ show edit update destroy ]
  load_and_authorize_resource except: [:create] # This sets @channel_platform
  before_action :channel_platform_params_multi, only: [:create, :update]

  # Symbol of the main parameters in the Form (except "place_id"), which exist in DB
  MAIN_FORM_KEYS = %i(mname note)

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = MAIN_FORM_KEYS
  # these will be handled in channel_platform_params_multi()

  # GET /channel_platforms or /channel_platforms.json
  def index
    @channel_platforms = ChannelPlatform.all
  end

  # GET /channel_platforms/1 or /channel_platforms/1.json
  def show
  end

  # GET /channel_platforms/new
  def new
    @channel_platform = ChannelPlatform.new
  end

  # GET /channel_platforms/1/edit
  def edit
  end

  # POST /channel_platforms or /channel_platforms.json
  def create
    @channel_platform = ChannelPlatform.new(@hsmain)
    authorize! __method__, @channel_platform

    add_unsaved_trans_to_model(@channel_platform, @hstra) # defined in application_controller.rb
    def_respond_to_format(@channel_platform)              # defined in application_controller.rb
  end

  # PATCH/PUT /channel_platforms/1 or /channel_platforms/1.json
  def update
    def_respond_to_format(@channel_platform, :updated){
      @channel_platform.update(@hsmain)
    } # defined in application_controller.rb
  end

  # DELETE /channel_platforms/1 or /channel_platforms/1.json
  def destroy
    def_respond_to_format_destroy(@channel_platform)  # defined in application_controller.rb
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_channel_platform
      @channel_platform = ChannelPlatform.find(params[:id])
    end

    # Sets @hsmain and @hstra and @prms_all from params
    #
    # +action_name+ (+create+ ?) is checked inside!
    #
    # @return NONE
    def channel_platform_params_multi
      hsall = set_hsparams_main_tra(:channel_platform) # defined in application_controller.rb
    end
end
