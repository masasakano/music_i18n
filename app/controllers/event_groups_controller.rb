# coding: utf-8
class EventGroupsController < ApplicationController
  #before_action :set_event_group, only: [:show, :edit, :update, :destroy]
  skip_before_action :authenticate_user!, :only => [:index, :show]  # Revert application_controller.rb so Index is viewable by anyone.
  before_action :set_countries, only: [:new, :create, :edit, :update] # defined in application_controller.rb
  load_and_authorize_resource except: [:create] # except: [:index, :show]
  before_action :event_params_two, only: [:update, :create]

  # String of the main parameters in the Form (except "place_id")
  MAIN_FORM_KEYS = %w(order_no start_date_err end_date_err place_id note)

  # Permitted main parameters for params(), used for update
  PARAMS_MAIN_KEYS = ([
    :start_year, :start_month, :start_day, :end_year, :end_month, :end_day, # form-specific keys that do not exist in Model
  ] + MAIN_FORM_KEYS + PARAMS_PLACE_KEYS).uniq  # PARAMS_PLACE_KEYS defined in application_controller.rb

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
    # Sets @hsmain and @hstra from params
    #
    # +action_name+ (+create+ ?) is checked inside!
    #
    # @return NONE
    def event_params_two
      hsall = set_hsparams_main_tra(:event_group) # defined in application_controller.rb
      _set_dates_to_hsmain(hsall)  # defined in application_controller.rb
    end


#############################
    # Only allow a list of trusted parameters through.
    def event_group_params
      params.require(:event_group).permit(
        :order_no, :start_year, :start_month, :start_day, :start_date_err, :end_year, :end_month, :end_day, :end_date_err, :place_id, :note,
        :start_date_err, :end_date_err,
        :langcode, :title, :ruby, :romaji, :alt_title, :alt_ruby, :alt_romaji, :is_orig, # In :create, should remove :is_orig
        :"place.prefecture_id.country_id", :"place.prefecture_id", :place  # :place is used (place_id above is redundant but the most basic UI may require it and so we leave it)
      )
    end
  def _add_date_to_hsmain(hsmain)
    %w(start end).each do |col_prefix|
      ar = %w(year month day).map{|i| params[:event_group][col_prefix+"_"+i].presence}
      hsmain[col_prefix+"_date"] = self.class.create_a_date(*ar)  # err is not specified.

      errcolname = col_prefix+"_date_err"
      err = params[:event_group][errcolname]
      err = nil if err && err.strip.blank?
      hsmain[errcolname] = err
    end
  end

end
