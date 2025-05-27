class Events::AlignStartTimeWithVidController < ApplicationController
  before_action :set_event, only: [:show, :update]
  load_and_authorize_resource :event

  def show
  end

  def update
    ar_cand_start_time = @event.cand_new_time_if_seems_too_early
    respond_to do |format|
      if !ar_cand_start_time
        format.html { redirect_to events_align_start_time_with_vid_path(@event), notice: "No change." }
      elsif @event.update(start_time: ar_cand_start_time[0], start_time_err: ar_cand_start_time[1])
        format.html { redirect_to events_align_start_time_with_vid_path(@event), notice: "start_time(_err) were successfully updated." }
      else
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_event
      @event = Event.find(params[:id])
    end
end

