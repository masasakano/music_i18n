# coding: utf-8
class EventsController < ApplicationController
  #before_action :set_event, only: %i[ show edit update destroy ]
  skip_before_action :authenticate_user!, :only => [:index, :show]  # Revert application_controller.rb so Index is viewable by anyone.
  before_action :set_countries, only: [:new, :create, :edit, :update] # defined in application_controller.rb
  load_and_authorize_resource except: [:create] # except: [:index, :show]  # This sets @event
  before_action :event_params_two, only: [:update, :create]

  # String of the main parameters in the Form (except "place_id")
  MAIN_FORM_KEYS = %i(duration_hour weight event_group_id note)  # place_id and start_* including start_err are later handled in helpers.get_place_from_params() and _set_time_to_hsmain(), respectively

  # Permitted main parameters for params(), used for update (and create)
  PARAMS_MAIN_KEYS = ([
    :start_year, :start_month, :start_day, :start_hour, :start_minute,
    :start_err, :start_err_unit,  # form-specific keys that do not exist in Model
  ] + MAIN_FORM_KEYS + PARAMS_PLACE_KEYS).uniq  # PARAMS_PLACE_KEYS defined in application_controller.rb

  # GET /events or /events.json
  def index
    @events = Event.all
  end

  # GET /events/1 or /events/1.json
  def show
  end

  # GET /events/new
  def new
    #@event = Event.new
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
    # Sets @hsmain and @hstra and @prms_all from params
    #
    # +action_name+ (+create+ ?) is checked inside!
    #
    # @return NONE
    def event_params_two
      hsall = set_hsparams_main_tra(:event) # defined in application_controller.rb
      _set_time_to_hsmain(hsall)  # defined in application_controller.rb
    end
end
