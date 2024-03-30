# coding: utf-8
class EventGroupsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]  # Revert application_controller.rb so Index is viewable by anyone.
  load_and_authorize_resource except: [:create] # except: [:index, :show]  # This sets @event. :create will be dealt separately
  before_action :set_event_group, only: [:show]  # so far redundant, but will be needed once public access is allowed
  before_action :set_countries, only: [:new, :create, :edit, :update] # defined in application_controller.rb
  before_action :event_params_two, only: [:update, :create]

  # Symbol of the main parameters in the Form (except "place_id"), which exist in DB
  MAIN_FORM_KEYS = %w(order_no start_date_err end_date_err place_id note)

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = ([
    :start_year, :start_month, :start_day, :end_year, :end_month, :end_day, # form-specific keys that do not exist in Model
  ] + MAIN_FORM_KEYS + PARAMS_PLACE_KEYS).uniq  # PARAMS_PLACE_KEYS defined in application_controller.rb
  # they, including place_id, will be handled in event_params_two()

  # GET /event_groups or /event_groups.json
  def index
  end

  # GET /event_groups/1 or /event_groups/1.json
  def show
  end

  # GET /event_groups/new
  def new
  end

  # GET /event_groups/1/edit
  def edit
  end

  # POST /event_groups or /event_groups.json
  def create
    # Parameters: {"event_group"=>{"langcode"=>"ja", "title"=>"The Test7", "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"", "place.prefecture_id.country_id"=>"338130558", "place.prefecture_id"=>"", "place_id"=>"", "order_no"=>"", "start_year" =>"1999", "start_month"=>"", "start_day"=>"", "end_year"=>"1999", "end_month"=>"", "end_day"=>"", "start_date_err"=>"", "end_date_err"=>"", "note"=>""}, "locale"=>"en"}

    @event_group = EventGroup.new(@hsmain)
    authorize! __method__, @event_group

    add_unsaved_trans_to_model(@event_group, @hstra) # defined in application_controller.rb
    def_respond_to_format(@event_group)              # defined in application_controller.rb
  end

  # PATCH/PUT /event_groups/1 or /event_groups/1.json
  def update
    def_respond_to_format(@event_group, :updated){
      @event_group.update(@hsmain)
    } # defined in application_controller.rb
  end

  # DELETE /event_groups/1 or /event_groups/1.json
  def destroy
    @event_group.destroy

    respond_to do |format|
      format.html { redirect_to event_groups_url, notice: "EventGroup was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_event_group
      @event_group = EventGroup.find(params[:id])
    end

    # Sets @hsmain and @hstra and @prms_all from params
    #
    # +action_name+ (+create+ ?) is checked inside!
    #
    # @return NONE
    def event_params_two
      hsall = set_hsparams_main_tra(:event_group) # defined in application_controller.rb
      _set_dates_to_hsmain(hsall)  # defined in application_controller.rb
    end
end
