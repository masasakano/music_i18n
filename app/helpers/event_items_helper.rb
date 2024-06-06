module EventItemsHelper
  # @return [Array] [ID, machine_title]
  def collection_event_items_for_new_artist_collab
    arbase = [[HaramiVidsController::DEF_FORM_NEW_ARTIST_COLLAB_EVENT_ITEM_NEW, t("layouts.new")+" EventItem"]]
    return arbase if @event_event_items.blank?  # for new (create)

    arbase + @event_event_items.map{|id_event, ar_event_items| 
        ar_event_items
      }.flatten.map{|ea_event_item| 
        [ea_event_item.id, ea_event_item.machine_title]
      }
  end

  # @param record [EventItem]
  # @return [String]
  def hint_for_data_to_be_imported(record)
    record.data_to_import_parent.map{ |ek, ev|
      next nil if ev.blank?
      str_ev = 
        if ev.respond_to? :current
          ev.current.to_s.inspect
        elsif ev.respond_to? :encompass?
          "<"+show_pref_place_country(ev, hyperlink: false, prefer_shorter: true)+">"  # defined in places_helper.rb
        else
          ev.to_s
        end
      sprintf("%s => %s", ek, str_ev)
    }.compact.join("; ")
  end
end
