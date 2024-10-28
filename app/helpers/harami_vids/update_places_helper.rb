module HaramiVids::UpdatePlacesHelper
  # Returns a Place if HaramiVid's place encompasses its EventItem(s)
  #
  # If multiple EventItems are associated, all the Place-s of EventItem-s
  # must be common.
  #
  # @param hvid [HaramiVid]
  # @return [Place, NilClass] nil if no need to update {HaramiVid#place}
  def get_evit_place_if_need_updating(hvid)
    return if !hvid.event_items.exists?
    plas = hvid.event_items.map{|i| i.place}.uniq
    return if plas.size != 1
    return if !(ret=plas.first)
    (!hvid.place || hvid.place.encompass_strictly?(ret)) ? ret : nil
  end
end
