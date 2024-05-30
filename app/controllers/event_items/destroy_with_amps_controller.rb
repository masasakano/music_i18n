class EventItems::DestroyWithAmpsController < ApplicationController
  def destroy
    @event_item = EventItem.find(params[:id])
    authorize! :destroy_with_amps, @event_item
    # This authorize should reject this request if a Harami1129 or multiple HaramiVids are associated to EventItem, even by an admin (except for the sysadmin)

    raise "Even sysadmin is not allowed to destroy EventItem associated to multiple HaramiVids." if @event_item.harami_vids.count > 1  # should never happen except by a request by sysadmin.

    result = nil
    hsopt = {}
    ActiveRecord::Base.transaction(requires_new: true) do
      result = @event_item.artist_music_plays.destroy_all
      result &&= @event_item.harami_vids.destroy(@event_item.harami_vids.first)
      @event_item.artist_music_plays.reset
      #@event_item.harami_vids.reset

      notice_tail = "successfully destroyed, together with the associated collaboration records."
      if result
        destroyable = @event_item.destroyable?
        result = false  # in case escaped with an Exception (DB rollback)
        if _event_destroyable?
          evt = @event_item.event
          n_event_items = evt.event_items.count
          @event_item.event.event_items.each do |evit|
            res=_destroy_model_set_alert(hsopt, evit) if !evit.unknown?  # may raise an exception to rollback
          end
          evt.event_items.reset
          result = _destroy_model_set_alert(hsopt, evt)  # may raise an exception to rollback
          hsopt[:notice] = sprintf("%s and %d children %s were %s", @evt.class.name, n_event_items, @event_item.class.name, notice_tail)
        elsif destroyable
          # Event is not destroyable but self (EventItem) is destroyable (and it should be whenever this request is submitted)
          result = _destroy_model_set_alert(hsopt, @event_item)  # may raise an exception to rollback
          hsopt[:notice] = "#{@event_item.class.name} was "+notice_tail
        else
          result = _destroy_model_set_alert(hsopt, @event_item)  # should fail and raise an exception to rollback (the main purpose to call this is to set the alert message)
        end
      end # if result
    end  # ActiveRecord::Base.transaction(requires_new: true) do

    if result
      fmt_json = Proc.new { head :no_content }
    else
      fmt_json = Proc.new { render json: hsopt[:alert] }
    end

    respond_to do |format|
      format.html { redirect_back fallback_location: harami_vids_path, **hsopt }
      format.json(&fmt_json)
    end
  end

  # @return [Boolean] true if all the EventItems belongs_to the parent Event have
  #    no associations, and hence the Event will be ready to be destroyed
  #    (though EventItem.unknown returns false for {EventItem#destroyable?} always).
  def _event_destroyable?
    # NOTE: If the Event is the last remaining Event in the EventGroup, you cannot destroy it.
    return nil if @event_item.event_group.events.size == 1

    @event_item.event.event_items.all?{ |evit|
      %i(harami_vids harami1129s artist_music_plays).all?{ |metho|
        !evit.send(metho).exists?
      }
    }
  end
  private :_event_destroyable?

  # Attempts to destory.  If failing, hsopt[:alert] is set.
  #
  # @return [Boolean] true if succeeds. Raises an Exception (Rollback) if fails
  def _destroy_model_set_alert(hsopt, model=@event_item)
    return true if model.destroy

    hsopt[:alert] = model.errors.full_messages
    raise ActiveRecord::Rollback, "Force rollback."
    raise
  end
  private :_destroy_model_set_alert

end
