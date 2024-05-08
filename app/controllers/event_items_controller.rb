class EventItemsController < ApplicationController
  #skip_before_action :authenticate_user!, :only => [:index, :show]  # Revert application_controller.rb so Index is viewable by anyone.
  load_and_authorize_resource except: [:create] # except: [:index, :show]  # This sets @event. :create will be dealt separately
  #before_action :set_event_item, only: [:show]  # it is redundant because of load_and_authorize_resource. This would be needed if public access was allowed in the future (so far, no plan)
  before_action :set_countries, only: [:new, :create, :edit, :update] # defined in application_controller.rb
  before_action :event_item_params, only: [:create, :update]

  # Symbol of the main parameters in the Form (except "place" (or "place_id"?)), which exist in DB or as setter methods
  MAIN_FORM_KEYS = %w(machine_title duration_minute duration_minute_err weight event_ratio event_id note)+[
    "start_time(1i)", "start_time(2i)", "start_time(3i)", "start_time(4i)", "start_time(5i)", "start_time(6i)",
    "publish_date(1i)", "publish_date(2i)", "publish_date(3i)",
    "form_start_err", "form_start_err_unit",
  ]

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = ([
    :start_year, :start_month, :start_day, :start_hour, :start_minute,
    :start_err, :start_err_unit,  # form-specific keys that do not exist in Model
  ] + MAIN_FORM_KEYS + PARAMS_PLACE_KEYS).uniq  # PARAMS_PLACE_KEYS defined in application_controller.rb
  # they, including place_id, will be handled in event_params_two()

  # Default unit for start-time error in the form
  DEF_FORM_ERR_UNIT = "hour"

  # GET /event_items or /event_items.json
  def index
    @event_items = EventItem.all
  end

  # GET /event_items/1 or /event_items/1.json
  def show
  end

  # GET /event_items/new
  def new
    set_event_prms  # set @event
    @event_item.event = @event
    if !@event
      flash[:notice] ||= []
      flash[:notice] << "You can pre-specify an Event and then a default machine_title would be suggested. Go to Event index, jump to your preferred Event, and there is a link to New EventItem under the table of all EventItems belonging to the Event."
    end
    @event_item.machine_title = @event_item.default_unique_title if @event
    @event_item.start_time     = (@event ? @event.start_time     : TimeAux::DEF_FIRST_DATE_TIME)  # see event.rb
    @event_item.start_time_err = (@event ? @event.start_time_err : TimeAux::MAX_ERROR)

    set_form_start_err(@event_item)  # defined in module_comon.rb
  end

  # GET /event_items/1/edit
  def edit
    # In case only an Event (but not StartTime) was defined in create
    @event_item.start_time     = (@event ? @event.start_time     : TimeAux::DEF_FIRST_DATE_TIME)  # see event.rb

    if !@event_item.form_start_err
      unit = ((uni=@event_item.form_start_err_unit) ? uni : get_optimum_timu_unit(@event_item.start_time_err))
      factor = _form_start_err_factor(unit)
      @event_item.form_start_err_unit ||= unit
      @event_item.form_start_err = @event_item.start_time_err.quo(factor)
    end
    #@event_item.start_time_err = (@event ? @event.start_time_err : TimeAux::MAX_ERROR)

    set_form_start_err(@event_item)  # defined in module_comon.rb
  end

  # POST /event_items or /event_items.json
  def create
    @event_item = EventItem.new(@hsmain)
    set_start_err_from_form(@event_item)  # defined in module_common.rb
    authorize! __method__, @event_item

    def_respond_to_format(@event_item)    # defined in application_controller.rb
    transfer_error_to_form(@event_item, mdl_attr: :start_time_err, form_attr: :form_start_err)  # defined in application_controller.rb
  end

  # PATCH/PUT /event_items/1 or /event_items/1.json
  def update
    start_err = set_start_err_from_form(@event_item, set_value: false)  # defined in module_common.rb
    def_respond_to_format(@event_item, :updated){
      @event_item.update(@hsmain.merge({start_time_err: start_err}))
    } # defined in application_controller.rb
    transfer_error_to_form(@event_item, mdl_attr: :start_time_err, form_attr: :form_start_err)  # defined in application_controller.rb
  end

  # DELETE /event_items/1 or /event_items/1.json
  def destroy
    def_respond_to_format_destroy(@event_item)  # defined in application_controller.rb
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_event_item
      @event_item = EventItem.find(params[:id])
    end

    # Sets @hsmain and @prms_all from params
    #
    # @return NONE
    def event_item_params
      hsall = set_hsparams_main(:event_item) # defined in application_controller.rb
      _set_time_to_hsmain(hsall)  # set start_time and err in @hsmain; defined in application_controller.rb, to handle start_* including start_err
    end

    # set @event from a given GET parameter
    def set_event_prms
      if params[:event_id].blank?
        @event = nil
      else
        @event = Event.find(params[:event_id].to_i)
      end
    end
end
