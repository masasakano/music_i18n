class EventGroupsController < ApplicationController
  skip_before_action :authenticate_user!, :only => [:index, :show]  # Revert application_controller.rb so Index is viewable by anyone.
  before_action :set_event_group, only: [:show, :edit, :update, :destroy]
  before_action :set_countries, only: [:new, :create, :edit, :update] # defined in application_controller.rb
  load_and_authorize_resource except: [:create] # except: [:index, :show]

  # String of the main parameters in the Form (except "place_id")
  MAIN_FORM_KEYS = %w(order_no start_year start_month start_day end_year end_month end_day place_id note)

  # GET /event_groups or /event_groups.json
  def index
    @event_groups = EventGroup.all
  end

  # GET /event_groups/1 or /event_groups/1.json
  def show
  end

  # GET /event_groups/new
  def new
    @event_group = EventGroup.new
  end

  # GET /event_groups/1/edit
  def edit
  end

  # POST /event_groups or /event_groups.json
  def create
    # Parameters: {"event_group"=>{"langcode"=>"ja", "title"=>"The Test7", "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"", "place.prefecture_id.country_id"=>"338130558", "place.prefecture_id"=>"", "place_id"=>"", "start_year"=>"1999", "start_month"=>"", "start_day"=>"", "end_year"=>"1999", "end_month"=>"", "end_day"=>"", "note"=>""}, "locale"=>"en"}
    #hsprm = event_group_params
    #@event_group = EventGroup.new(event_group_params)
    params.permit!
    hsprm = params.require(:event_group).permit(
      :order_no, :start_year, :start_month, :start_day, :end_year, :end_month, :end_day, :place_id, :note,
      :langcode, :title, :ruby, :romaji, :alt_title, :alt_ruby, :alt_romaji,  # no :is_orig, 
      :"place.prefecture_id.country_id", :"place.prefecture_id", :place
    )

    hsmain = params[:event_group].slice(*MAIN_FORM_KEYS)
    @event_group = EventGroup.new(**(hsmain.merge({place_id: helpers.get_place_from_params(hsprm).id})))
    authorize! __method__, @event_group

    add_unsaved_trans_to_model(@event_group) # defined in application_controller.rb
    def_respond_to_format(@event_group)      # defined in application_controller.rb
  end

  # PATCH/PUT /event_groups/1 or /event_groups/1.json
  def update
    params.permit!
    hsprm = params.require(:event_group).permit(
      :order_no, :start_year, :start_month, :start_day, :end_year, :end_month, :end_day, :note,
      :"place.prefecture_id.country_id", :"place.prefecture_id", :place_id
    )

    hsmain = params[:event_group].slice(*MAIN_FORM_KEYS)
    hs2pass = hsmain.merge({place_id: helpers.get_place_from_params(hsprm).id})

    def_respond_to_format(@event_group, :updated){
      @event_group.update(hs2pass)
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

    # Only allow a list of trusted parameters through.
    def event_group_params
      params.require(:event_group).permit(
        :order_no, :start_year, :start_month, :start_day, :end_year, :end_month, :end_day, :place_id, :note,
        :langcode, :title, :ruby, :romaji, :alt_title, :alt_ruby, :alt_romaji, :is_orig, # In :create, should remove :is_orig
        :"place.prefecture_id.country_id", :"place.prefecture_id", :place  # :place is used (place_id above is redundant but the most basic UI may require it and so we leave it)
      )
    end
end
