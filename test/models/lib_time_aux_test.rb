# coding: utf-8
require 'test_helper'

# Just unit tests for /app/grid/base_grid.rb and /lib/reverse_sql_order.rb
class LibTimeAuxTest < ActiveSupport::TestCase
  include ApplicationHelper # for suppress_ruby270_warnings()

  test "self.converted_middle_time" do
    org = Time.new
    ti = TimeAux.converted_middle_time(org)
    assert_equal ti, org
    assert_equal Rails.configuration.music_i18n_def_timezone_str, ti.formatted_offset
    #assert_equal "+09:00", Rails.configuration.music_i18n_def_timezone_str  # Default.
    assert     ti.respond_to?(:error)
    assert_nil ti.error

    org = Time.new(1999, 6, 10, 8, 17)
    ti = TimeAux.converted_middle_time(org, 13)
    assert_equal  org, ti, "13 should be irrelevant, but..."

    org = Time.new(1999, 6, 10, 8, 17,     in: "+09:00")  # providing this time zone agrees with Rails.configuration.music_i18n_def_timezone_str
    exp = Time.new(1999, 6, 10, 8, 17, 30, in: "+09:00")
    ti = TimeAux.converted_middle_time(1999, 6, 10, 8, 17)
    refute_equal  org, ti
    assert_equal  exp, ti
    assert_equal   30, ti.error.in_seconds

    org = Time.new(2019, 2,     in: "+09:00")  # providing this time zone agrees with Rails.configuration.music_i18n_def_timezone_str
    exp = Time.new(2019, 2, 14, 23, 59, 59.99, in: "+09:00")
    ti = TimeAux.converted_middle_time(2019, 2)
    refute_equal  org, ti
    #assert_equal  exp.day,  ti.day    # 14 <=> 15 (i.e., Date 14, 23:59:59.999 <=> Date 15, 00:00:00)
    #assert_equal  exp.hour, ti.hour   # 23 <=> 0  (i.e., Date 14, 23:59:59.999 <=> Date 15, 00:00:00)
    assert_in_delta exp.to_f, ti.to_f, delta=0.1  # For Float comparison
    assert_equal   14, ti.error.in_days

    # leap year
    org = Time.new(2020, 2,     in: "+09:00")  # providing this time zone agrees with Rails.configuration.music_i18n_def_timezone_str
    exp = Time.new(2020, 2, 15, 11, 59, 59.99, in: "+09:00")
    ti = TimeAux.converted_middle_time(2020, 2)
    refute_equal  org, ti
    assert_equal  exp.day,  ti.day
    #assert_equal  exp.hour, ti.hour
    assert_in_delta exp.to_f, ti.to_f, delta=0.1  # For Float comparison
    assert_in_delta 14.5, ti.error.in_days, delta=0.001

    # Date
    org = Date.new(2021, 2, 17)
    exp = Time.new(2021, 2, 17, 12, 0, 0, in: "+09:00")
    ti = TimeAux.converted_middle_time(org, 1999, 1, 1, 1, 1)  # 1999 and after are garbage
    assert_equal  org, ti.to_date
    assert_equal  exp,  ti

    # Special cases
    ti = TimeAux.converted_middle_time(2019, nil)  # 2019 defined at Rails.application.config.music_i18n_def_first_event_year 
    assert_equal TimeAux::DEF_FIRST_DATE_TIME, ti
    ti = TimeAux.converted_middle_time(9999, nil)
    assert_equal TimeAux::DEF_LAST_DATE_TIME, ti
  end

  test "adjusted_time_array1" do
    ## 6 arguments
    exp = [1999, 6, 10, 8, 17, 25]
    org = Time.new(*exp, in: "+09:00")  # providing this time zone agrees with Rails.configuration.music_i18n_def_timezone_str
    ary = TimeAux.adjusted_time_array(org, err: 30.second)
    assert_equal  exp, ary

    ary = TimeAux.adjusted_time_array(org, err: 30)
    assert_equal  exp, ary

    ary = TimeAux.adjusted_time_array(org)
    assert_equal  exp, ary

    org = TimeWithError.at(org, in: "+09:00")  # providing this time zone agrees with Rails.configuration.music_i18n_def_timezone_str
    org.error = 30.second
    ary = TimeAux.adjusted_time_array(org)
    assert_equal  exp, ary

    ## insignificant 'second'
    exp = [1999, 6, 10, 8, 17, nil]
    orgin = exp[0..4]+[30]
    org = Time.new(*orgin, in: "+09:00")  # providing this time zone agrees with Rails.configuration.music_i18n_def_timezone_str
    assert_equal 30, org.sec
    ary = TimeAux.adjusted_time_array(org, err: 30.second)
    assert_equal  exp, ary

    ary = TimeAux.adjusted_time_array(org, err: 30)
    assert_equal  exp, ary

    ary = TimeAux.adjusted_time_array(org)
    assert_equal  orgin, ary

    org = TimeWithError.at(org, in: "+09:00")  # providing this time zone agrees with Rails.configuration.music_i18n_def_timezone_str
    org.error = 30.second
    ary = TimeAux.adjusted_time_array(org)
    assert_equal  exp, ary

    ## insignificant 'day'
    exp = [2004, 2, nil, nil, nil, nil]
    orgin = [2004, 2, 15, 0, 0, 0]
    org = Time.new(*orgin, in: "+09:00")  # providing this time zone agrees with Rails.configuration.music_i18n_def_timezone_str
    assert_equal 0, org.sec
    ary = TimeAux.adjusted_time_array(org, err: 14.day)
    assert_equal  exp, ary

    ary = TimeAux.adjusted_time_array(org, err: 14*24*3600)
    assert_equal  exp, ary

    ary = TimeAux.adjusted_time_array(org)
    assert_equal  orgin, ary

    org = TimeWithError.at(org, in: "+09:00")  # providing this time zone agrees with Rails.configuration.music_i18n_def_timezone_str
    org.error = 14.day
    ary = TimeAux.adjusted_time_array(org)
    assert_equal  exp, ary

    ## Date input, meaning insignificant 'hour'
    exp = [2004, 2, 18, nil, nil, nil]
    orgin = [2004, 2, 18]
    org = Date.new(*orgin)

    ary = TimeAux.adjusted_time_array(org)
    assert_equal  exp, ary
  #end
  #test "adjusted_time_array2" do

    # Special cases
    ary = TimeAux.adjusted_time_array(TimeAux::DEF_FIRST_DATE_TIME)
    assert_equal TimeAux::DEF_FIRST_DATE_TIME.year,  ary[0]
    assert_nil   ary[1]
    assert_nil   ary[2]
    assert_nil   ary[3]
    assert_nil   ary[4]
    assert_nil   ary[5]

    ary = TimeAux.adjusted_time_array(TimeAux::DEF_LAST_DATE_TIME)
    assert_equal TimeAux::DEF_LAST_DATE_TIME.year,   ary[0]
    assert_nil   ary[1]
    assert_nil   ary[2]
    assert_nil   ary[3]
    assert_nil   ary[4]
    assert_nil   ary[5]
  end

  test "to_time_midday_utc" do
    assert_equal 12, TimeAux.to_time_midday_utc(Date.new(2024,10,20)).hour
    assert_equal 12, TimeAux.to_time_midday_utc(Date.new(2024,10,28)).hour
  end
end


