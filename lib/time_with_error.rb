# -*- coding: utf-8 -*-

# Same as Time, but an instance variable and its accessor "error" are defined.
class TimeWithError < Time
  # maybe an instance of ActiveSupport::Duration (or nil)
  #
  # @example
  #   t = TimeWithError.new(Time.now)
  #   t.error = 10.minute  # => ActiveSupport::Duration
  #   t.error.in_seconds   # => 600
  attr_accessor "error"
end

