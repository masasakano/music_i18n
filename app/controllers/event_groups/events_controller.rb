module EventGroups
  class EventsController < ApplicationController
    DEF_YEAR_BEGIN = Time.current.year

    def index
      @events = self.class.filter_events(params[:event_group_id], params[:year_begin], params[:year_end])

      render layout: false
    end

    # @param event_group_id_raw [NilClass, String, Integer] can be "all"
    # @param year_begin_raw [String, Integer, NilClass]
    # @param year_end_raw   [String, Integer, NilClass]
    # @return [Event]
    def self.filter_events(event_group_id_raw, year_begin_raw, year_end_raw)
      # If "all" is given, no filtering based on EventGroup
      events, evgr_id =  ## evgr_id is an (empty or number-like) String or nil or Integer
        if event_group_id_raw == "all"
          [Event.all, nil]
        else
          [Event.where(event_group_id: event_group_id_raw), event_group_id_raw]
        end

      # Filter using database-indexed date range
      year_begin = year_begin_raw.presence ? year_begin_raw.to_i : DEF_YEAR_BEGIN
      year_end   = year_end_raw.presence   ? year_end_raw.to_i   : year_begin
      year_begin = 2 if year_begin <= Rails.configuration.music_i18n_def_first_event_year  # year_end = 2019
      year_begin, year_end = year_end, year_begin if year_begin > year_end

      start_time_begin = Time.zone.local(year_begin).beginning_of_year - 1.day
      start_time_end   = Time.zone.local(year_end).end_of_year + 1.day

      events = events.where(start_time: start_time_begin..start_time_end)

      # Unknown Event in each EventGroup is always available regardless of the date-range filter
      events = events.or(Event.where(id: EventGroup.find(evgr_id).unknown_event)) if evgr_id.present?

      events 
    end
  end
end
