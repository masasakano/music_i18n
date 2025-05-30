class EventItemsController < ApplicationController
  include ModuleCommon
  include ApplicationHelper  # for get_params_from_date_time
  include ModuleGridController # for set_grid

  #skip_before_action :authenticate_user!, :only => [:index, :show]  # Revert application_controller.rb so Index is viewable by anyone.
  load_and_authorize_resource except: [:create] # except: [:index, :show]  # This sets @event. :create will be dealt separately
  #before_action :set_event_item, only: [:show]  # it is redundant because of load_and_authorize_resource. This would be needed if public access was allowed in the future (so far, no plan)
  before_action :set_countries, only: [:new, :create, :edit, :update] # defined in application_controller.rb
  before_action :event_item_params, only: [:create, :update]

  # Symbol of the main parameters in the Form (except "place" (or "place_id"?)), which exist in DB or as setter methods
  MAIN_FORM_KEYS = %w(machine_title duration_minute duration_minute_err weight event_ratio event_id note)+[
    "start_time(1i)", "start_time(2i)", "start_time(3i)", "start_time(4i)", "start_time(5i)", "start_time(6i)",
    "publish_date(1i)", "publish_date(2i)", "publish_date(3i)",
    "form_start_err", "form_start_err_unit", "match_parent",
  ]

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = ([
    :start_year, :start_month, :start_day, :start_hour, :start_minute,
    :start_err, :start_err_unit,  # form-specific keys that do not exist in Model
  ] + MAIN_FORM_KEYS + PARAMS_PLACE_KEYS).uniq  # PARAMS_PLACE_KEYS defined in application_controller.rb
  # they, including place_id, will be handled in event_params_two()

  # Default unit for start-time error in the form; overwriting the one in ApplicationController
  DEF_FORM_TIME_ERR_UNIT = "hour"

  # GET /event_items or /event_items.json
  def index
    @event_items = EventItem.all
    set_grid(EventItem, hs_def: {order: :updated_at, descending: true})  # setting @grid; defined in concerns/module_grid_controller.rb
  end

  # GET /event_items/1 or /event_items/1.json
  def show
  end

  # GET /event_items/new
  def new
    set_event_prms  # set @event
    @event_item.event = @event
    if @event
      @event_item.machine_title   ||= @event_item.default_unique_title 
      @event_item.place           ||= @event.place
      @event_item.start_time      ||= @event.start_time
      @event_item.start_time_err  ||= @event.start_time_err
      @event_item.duration_minute ||= @event.duration_hour*60 if @event.duration_hour
    else
      flash[:notice] ||= []
      flash[:notice] << "You can pre-specify an Event and then a default machine_title would be suggested. Go to Event index, jump to your preferred Event, and there is a link to New EventItem under the table of all EventItems belonging to the Event."
    end
    @event_item.start_time     ||= TimeAux::DEF_FIRST_DATE_TIME  # see event.rb
    @event_item.start_time_err ||= TimeAux::MAX_ERROR

    set_form_start_err(@event_item)  # defined in module_comon.rb
  end

  # GET /event_items/1/edit
  def edit
    # In case only an Event (but not StartTime) was defined in create
    @event_item.start_time   ||= (@event ? @event.start_time     : TimeAux::DEF_FIRST_DATE_TIME)  # see event.rb

    if !@event_item.form_start_err
      unit = ((uni=@event_item.form_start_err_unit) ? uni : get_optimum_timu_unit(@event_item.start_time_err))  # defined in /app/models/module_common.rb
      factor = _form_start_err_factor(unit)  # defined in /app/models/module_common.rb
      @event_item.form_start_err_unit ||= unit
      @event_item.form_start_err ||= @event_item.start_time_err.quo(factor) if @event_item.start_time_err
    end
    #@event_item.start_time_err = (@event ? @event.start_time_err : TimeAux::MAX_ERROR)

    set_form_start_err(@event_item)  # defined in module_comon.rb

    if !@event_item.publish_date
      @event_item.publish_date = @event_item.first_release_date
    end
  end

  # POST /event_items or /event_items.json
  # @see EventsController#craete
  def create
    @event_item = EventItem.new(@hsmain)
    authorize! __method__, @event_item
    event_create_to_format(@event_item) # defined in application_controller.rb
  end

  # PATCH/PUT /event_items/1 or /event_items/1.json
  def update
    _match_parent_hsmain
    event_update_to_format(@event_item)  # defined in application_controller.rb
  end

  # DELETE /event_items/1 or /event_items/1.json
  def destroy
    back_url = event_url(@event_item.event)
    def_respond_to_format_destroy(@event_item, fallback_location: back_url)  # defined in application_controller.rb
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

    # adjusts @hsmain according to parent (to import the data from parent Event or associated HaramiVids so the parameters are all consistent)
    #
    # @return [void]
    def _match_parent_hsmain
      @event_item.match_parent = @hsmain[:match_parent]
      return if !@event_item.match_parent
      use_place_id = !@hsmain.keys.include?("place")
      @event_item.event_id = @hsmain[:event_id] if @hsmain[:event_id]

      hs2update = @event_item.data_to_import_parent(hsmain: @hsmain)  # This sets @event_item.warnings
      hs2update.each_pair do |ek, ev|
        next if !ev
        if "start_time_err" == ek
          @hsmain["form_start_err"] = ev
          @hsmain["form_start_err_unit"] = "second"
        elsif "place" == ek && use_place_id
          @hsmain["place_id"] = ev.id
        elsif ev.respond_to? :julian?
          @hsmain.merge! get_params_from_date_time(ev, ek.to_s)  # defined in ApplicationHelper
        elsif ev.respond_to? :tv_usec
          @hsmain.merge! get_params_from_date_time(ev, ek.to_s, 6)
        else
          if !@hsmain.has_key?(ek)
            msg = "ERROR(#{__method__}): Unexpectedly, key=#{ek.inspect} does not exist in @hsmain.  Developer must fix it ASAP."
            puts msg
            logger.error msg
          end
          @hsmain[ek.to_s] = ev
        end
      end

      flash[:warning] ||= []
      flash[:warning].concat(@event_item.warnings.map{|ek, ev| sprintf("(%s) %s", ek, ev)})
    end
end
