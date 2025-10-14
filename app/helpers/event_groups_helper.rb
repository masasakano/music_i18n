module EventGroupsHelper

  # By how many years is the minimum year in the selectbox before the set year?
  #
  # For example, if the set year is 1980, the minimum is 1960.
  START_YEARS_BEFORE_CURRENT = 20

  # For new EventGroup, the minimum year in the selectbox for start_year
  # may be 5 years before the current year, if EventGroup#start_date is recent
  # in case the editor wants to set the start_year earlier than the current year.
  ALLOWANCE_YEARS_START_YEAR_FOR_NEW = 5

  # Returns the minimum year to show in a Date/Time form field
  #
  # Used in {EventGroup}, {Event}, {EventItem}, {Url}
  #
  # @param dtime [Date, Time, TimeWithError, NilClass]
  # @return [Integer]
  def get_form_start_year(dtime)
    def_year = TimeAux::DEF_FIRST_DATE_TIME.year-1
    return def_year if dtime.blank?

    if dtime.year <= def_year
      dtime.year - START_YEARS_BEFORE_CURRENT
    else
      def_year
    end
  end

  # Range for start_date in the selectbox in EventGroup form
  #
  # @param event_group [EventGroup]
  # @return [Array] Start-year, End-year
  def evgr_start_date_select_range_start_end_year(event_group)
    dat = event_group.start_date
    dat_or_this = (dat ? dat : Date.current)

    end_y = [dat_or_this+(START_YEARS_BEFORE_CURRENT+1).year, Date.current].min.year + 1
    [get_form_start_year(dat), end_y]
  end

  # Range for end_date in the selectbox in EventGroup form
  #
  # @param event_group [EventGroup]
  # @return [Array] Start-year, End-year
  def evgr_end_date_select_range_start_end_year(event_group)
    dat = event_group.start_date
    start_y = (dat ? dat.year : TimeAux::DEF_FIRST_DATE_TIME.year)
    start_y = [start_y, Date.current.year-ALLOWANCE_YEARS_START_YEAR_FOR_NEW].min if event_group.new_record?
    # For an existing EventGroup, the minimum selection range for End-date is EventGroup#start_date
    # For new EventGroup, it may be 5 years before the current year, if EventGroup#start_date is recent
    # in case the editor wants to set the start_year earlier than the current year.

    dat_end = event_group.end_date
    end_y = ((start_y >= Date.current.year + EventGroupsController::OFFSET_LARGE_YEAR) ? start_y : [start_y, Date.current.year, dat_end.year].max + 5) # Selection end is +5 years
    dat_or_this = (dat_end ? dat_end : TimeAux::DEF_LAST_DATE_TIME.to_date)
    [start_y, end_y]
  end
end
