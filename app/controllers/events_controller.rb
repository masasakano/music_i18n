# coding: utf-8
class EventsController < ApplicationController
  skip_before_action :authenticate_user!, :only => [:index, :show]  # Revert application_controller.rb so Index is viewable by anyone.
  load_and_authorize_resource except: [:create] # except: [:index, :show]  # This sets @event. :create will be dealt separately
  before_action :set_event, only: [:show]  # so far redundant because of load_and_authorize_resource, but will be needed once public access is allowed
  before_action :set_countries, only: [:new, :create, :edit, :update] # defined in application_controller.rb
  before_action :event_params_two, only: [:create, :update]

  # Symbol of the main parameters in the Form (except "place_id"), which exist in DB
  MAIN_FORM_KEYS = %w(duration_hour weight event_group_id note) + [
    "start_time(1i)", "start_time(2i)", "start_time(3i)", "start_time(4i)", "start_time(5i)", "start_time(6i)",
    "form_start_err", "form_start_err_unit",
  ]

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = ([
    :start_year, :start_month, :start_day, :start_hour, :start_minute,
    :start_err, :start_err_unit,  # form-specific keys that do not exist in Model
  ] + MAIN_FORM_KEYS + PARAMS_PLACE_KEYS).uniq  # PARAMS_PLACE_KEYS defined in application_controller.rb
  # they, including place_id, will be handled in event_params_two()

  # Default unit for start-time error in the form; the same as the one in ApplicationController
  DEF_FORM_TIME_ERR_UNIT = "day"

  # GET /events or /events.json
  def index
    @events = Event.all
  end

  # GET /events/1 or /events/1.json
  def show
  end

  # GET /events/new
  def new
    set_event_group_prms  # set @event_group
    @event.event_group = @event_group
    @event.start_time     ||= (@event_group ? convert_date_to_midday_utc(@event_group.start_date) : TimeAux::DEF_FIRST_DATE_TIME)  # see event.rb
    @event.start_time_err ||= (@event_group ? @event_group.start_date_err*86400 : TimeAux::MAX_ERROR)

    set_form_start_err(@event)  # defined in module_comon.rb
    @event.place = @event_group.place if @event_group
  end

  # GET /events/1/edit
  def edit
    # In case only an EventGroup (but not StartTime) was defined in create
    @event.start_time     ||= (@event_group ? convert_date_to_midday_utc(@event_group.start_time) : TimeAux::DEF_FIRST_DATE_TIME)  # see event.rb

    if !@event.form_start_err
      unit = ((uni=@event.form_start_err_unit) ? uni : get_optimum_timu_unit(@event.start_time_err))  # defined in /app/models/module_common.rb
      factor = _form_start_err_factor(unit)  # defined in /app/models/module_common.rb
      @event.form_start_err_unit ||= unit
      @event.form_start_err = @event.start_time_err.quo(factor).to_f if @event.start_time_err
    end

    set_form_start_err(@event)  # defined in module_comon.rb
  end

  # POST /events or /events.json
  # @see EventItemsController#craete
  def create
    @event = Event.new(@hsmain)
    authorize! __method__, @event
    event_create_to_format(@event) # defined in application_controller.rb
  end

  # PATCH/PUT /events/1 or /events/1.json
  def update
    event_update_to_format(@event)  # defined in application_controller.rb
  end

  # DELETE /events/1 or /events/1.json
  def destroy
    def_respond_to_format_destroy(@event)  # defined in application_controller.rb
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


    # set @event_group from a given GET parameter
    def set_event_group_prms
      if params[:event_group_id].blank?
        @event_group = nil
      else
        @event_group = EventGroup.find(params[:event_group_id].to_i)
      end
    end

end
