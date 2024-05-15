module EventItemsHelper
  # @return [Array] [ID, machine_title]
  def collection_event_items_for_new_artist_collab
    arbase = [[HaramiVidsController::DEF_FORM_NEW_ARTIST_COLLAB_EVENT_ITEM_NEW, t("layouts.new")+" EventItem"]]
logger.error "DEBUG_ERROR1: @event_event_items=#{@event_event_items.inspect}"
    return arbase if @event_event_items.blank?  # for new (create)
logger.error "DEBUG_ERROR2: @event_event_items=#{@event_event_items.inspect}"

    arbase + @event_event_items.map{|id_event, ar_event_items| 
        ar_event_items
      }.flatten.map{|ea_event_item| 
        [ea_event_item.id, ea_event_item.machine_title]
      }
  end
end
