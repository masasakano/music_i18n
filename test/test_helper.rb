# coding: utf-8
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'w3c_validators'
require "helpers/controller_helper"
require "helpers/test_system_helper"

Dir[Rails.root.to_s+"/db/seeds/*.rb"].uniq.each do |seed|
  next if /^seeds_/ =~ File.basename(seed)  # Skipping reading the old-style Modules
  require seed
end

ActiveRecord::FixtureSet.context_class.include Seeds

class ActiveSupport::TestCase
  include ApplicationHelper

  DEF_RELPATH_HARAMI1129_LOCALTEST = 'test/controllers/harami1129s/data/harami1129_sample.html'

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


  # Validate HTML with W3C
  #
  # To call this method, you need to put the following in your caller:
  #
  #   setup do
  #     @validator = W3CValidators::NuValidator.new
  #   end
  # 
  # If environmental variable SKIP_W3C_VALIDATE is set and not '0' or 'false',
  # validation is skipped.
  #
  # The caller information is printed if fails.
  #
  # If the error message is insufficient, you may simply print out 'response.body' in the caller,
  # or better
  #
  #   @validator.validate_text(response.body).debug_messages.each do |key, value|
  #     puts "#{key}: #{value}"
  #   end
  #
  # @param name [String] Identifier for the error message.
  def w3c_validate(name="caller")
    return if is_env_set_positive?('SKIP_W3C_VALIDATE')
    #ENV.keys.include?('SKIP_W3C_VALIDATE') && !%w(0 false FALSE).include?(ENV.keys.include?('SKIP_W3C_VALIDATE'))

    bind = caller_locations(1,1)[0]  # Ruby 2.0+
    caller_info = sprintf "%s:%d", bind.absolute_path.sub(%r@.*(/test/)@, '\1'), bind.lineno
    # NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"

    ## W3C HTML validation (Costly operation)
    arerr = @validator.validate_text(response.body).errors
    arerr = _may_ignore_autocomplete_errors_for_hidden(arerr, "Ignores W3C validation errors for #{name} (#{caller_info}): ")
    assert_empty arerr, "Failed for #{name} (#{caller_info}): W3C-HTML-validation-Errors(Size=#{arerr.size}): ("+arerr.map(&:to_s).join(") (")+")"
  end

  # Botch fix of W3C validation errors for HTMLs generated by button_to
  #
  # On 2022-10-26, W3C validation implemented a check, which may raise an error:
  #
  # > An input element with a type attribute whose value is hidden must not have an autocomplete attribute whose value is on or off.
  #
  # This is particularly the case for HTMLs generated by button_to as of Rails 7.0.4.
  # It seems the implementation in Rails was deliberate to deal with mal-behaviours of
  # Firefox (Github Issue-42610: https://github.com/rails/rails/issues/42610 ).
  #
  # Whatever the reason is, it is highly inconvenient for developers who
  # use W3C validation for their Rails apps.
  # 
  # This routine takes a W3C-validation error object (Array) and
  # return the same Array where the specific errors are deleted
  # so that one could still test the other potential errors with the W3C validation.
  # The said errors are recorded with +logger.warn+ (if +prefix+ is given).
  #   
  # Note that this routine does nothing *unless* the config parameter
  #   config.ignore_w3c_validate_hidden_autocomplete = true
  # is set in config, e.g., in the file (if for testing use only):
  #   /config/environments/test.rb
  #
  # == References
  #
  # * Stackoverflow: https://stackoverflow.com/questions/74256523/rails-button-to-fails-with-w3c-validator
  # * Github: https://github.com/validator/validator/pull/1458
  # * HTML Spec: https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#autofilling-form-controls:-the-autocomplete-attribute:autofill-anchor-mantle-2
  #
  # @example Usage, maybe in /test/test_helper.rb
  #   # Make sure to write in /config/environments/test.rb
  #   #    config.ignore_w3c_validate_hidden_autocomplete = true
  #   #
  #   #require 'w3c_validators'
  #   bind = caller_locations(1,1)[0]  # Ruby 2.0+
  #   caller_info = sprintf "%s:%d", bind.absolute_path.sub(%r@.*(/test/)@, '\1'), bind.lineno
  #   errors = @validator.validate_text(response.body).errors
  #   prefix = "Ignores W3C validation errors (#{caller_info}): "
  #   errors = _may_ignore_autocomplete_errors_for_hidden(errors, prefix)
  #   assert_empty errors, "Failed in W3C validation: "+errors.map(&:to_s).inspect
  #
  # @param errs [Array<W3CValidators::Message>] Output of +@validator.validate_text(response.body).errors+
  # @param prefix [String] Prefix of the warning message recorded with Logger.
  #    If empty, no message is recorded in Logger.
  # @return [Array<String, W3CValidators::Message>]
  def _may_ignore_autocomplete_errors_for_hidden(errs, prefix="")
    removeds = []
    return errs if !Rails.configuration.ignore_w3c_validate_hidden_autocomplete
    errs.map{ |es|
      # Example of an Error:
      #   ERROR; line 165: An “input” element with a “type” attribute whose value is “hidden” must not have an “autocomplete” attribute whose value is “on” or “off”
      if /\AERROR\b.+\binput\b[^a-z]+\belement.+\btype\b.+\bhidden\b.+\bautocomplete\b[^a-z]+\battribute\b/i =~ es.to_s
        removeds << es
        nil
      else
        es
      end
    }.compact

  ensure
    # Records it in Logger
    if !removeds.empty? && !prefix.blank?
      Rails.logger.warn(prefix + removeds.map(&:to_s).uniq.inspect)
    end
  end


  # Validate if Flash message matches the given Regexp (called from Controller tests)
  #
  # Search is based on CSS classes.
  #
  # See {ApplicationController::FLASH_CSS_CLASSES} for CSS classes in this app.
  #
  # *Tip*: If the type is in suspect, pass nil to type (Default).
  #
  # @param regex [Regexp] 
  # @param msg [String] 
  # @param type [Symbol, Array<Symbol>, NilClass] :notice, :alert, :warning, :success or their array.
  #    If nil, everything defined in {ApplicationController::FLASH_CSS_CLASSES}
  #    Note that the actual CSS is "alert-danger" (Bootstrap) for :alert, etc.
  def flash_regex_assert(regex, msg=nil, type: nil)
    bind = caller_locations(1,1)[0]  # Ruby 2.0+
    caller_info = sprintf "%s:%d", bind.absolute_path.sub(%r@.*(/test/)@, '\1'), bind.lineno
    # NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"

    all_flash_types = ApplicationController::FLASH_CSS_CLASSES.keys.map(&:to_s) # String
    types = type && [type.to_s].flatten || all_flash_types
    if types.any?{|i| !ApplicationController::FLASH_CSS_CLASSES.keys.include?(i)}
      raise "(#{caller_info}) (#{__FILE__}) Flash type (#{types.inspect}) must be included in ApplicationController::FLASH_CSS_CLASSES="+ApplicationController::FLASH_CSS_CLASSES.keys.map(&:to_sym).inspect
    end
    cond = types.map{|i| "div#body_main "+"p."+ApplicationController::FLASH_CSS_CLASSES[i].strip.split.join(".")}.join(", ")  # "div#body_main p.alert.alert-danger div#body_main p.alert.alert-warning" etc
    csstext = css_select(cond).text
    msg2pass = (msg || sprintf("Fails in flash(%s)-message regexp matching for: ", (type || "ALL")))+csstext.inspect
    assert_match(regex, csstext, "(#{caller_info}): "+msg2pass)
  end

  # Asserts in a Conroller test no presence of alert on the page and prints the alert in failing it
  #
  # This tests both a flash and screen. In some cases, the previous flash remains
  # in testing.  In such case, specify +screen_test_only: true+
  def my_assert_no_alert_issued(screen_test_only: false)
    bind = caller_locations(1,1)[0]  # Ruby 2.0+
    caller_info = sprintf "%s:%d", bind.absolute_path.sub(%r@.*(/test/)@, '\1'), bind.lineno
    # NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"

    assert  flash[:alert].blank?, "Failed(#{caller_info}) with Flash-alert: "+(flash[:alert] || "") if !screen_test_only
    msg_alert = css_select(".alert").text.strip
    assert_empty msg_alert, "(#{caller_info}):Alert: #{msg_alert}"
  end

  # assert if the attribute of the instance is updated
  #
  # @note model is reloaded!
  #
  # @param model [Model]
  # @param attr [String, Symbol] Attribute
  # @param msg [String] message parameter for assert
  # @param inspect [Boolean] if true, the difference would be printed if failed.
  # @param refute [Boolean] if true (Def: false), returns true if NOT updated. cf. user_refute_updated_attr?
  # @param bind_offset [Integer] offset for caller_locations (used for displaying the caller routine)
  def user_assert_updated_attr?(model, attr, msg=nil, inspect: true, refute: false, bind_offset: 0)
    bind = caller_locations(1+bind_offset, 1)[0]  # Ruby 2.0+
    caller_info = sprintf "%s:%d", bind.absolute_path.sub(%r@.*(/test/)@, '\1'), bind.lineno
    # NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"

    upd, msg2pass = _reload_and_get_message(model, msg, inspect, attr, caller_info)
    if refute
      assert_equal upd, model.send(attr), msg2pass
    else  # Default
      refute_equal upd, model.send(attr), msg2pass
    end
  end

  # refute if the attribute of the instance is updated
  #
  # @param #see user_assert_updated_attr?
  def user_refute_updated_attr?(model, attr, msg=nil, inspect: true)
    user_assert_updated_attr?(model, attr, msg=nil, inspect: true, refute: true, bind_offset: 1)
  end

  # assert if the instance is updated, checking updated_at 
  #
  # @note model is reloaded!
  #
  # @param model [Model]
  # @param msg [String] message parameter for assert
  # @param inspect [Boolean] if true, the difference would be printed if failed.
  # @param refute [Boolean] if true (Def: false), returns true if NOT updated. cf. user_refute_updated_attr?
  # @param bind_offset [Integer] offset for caller_locations (used for displaying the caller routine)
  def user_assert_updated?(model, msg=nil, inspect: true, refute: false, bind_offset: 0)
    bind = caller_locations(1+bind_offset, 1)[0]  # Ruby 2.0+
    caller_info = sprintf "%s:%d", bind.absolute_path.sub(%r@.*(/test/)@, '\1'), bind.lineno
    # NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"

    upd, msg2pass = _reload_and_get_message(model, msg, inspect, :updated_at, caller_info)
    if refute
      refute_operator upd, :<, model.updated_at, msg2pass
    else
      assert_operator upd, :<, model.updated_at, msg2pass
    end
  end

  # refute if the instance is updated, checking updated_at 
  #
  # i.e., true if instance is NOT updated.
  #
  # @param model [Model]
  # @param msg [String] message parameter for assert/refute
  # @param inspect [Boolean] if true, the difference would be printed if failed.
  def user_refute_updated?(model, msg=nil, inspect: true)
    user_assert_updated?(model, msg=nil, inspect: true, refute: true, bind_offset: 1)
    #bind = caller_locations(1,1)[0]  # Ruby 2.0+
    #caller_info = sprintf "%s:%d", bind.absolute_path.sub(%r@.*(/test/)@, '\1'), bind.lineno
    ## NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"
    #
    #upd, msg2pass = _reload_and_get_message(model, msg, inspect, :updated_at, caller_info)
    #assert_equal upd, model.updated_at, msg2pass
  end

  # Internal common routine.
  #
  # @param model [Model]
  # @param msg [String] message parameter for assert
  # @param inspect [Boolean] if true, the difference would be printed if failed.
  # @param attr [Symbol] Attribute
  # @param caller_info [String]
  # @return [Object, String] Old object and Error message to pass
  def _reload_and_get_message(model, msg, inspect, attr, caller_info)
    old = model.inspect if inspect
    upd = model.send(attr)
    model.reload
    msg2pass = "(#{caller_info}): "+(msg || "")+(inspect ? ":(Old|New) \n#{old} => \n#{model.inspect}" : "")
    [upd, msg2pass]
  end
  private :_reload_and_get_message

  # @see https://stackoverflow.com/questions/13187753/rails3-jquery-autocomplete-how-to-test-with-rspec-and-capybara
  # No need of sleep!
  #
  # CSS looks different from the above URI:
  #   <li class="ui-menu-item">
  #     <div id="ui-id-2" tabindex="-1" class="ui-menu-item-wrapper">OneCandidate</div>
  #   </li>
  def fill_autocomplete(field, **options)
    fill_in field, with: options[:with]

    page.execute_script %Q{ $('##{field}').trigger('focus') }
    page.execute_script %Q{ $('##{field}').trigger('keydown') }

    selector = %Q{ul.ui-autocomplete li.ui-menu-item:contains("#{options[:select]}")}  # has to be double quotations (b/c of the sentence below)
    ## Or, more strictly,
    #selector = %Q{ul.ui-autocomplete li.ui-menu-item div.ui-menu-item-wrapper:contains("#{options[:select]}")}  # has to be double quotations (b/c of the sentence below)

    bind = caller_locations(1,1)[0]  # Ruby 2.0+
    caller_info = sprintf "%s:%d", bind.absolute_path.sub(%r@.*(/test/)@, '\1'), bind.lineno
    # NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"

    # page.should have_selector selector  # I think this is for RSpec only. # This ensures to wait for the popup to appear.
    #print "DEBUG: "; p page.find('ul.ui-autocomplete div.ui-menu-item-wrapper')['innerHTML']
    ## assert page.has_selector? selector  # Does not work (maybe b/c it is valid only for jQuery; officially CSS does not support "contains" selector, which is deprecated): Selenium::WebDriver::Error::InvalidSelectorError: invalid selector: An invalid or illegal selector was specified
    begin
      assert_selector selector.sub(/:contains.*/, '')  # This MAY ensure to wait for the popup to appear??
      flag = true
    ensure
      warn "ERROR: Failed when called from (#{caller_info})" if !flag
    end

    page.execute_script %Q{ $('#{selector}').trigger('mouseenter').click() }
  end

  # Set ENV['URI_HARAMI1129'] for local model/controller tests
  #
  # If ENV['URI_HARAMI1129_LOCALTEST'] is set as either the local-file full path or
  # a path below Rails.root like 'test/my_data/x.html', it is used
  # (Default: DEF_RELPATH_HARAMI1129_LOCALTEST)
  def set_uri_harami1129_localtest
    ENV['URI_HARAMI1129'] = 
      if ENV['URI_HARAMI1129_LOCALTEST'].blank? || %r@\A[^/]*:/@ =~ ENV['URI_HARAMI1129_LOCALTEST']
        if !ENV['URI_HARAMI1129_LOCALTEST'].blank?
          msg = "WARNING: Ignored and reset to Default (should be either the local absolute path or relative path beggining with 'test/': ENV['URI_HARAMI1129_LOCALTEST']=#{ENV['URI_HARAMI1129_LOCALTEST']}"
          Rails.logger.warn msg
          $stderr.puts msg
        end
        (Rails.root+DEF_RELPATH_HARAMI1129_LOCALTEST).to_s
      elsif %r@\A/@ =~ ENV['URI_HARAMI1129_LOCALTEST']
        ENV['URI_HARAMI1129_LOCALTEST']
      else
        (Rails.root+ENV['URI_HARAMI1129_LOCALTEST']).to_s
      end

    if !File.exist? ENV['URI_HARAMI1129']
      msg = "ERROR: Local test file (#{ENV['URI_HARAMI1129']}) not exist, maybe because ENV['URI_HARAMI1129_LOCALTEST']=(#{ENV['URI_HARAMI1129_LOCALTEST']}) is invalid."
      Rails.logger.error msg
      $stderr.puts msg
    end
    Rails.logger.info "INFO: to read Local test data file: #{ENV['URI_HARAMI1129']}"
  end

  # Get a unique id_remote for Harami1129
  #
  # @param *rest [Integer] (Multiple) integer that should be avoided (maybe the previous yet-unsaved outputs of this method)
  # @return [Integer]
  def _get_unique_id_remote(*rest)
    (Harami1129.all.pluck(:id_remote).compact+rest).sort.last.to_i + 1
  end

  # called from /test/controllers/{artists,musics}/merges_controller_test.rb
  # cf. /test/controllers/harami1129s/populates_controller_test.rb
  # @return [Harami1129]
  def _populate_harami1129_sting(h1129)
    assert_difference('Harami1129.count + HaramiVid.count*10000', 0) do
      patch harami1129_internal_insertions_url(h1129)
      assert_response :redirect
      assert_redirected_to harami1129_url h1129
    end
    h1129.reload

    assert_difference('HaramiVid.count*10000 + HaramiVidMusicAssoc.count*1000 + Music.count*100 + Artist.count*10 + Engage.count', 11111) do
      patch harami1129_populate_url(h1129)
      assert_response :redirect
      assert_redirected_to harami1129_url h1129
    end
    h1129.reload
  end
end
