# coding: utf-8
class EventsController < ApplicationController
  skip_before_action :authenticate_user!, :only => [:index, :show]  # Revert application_controller.rb so Index is viewable by anyone.
  load_and_authorize_resource except: [:create] # except: [:index, :show]  # This sets @event. :create will be dealt separately
  before_action :set_event, only: [:show]  # so far redundant because of load_and_authorize_resource, but will be needed once public access is allowed
  before_action :set_countries, only: [:new, :create, :edit, :update] # defined in application_controller.rb
  before_action :event_params_two, only: [:create, :update]

  # Symbol of the main parameters in the Form (except "place_id"), which exist in DB
  MAIN_FORM_KEYS = %i(duration_hour weight event_group_id note)

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = ([
    :start_year, :start_month, :start_day, :start_hour, :start_minute,
    :start_err, :start_err_unit,  # form-specific keys that do not exist in Model
  ] + MAIN_FORM_KEYS + PARAMS_PLACE_KEYS).uniq  # PARAMS_PLACE_KEYS defined in application_controller.rb
  # they, including place_id, will be handled in event_params_two()

  # GET /events or /events.json
  def index
  end

  # GET /events/1 or /events/1.json
  def show
  end

  # GET /events/new
  def new
  end

  # GET /events/1/edit
  def edit
  end

  # POST /events or /events.json
  def create
    @event = Event.new(@hsmain)
    authorize! __method__, @event

    add_unsaved_trans_to_model(@event, @hstra) # defined in application_controller.rb
    def_respond_to_format(@event)              # defined in application_controller.rb
  end


  # PATCH/PUT /events/1 or /events/1.json
  def update
    def_respond_to_format(@event, :updated){
      @event.update(@hsmain)
    } # defined in application_controller.rb
  end

  # DELETE /events/1 or /events/1.json
  def destroy
    @event.destroy

    respond_to do |format|
      format.html { redirect_to events_url, notice: "Event was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_event
      @event = Event.find(params[:id])
    end

    # Sets @hsmain and @hstra and @prms_all from params
    #
    # +action_name+ (+create+ ?) is checked inside!
    #
    # @return NONE
    def event_params_two
      hsall = set_hsparams_main_tra(:event) # defined in application_controller.rb
      _set_time_to_hsmain(hsall)  # set start_time and err in @hsmain; defined in application_controller.rb, to handle start_* including start_err
    end
end
