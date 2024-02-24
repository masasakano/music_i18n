# -*- coding: utf-8 -*-

# This is required in /config/application.rb
module TimeAux

  module_function  # equivalent to: extend self

  # Returns the "middle" TimeWithError object, considering the uncertainty
  #
  # For example, if it is from February 1999 (non-leap year) and unknown day, hour etc,
  # this returns {TimeWithError} of +1999-03-14 23:59:59.999999999+
  # in the application-wide time zone {Rails.configuration.music_i18n_def_timezone_str}
  # (JST in default).
  #
  # Argument(s) are one of Date, Time (or TimeWithError), and Array of Integers.
  # If Time (or TimeWithError) is given, make sure its timezone agrees with the application-wide one.
  # Otherwise, the result may be slighly different from your expectation.
  # TimeWithError defined in /lib/time_with_error.rb
  #
  # @example specify Time or Date
  #    get_middle_time(Time.new(2024, 1, in: Rails.configuration.music_i18n_def_timezone_str, known_unit: :month)
  #      # => TimeWithError(2024-01-15 12:00:00 +09:00, err=31.days)
  #
  # @example specify a set of Integers
  #    get_middle_time(2024, 1, 7, 14)
  #      # => TimeWithError(2024-01-07 14:30:00 +09:00, err=31.days)  # i.e., Time(2024-01-07 05:30:00 UTC)
  #      # known_unit (=> hour) is automatically determined.
  #
  # @param dtime [Date, Time, Integer] nb., DateTime is OK but it is deprecated in Ruby 3. Or, Integer for Year.
  # @param month [Integer, NilClass] If dtime is Integer, meaning Year, this may be specified and is checked.
  # @param day   [Integer, NilClass] If month is specified and valid, this is checked.
  # @param hour   [Integer, NilClass] If day   is specified and valid, this is checked.
  # @param minute [Integer, NilClass] If hour  is specified and valid, this is checked.
  # @param second [Integer, NilClass] If minute is specified and valid, this is checked.
  # @return [TimeWithError] the "middle" TimeWithError in the system (config) TimeZone and its uncertainty is in ActiveSupport::Duration
  def converted_middle_time(dtime, *rest)  #, known_unit: nil)
    dtime, known_unit = _time_from_date_or_array(dtime, *rest)
    return TimeWithError.at(dtime, in: Rails.configuration.music_i18n_def_timezone_str) if ! known_unit

    ku = known_unit.to_s
    dt_begin = dtime.send("beginning_of_"+ku)  # e.g., dtime.beginning_of_month
    dt_end   = dtime.send("end_of_"+ku)

    duration_sec = dt_end.to_time.to_f - dt_begin.to_time.to_f
    ret = TimeWithError.at( Time.at(dt_begin.to_time.to_f + duration_sec/2.0, in: Rails.configuration.music_i18n_def_timezone_str) )
    ret.error = (duration_sec/2.0).second
    ret
  end # def converted_middle_time(dtime, *rest)

  # Returns the 6-element Array of Year, Month, ... guessed from the given Time and error
  #
  # Kind of reverse of {#converted_middle_time} .
  # Less significant elements may be set nil,
  # depending on the given {TimeWithError#error} or +err+ and Time value.
  # For example, when the first argument is Date, the last three elements (hour, minute, second)
  # are set nil.
  #
  # @param dtime [Date, Time, TimeWithError] nb., DateTime is OK but it is deprecated in Ruby 3.
  # @param err [ActiveSupport::Duration, Integer, NilClass] Duration. Maybe included in +dtime.error+ (if it is a TimeWithError).  If Integer, the unit is a second. nil means undefined; if so and IF dtime is Date, this is automatically determined.
  # @return [Array<Numeric>] 6-element Array of Year, Month, Day, Hour, Minute, Second
  def adjusted_time_array(dtime, err: nil)
    # Converts Date into Time, whereas TimeWithError or Time remains as it is.
    dtime, known_unit = _time_from_date_or_array(dtime)
    # known_unit is non-nil only for Date

    # err is taken from dtime.error (if defined) as a fallback.
    err ||= dtime.error if dtime.respond_to?(:error)  # if TimeWithError
    err ||= err.second if err && dtime.respond_to?(:error)  # if TimeWithError
    err = err.second   if err && !err.respond_to?(:in_seconds)

    arret = %i(year month day hour min sec).map{|i| dtime.send(i)}
    return arret if !err && !known_unit

    ra=(14..16)
    if    :minute == known_unit || (err && 30 == err.in_seconds.round && (29..31).cover?(dtime.sec))
      arret[5] = nil
    elsif :hour   == known_unit || (err && 30 == err.in_minutes.round && 30 == dtime.min)
      arret.fill nil, 4..5
    elsif :day    == known_unit || (err && 12 == err.in_hours.round   && 12 == dtime.hour)
      arret.fill nil, 3..5
    elsif :month  == known_unit || (err && ra.cover?(err.in_days.round) && ra.cover?(dtime.day))
      arret.fill nil, 2..5
    elsif :year   == known_unit || (err && 6 == err.in_months.round   && 12 == dtime.month)
      arret.fill nil, 1..5
    else
      nil
    end

    arret
  end

  # Returns Time converted from Date or Integer-Array, as well as Symbol in some cases
  #
  # This returns Symbol like +:day+ as the 2nd element only when the given arguments
  # are either Date or Array of Integers (to indicate Date/Time).
  #
  # @example
  #    ti, k = _time_from_date_or_array(1993, 12, nil) # return Array(!)
  #    ti, _ = _time_from_date_or_array(Date.today)  # the receiver may contain "_" with no harm
  #    ti    = _time_from_date_or_array(Time.now)    # or  receiver may be a single variable.
  #
  # @param dtime  [Date, Time, Integer] nb., DateTime is OK but it is deprecated in Ruby 3. Or, Integer for Year.
  # @param month  [Integer, NilClass] If dtime is Integer, meaning Year, this may be specified and is checked.
  # @param day    [Integer, NilClass] If month is specified and valid, this is checked.
  # @param hour   [Integer, NilClass] If day   is specified and valid, this is checked.
  # @param minute [Integer, NilClass] If hour  is specified and valid, this is checked.
  # @param second [Integer, NilClass] If minute is specified and valid, this is checked.
  # @return [Time, Array<Time, Symbol>]] If Array is given, returns 2-element Array of Time and "known_unit"; otherwise Time only.
  def _time_from_date_or_array(dtime, month=nil, day=nil, hour=nil, minute=nil, second=nil)
    # if Date, treats it as in a date-time Array.
    if dtime.respond_to? :gregorian
      dtime, month, day, hour = dtime.year, dtime.mon, dtime.day, nil
    end

    return dtime if !dtime.respond_to? :divmod

    known_unit = _guess_known_unit_from_ary(dtime, month, day, hour, minute, second)
    ret1 = Time.new(dtime, month, day, hour, minute, second, in: Rails.configuration.music_i18n_def_timezone_str)
    [ret1, known_unit]
  end
  private :_time_from_date_or_array

  # Returns the least significant known time unit
  #
  # @example
  #    _time_from_date_or_array(1993, 12)         # => :month
  #    _time_from_date_or_array(1993, 12, nil, 5) # => :month
  #
  # @param year   [Integer, NilClass] If nil, it means the entire Time is nil.
  # @param month  [Integer, NilClass] If year is Integer, this may be specified and is checked.
  # @param day    [Integer, NilClass] If month is specified and valid, this is checked.
  # @param hour   [Integer, NilClass] If day   is specified and valid, this is checked.
  # @param minute [Integer, NilClass] If hour  is specified and valid, this is checked.
  # @param second [Numeric, NilClass] If minute is specified and valid, this is checked.
  # @return [Symbol, NilClass] Symbol of the last significant unit or nil
  def _guess_known_unit_from_ary(year, month=nil, day=nil, hour=nil, minute=nil, second=nil)
    if !year
      nil  # Entire Time is nil
    elsif !month
      :year
    elsif !day
      :month
    elsif !hour
      :day
    elsif !minute
      :hour
    elsif !second
      :minute
    else
      nil  # Nothing is nil
    end
  end
  private :_guess_known_unit_from_ary
end
