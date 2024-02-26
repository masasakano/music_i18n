# coding: utf-8
class EventsController < ApplicationController
  #before_action :set_event, only: %i[ show edit update destroy ]
  skip_before_action :authenticate_user!, :only => [:index, :show]  # Revert application_controller.rb so Index is viewable by anyone.
  before_action :set_event, only: [:show, :edit, :update, :destroy]
  before_action :set_countries, only: [:new, :create, :edit, :update] # defined in application_controller.rb
  load_and_authorize_resource except: [:create] # except: [:index, :show]

  # String of the main parameters in the Form (except "place_id")
  MAIN_FORM_KEYS = %w(start_time_err duration_hour weight event_group_id place_id note)

  # Permitted main parameters for params(), used for update
  PARAMS_MAIN_PARAMETERS = [
    :duration_hour, :weight, :event_group_id, :place_id, :note,
    :start_year, :start_month, :start_day, :start_hour, :start_minute,
    :start_err, :start_err_unit,
    :"place.prefecture_id.country_id", :"place.prefecture_id", :place  # :place is used (place_id above is redundant but the most basic UI may require it and so we leave it)
  ]

  # Permitted parameters for params()
  PARAMS_PARAMETERS = PARAMS_MAIN_PARAMETERS + [
    :langcode, :title, :ruby, :romaji, :alt_title, :alt_ruby, :alt_romaji, :is_orig, # In :create, should remove :is_orig
  ]

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
    params.permit!
    hsprm = params.require(:event).permit(*(PARAMS_PARAMETERS - [:is_orig]))
    hsmain = params[:event].slice(*MAIN_FORM_KEYS)
    _set_time_to_hsmain(hsmain)  # defined in application_controller.rb
    hsmain.merge!({place_id: helpers.get_place_from_params(hsprm).id})

    @event = Event.new(hsmain)
    authorize! __method__, @event

    add_unsaved_trans_to_model(@event) # defined in application_controller.rb
    def_respond_to_format(@event)      # defined in application_controller.rb
  end


  # PATCH/PUT /events/1 or /events/1.json
  def update
    params.permit!
    hsprm = params.require(:event).permit(*PARAMS_MAIN_PARAMETERS)

    hsmain = params[:event].slice(*MAIN_FORM_KEYS)
    _set_time_to_hsmain(hsmain)  # defined in application_controller.rb
    hsmain.merge!({place_id: helpers.get_place_from_params(hsprm).id})

    def_respond_to_format(@event, :updated){
      @event.update(hsmain)
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

    # Only allow a list of trusted parameters through.
    def event_params
      params.require(:event).permit( *PARAMS_PARAMETERS )
    end
end
