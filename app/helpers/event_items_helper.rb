module EventItemsHelper
  # @param collec [Relation, NilClass] Current collection of EventItems to verify the completeness of @event_event_items. If nil, no verification. 
  # @param harami_vid [HaramiVid]
  # @param sorted_eei: [Array, NilClass] sorted @event_event_items (in case it has been already calculated)
  # @return [Relation, NilClass] of ordered (by Music timing) EventItems to choose
  def sorted_event_item_collection(collec=nil, harami_vid=@harami_vid, sorted_eei: nil)
    sorted_eei = sorted_event_event_items_by_timing(harami_vid, @event_event_items) if sorted_eei.blank?  # defined in app/helpers/harami_vids_helper.rb
    evit_ids = sorted_eei.values.compact.flatten.map(&:id)
    if collec && (evit_ids.sort.uniq != collec.pluck(:id).flatten.uniq)
      logger.warn("WARNING: Inconsistent EventItem collection between EventItem-IDs of [@event_event_items, @harami_vid.event_items] = #{[evit_ids.sort.uniq, collec.pluck(:id).flatten.uniq].inspect}, which should never happen...")
      nil  # or you may return: @harami_vid.event_items
    else
     # see re sorting: https://stackoverflow.com/questions/10150152/find-model-records-by-id-in-the-order-the-array-of-ids-were-given/68998474#68998474
      join_sql = "INNER JOIN unnest('{#{evit_ids.join(',')}}'::int[]) WITH ORDINALITY t(id, ord) USING (id)"  # PostgreSQL-specific
      EventItem.joins(join_sql).order("t.ord")
    end
  end

  # @param harami_vid [HaramiVid]
  # @param sorted_eei: [Array, NilClass] sorted @event_event_items (in case it has been already calculated)
  # @return [Array] [ID, machine_title]
  def collection_event_items_for_new_artist_collab(harami_vid=@harami_vid, sorted_eei: nil)
    arbase = [[HaramiVidsController::DEF_FORM_NEW_ARTIST_COLLAB_EVENT_ITEM_NEW, t("layouts.new")+" EventItem"]]
    return arbase if @event_event_items.blank?  # for new (create)

    sorted_eei = sorted_event_event_items_by_timing(harami_vid, @event_event_items) if sorted_eei.blank?  # defined in app/helpers/harami_vids_helper.rb
    arbase + sorted_eei.map{|id_event, ar_event_items| 
        ar_event_items
      }.flatten.map{|ea_event_item| 
        [ea_event_item.id, ea_event_item.machine_title]
      }
  end

  # @param record [EventItem]
  # @return [String]
  def hint_for_data_to_be_imported(record)
    EventItem::ATTRS_TO_BE_CONSISTENT_WITH_PARENT.map{|ek|
      (str_ev = str_data_to_be_imported_for(record, ek)) || (next nil)
      sprintf("%s => %s", ek, str_ev)
    }.compact.join("; ")
  end

  # This method returns String to be printed.
  #
  # To get the Ruby value to be imported, simply use record.
  #
  # @param record [EventItem]
  # @param key [Symbol, String] of an EventItem attribute
  # @return [String, NilClass] nil if no need of importing Event data for the key
  def str_data_to_be_imported_for(record, key)
    (val = record.data_to_import_parent(hsmain: (@hsmain || {}))[key]) || return
    if val.respond_to? :current
      val.current.to_s.inspect
    elsif val.respond_to? :encompass?
      "<"+show_pref_place_country(val, hyperlink: false, prefer_shorter: true)+">"  # defined in places_helper.rb
    else
      val.to_s
    end
  end
end
