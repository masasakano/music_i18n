ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Disable routing-filter in testing
  RoutingFilter.active = false

  # Add more helper methods to be used by all tests here...
  include Devise::Test::IntegrationHelpers
  include Warden::Test::Helpers

  ## helper to enable PaperTrail on specific tests
  def with_versioning
    was_enabled = PaperTrail.enabled?
    was_enabled_for_request = PaperTrail.request.enabled?
    PaperTrail.enabled = true
    PaperTrail.request.enabled = true
    begin
      yield
    ensure
      PaperTrail.enabled = was_enabled
      PaperTrail.request.enabled = was_enabled_for_request
    end
  end

  # not works well for some reason...
  def log_in( user )
    if integration_test?
      #use warden helper
      login_as(user, :scope => :user)
    else #controller_test, model_test
      #use devise helper
      sign_in(user)
    end
  end

  # add until here
  # ---------------------------------------------

  # Reverse of get_date_time_from_params in Application.helper
  #
  # pReturns a Hash like params from Date/DateTime
  #   {"r_date(1i)"=>"2019", "r_date(2i)"=>"1", "r_date(3i)"=>"9"}
  #
  # @param dt [Date, DateTime]
  # @param kwd [String, Symbol] Keyword of params
  # @param maxnum [Integer, NilClass] Number of parameters in params
  #    In default (if nil is given), 3 for Date and 5 for DateTime
  #    (n.b., "second" is not included as in Rails default).
  # @return [Date, DateTime]
  def get_params_from_date_time(dt, kwd, maxnum=nil)
    is_date = (dt.respond_to? :julian?)
    num = (maxnum || (is_date ? 3 : 5))

    if is_date
      num = [num, 3].min
      dtoa = %i(year month day).map{|i| dt.send(i)}[0..(num-1)]
    else
      num = [num, 6].min
      dtoa = dt.to_a[0,6].reverse[0..(num-1)]
    end

    s_kwd = kwd.to_s
    (1..num).to_a.map{|i| [sprintf("#{s_kwd}(%di)", i), dtoa[i-1]]}.to_h
  end

  # Reverse of get_bool_from_params in Application.helper
  #
  # The input should be String.
  #
  # @param prmval [String, NilClass] params['is_ok']
  # @return [Boolean, NilClass]
  def get_params_from_bool(val)
    val ? "1" : "0"
  end

  # Convert Ruby Hash to params style
  #
  # Note if the value is nil, it is converted into "";
  # however if it is a check_box, it should be "0" or "1".
  #
  # @param hsin [Hash] Input Hash
  # @param maxdatenum [Integer, NilClass] Number of parameters in params or Date/DateTime
  # @return [Hash]
  def convert_to_params(hsin, maxdatenum: nil)
    ardts = []  # To hold Array of "Hashes created from Date/DateTime"
    hsout = hsin.map{|ek, ev|
      if ev.respond_to? :wednesday?
        ardts << get_params_from_date_time(ev, ek, maxnum=maxdatenum)
        nil
      else
        [ek.to_s,
         case ev
         when nil
           ""
         when true
           "1"
         when false
           "0"
         else
           ev.to_s
         end
        ]
      end
    }.compact.to_h
    hsout.merge ardts.inject({}, &:merge)
  end

end
