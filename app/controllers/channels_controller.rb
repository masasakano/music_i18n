# coding: utf-8
class ChannelsController < ApplicationController
  #before_action :set_channel, only: %i[ show edit update destroy ]
  load_and_authorize_resource except: [:new, :create] # This sets @channel
  before_action :model_params_multi, only: [:create, :update]

  ## params key for auto-complete Artist
  #PARAMS_KEY_AC = BaseMerges::BaseWithIdsController.formid_autocomplete_with_id(Artist).to_sym

  # Symbol of the main parameters in the Form (except "place_id"), which exist in DB
  MAIN_FORM_KEYS = %i(id_at_platform id_human_at_platform channel_owner_id channel_platform_id channel_type_id note)

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = MAIN_FORM_KEYS #+ [PARAMS_KEY_AC] # == :artist_with_id
  # these will be handled in model_params_multi()

  # GET /channels or /channels.json
  def index
    @channels = Channel.all
  end

  # GET /channels/1 or /channels/1.json
  def show
  end

  # GET /channels/new
  def new
    authorize! __method__, Channel
    @channel = Channel.new
    set_channel_sub_parameters
  end

  # GET /channels/1/edit
  def edit
  end

  # POST /channels or /channels.json
  def create
    @channel = Channel.new(@hsmain)
    authorize! __method__, @channel

    add_unsaved_trans_to_model(@channel, @hstra, force_is_orig_true: false) # defined in application_controller.rb
    def_respond_to_format(@channel)              # defined in application_controller.rb
  end

  # PATCH/PUT /channels/1 or /channels/1.json
  def update
    def_respond_to_format(@channel, :updated){
      @channel.update(@hsmain)
    } # defined in application_controller.rb
  end

  # DELETE /channels/1 or /channels/1.json
  def destroy
    @channel.destroy

    respond_to do |format|
      format.html { redirect_to channels_url, notice: "Channel was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_channel
      @channel = Channel.find(params[:id])
    end

    # set channel_owner_id etc from a given URL parameter
    #
    # Path: new_channel_path( params: {channel: {channel_owner_id: 123, channel_type_id: 456}} )
    #
    # @retun [void]
    def set_channel_sub_parameters
      if params[:channel].present?
        %w(channel_owner_id channel_type_id channel_platform_id title langcode).each do |ek|
          if (prm=params[:channel][ek]).present?  # => channel[channel_owner_id]=123 etc
            @channel.send(ek+"=", prm)
          end
        end
      end
    end

    # Sets @hsmain and @hstra and @prms_all from params
    #
    # +action_name+ (+create+ ?) is checked inside!
    #
    # @return NONE
    def model_params_multi
      hsall = set_hsparams_main_tra(:channel) # defined in application_controller.rb
      %i(id_at_platform id_human_at_platform).each do |att|
        @hsmain[att] = nil if @hsmain[att].blank?
      end
    end

end
