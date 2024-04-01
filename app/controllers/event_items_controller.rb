class EventItemsController < ApplicationController
  #skip_before_action :authenticate_user!, :only => [:index, :show]  # Revert application_controller.rb so Index is viewable by anyone.
  load_and_authorize_resource except: [:create] # except: [:index, :show]  # This sets @event. :create will be dealt separately
  #before_action :set_event_item, only: [:show]  # it is redundant because of load_and_authorize_resource. This would be needed if public access was allowed in the future (so far, no plan)
  before_action :set_countries, only: [:new, :create, :edit, :update] # defined in application_controller.rb
  before_action :event_item_params, only: [:create, :update]

  # Symbol of the main parameters in the Form (except "place_id"), which exist in DB
  MAIN_FORM_KEYS = %i(machine_title duration_minute duration_minute_err weight event_ratio event_id note)

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = ([
    :start_year, :start_month, :start_day, :start_hour, :start_minute,
    :start_err, :start_err_unit,  # form-specific keys that do not exist in Model
  ] + MAIN_FORM_KEYS + PARAMS_PLACE_KEYS).uniq  # PARAMS_PLACE_KEYS defined in application_controller.rb
  # they, including place_id, will be handled in event_params_two()

  # GET /event_items or /event_items.json
  def index
    @event_items = EventItem.all
  end

  # GET /event_items/1 or /event_items/1.json
  def show
  end

  # GET /event_items/new
  def new
    @event_item = EventItem.new
  end

  # GET /event_items/1/edit
  def edit
  end

  # POST /event_items or /event_items.json
  def create
    @event_item = EventItem.new(@hsmain)
    authorize! __method__, @event_item

    def_respond_to_format(@event_item)              # defined in application_controller.rb
  end

  # PATCH/PUT /event_items/1 or /event_items/1.json
  def update
    def_respond_to_format(@event_item, :updated){
      @event_item.update(@hsmain)
    } # defined in application_controller.rb
  end

  # DELETE /event_items/1 or /event_items/1.json
  def destroy
    @event_item.destroy

    respond_to do |format|
      format.html { redirect_to event_items_url, notice: "EventItem was successfully destroyed." }
      format.json { head :no_content }
    end
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

end
