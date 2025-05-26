class EventItems::NominalMachineTitlesController < ApplicationController
  before_action :set_event_item, only: [:show, :update]
  load_and_authorize_resource :event_item

  def show
  end

  def update
    nominal_title = @event_item.nominal_unique_title(except_self: true)
    respond_to do |format|
      if @event_item.update(machine_title: nominal_title)
        format.html { redirect_to event_items_nominal_machine_title_path(@event_item), notice: "machine_title was successfully updated." }
      else
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_event_item
      @event_item = EventItem.find(params[:id])
      # event_item_params  # (maybe defined below)
    end
end

