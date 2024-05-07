module EventGroupsHelper

  # Returns the minimum year to show in a Date/Time form field
  #
  # @param dtime [Date, Time, TimeWithError, NilClass]
  # @return [Integer]
  def get_form_start_year(dtime)
    def_year = TimeAux::DEF_FIRST_DATE_TIME.year-1
    return def_year if dtime.blank?

    if dtime.year <= def_year
      dtime - 20
    else
      def_year
    end
  end
end
