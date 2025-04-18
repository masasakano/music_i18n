# coding: utf-8
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require "helpers/model_helper"
require "helpers/controller_helper"
require "helpers/test_system_helper"
require_relative './test_w3c_validate_helper'

Dir[Rails.root.to_s+"/db/seeds/*.rb"].uniq.each do |seed|
  next if /^seeds_/ =~ File.basename(seed)  # Skipping reading the old-style Modules
  require seed
end
require Rails.root.to_s+"/db/seeds/event_groups" # EventGroup

ActiveRecord::FixtureSet.context_class.include Seeds

class ActiveSupport::TestCase
  include ApplicationHelper
  include TestW3cValidateHelper

  DEF_RELPATH_HARAMI1129_LOCALTEST = 'test/controllers/harami1129s/data/harami1129_sample.html'

  # Used in the method {#_get_caller_info_message}. 0 means the caller (of the method) itself. 1 means its parent.
  BASE_CALLER_INFO_BIND_OFFSET = 1

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

  # CSS for pages
  PAGECSS = {
    new_trans_lang_radios: 'form div.field.radio_langcode',  # eg: page.find(PAGECSS[:new_trans_lang_radios]).choose('English')
    show: {
      pid: ".show_unique_parameters dd.item_pid", # see retrieve_pid_in_show() below
    },
  }.with_indifferent_access

  # CSS for Grids
  CSSGRIDS = {
    form: 'form.datagrid-form',  # used to be form#new_artists_grid in DataGrid Ver.1
    # input_sex:      'input[name="artists_grid[sex][]"]',
    # input_title_en: 'input#artists_grid_title_en',  # maybe preceded with div.datagrid-filter
    table:          'table.datagrid-table',  # used to contain 'table.artists_grid' in DataGrid Ver.1
  }.with_indifferent_access
  CSSGRIDS.merge!({
    form_reset: CSSGRIDS[:form]+' div.datagrid-actions a.datagrid-reset',
    th_tr: CSSGRIDS[:table]+' thead tr',
    tb_tr: CSSGRIDS[:table]+' tbody tr',
  })
  CSSGRIDS.merge!({
    th_sex:      CSSGRIDS[:th_tr]+' th[data-column="sex"]',  # used to be "th.sex" in Datagrid Ver.1
    th_title_en: CSSGRIDS[:th_tr]+' th[data-column="title_en"]',
    th_events:   CSSGRIDS[:th_tr]+' th[data-column="events"]',
    th_collabs:  CSSGRIDS[:th_tr]+' th[data-column="collabs"]',
    td_title_ja: CSSGRIDS[:tb_tr]+' td[data-column="title_ja"]',
    td_title_en: CSSGRIDS[:tb_tr]+' td[data-column="title_en"]',
  })
  CSSGRIDS.merge!({
    th_title_en_a_asc:  CSSGRIDS[:th_title_en]+' div.datagrid-order  a.datagrid-order-control-asc',
    th_title_en_a_desc: CSSGRIDS[:th_title_en]+' div.datagrid-order  a.datagrid-order-control-desc',
  })

  # XPATH for Grids
  #
  # @note You may precede it with "/" (!!)
  XPATHGRIDS = {
    form: "/form[contains(@class, 'datagrid-form')]",  # used to be form#new_artists_grid in DataGrid Ver.1
    table: "/table[contains(@class, 'datagrid-table')]",  # used to contain 'table.artists_grid' in DataGrid Ver.1
  }.with_indifferent_access
  XPATHGRIDS.merge!({
    th_tr: XPATHGRIDS[:table]+'//thead//tr',
    tb_tr: XPATHGRIDS[:table]+'//tbody//tr',
  })
  XPATHGRIDS.merge!({
    td_title: XPATHGRIDS[:tb_tr]+"//td[@data-column='title']",  # for Harami1129
  })

  # @example
  #   css_grid_input_range(Artist, "birth_year", fromto: :to)
  #
  # @param fromto: [Symbol] either :from or :to
  # @return [String] CSS for :from or :to for Grid.
  def css_grid_input_range(model, kwd, fromto: )
    model_pl = plural_underscore(model)  # defined in application_helper.rb

    from_to =
      case fromto.to_s
      when "from", "to"
        fromto.to_s
      else
        raise "Wrong argument (#{fromto.inspect}) - either :from or :to"
      end

    sprintf 'input[name="%s_grid[%s][%s]"]', model_pl, kwd, from_to
  end

  # Reverse of get_bool_from_params in Application.helper
  #
  # The input should be String.
  #
  # @param prmval [String, NilClass] params['is_ok']
  # @return [Boolean, NilClass]
  def get_params_from_bool(val)
    return "" if val.nil?
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
         when nil, true, false
           get_params_from_bool(ev)
         else
           ev.to_s
         end
        ]
      end
    }.compact.to_h
    hsout.merge ardts.inject({}, &:merge)
  end

  # Read the display_name of the current_user from HTML and returns it.
  #
  # @example
  #    assert_nil current_user_display_name(is_system_test: false)  # defined in test_helper.rb
  #    assert_equal(@moderator_all.display_name, current_user_display_name)  # defined in test_helper.rb
  #
  # @return [String, NilClass] nil if no user is logged is.
  def current_user_display_name(is_system_test: true)
    method = (is_system_test ? Proc.new{|*args, **kwds| page.find(*args)} : Proc.new{|*args, **kwds| css_select(*args, **kwds)})
    begin
      pag = method.call('div#navbar_top span.navbar_top_display_name')
    rescue Capybara::ElementNotFound
      return nil
    end
    pag.blank? ? nil : pag.text  # for css_select (in Controller tests), pag.first.text is more strict.
  end

  # Validate if Flash message matches the given Regexp (called from Controller tests)
  #
  # Search is based on CSS classes.
  #
  # See {ApplicationController::FLASH_CSS_CLASSES} for CSS classes in this app.
  #
  # *Tip*: If the type is in suspect, pass nil to type (Default).
  #
  # == Debugging
  #
  # You may add +follow_redirect!+ before calling this in some cases.
  # For debugging, insert the following statemets (refer to #{css_for_flash})
  #   print "DEBUG:for-flash1: #{css_select('div#error_explanation').to_html}\n"
  #   print "DEBUG:for-flash2: #{css_select('p.alert').to_html}\n"
  #
  # @param regex [Regexp] 
  # @param msg [String] 
  # @param type: [Symbol, Array<Symbol>, NilClass] :notice, :alert, :warning, :success or their array.
  #    If nil, everything defined in {ApplicationController::FLASH_CSS_CLASSES}
  #    Note that the actual CSS is "alert-danger" (Bootstrap) for :alert, etc.
  # @param with_html: [Boolean] if true (Def: false), HTML (as opposed to a plain text) is evaluated with regex.
  # @param kwds: [Hash] Optional hash to be passed to {#css_for_flash}, notably +extra+
  def flash_regex_assert(regex, msg=nil, type: nil, with_html: false, **kwds)
    caller_info = _get_caller_info_message(bind_offset: 0)
    #bind = caller_locations(1,1)[0]  # Ruby 2.0+
    #caller_info = sprintf "%s:%d", bind.absolute_path.sub(%r@.*(/test/)@, '\1'), bind.lineno
    ## NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"

    csstext = css_select(css_for_flash(type, **kwds)).send(with_html ? :inner_html : :text)
    msg2pass = (msg || sprintf("Fails in flash(%s)-message regexp matching for: ", (type || "ALL")))+csstext.inspect
    assert_match(regex, csstext, "(#{caller_info}): "+msg2pass)
  end

  # Returns the CSS string to extract the flash messages.
  #
  # @example
  #    css_for_flash(:notice, category: :error_explanation)
  #      # => "div#body_main div.alert.alert-info.notice"
  #    css_for_flash(:warning, category: :both, extra: "a em")
  #      # => "div#body_main div.alert.alert-warning a em, div#body_main div#error_explanation.alert.alert-warning a em"
  #    css_for_flash([:alert, :success], category: :div, extra_attributes: ["cls1", "cls2"])
  #      # => "div#body_main div.alert.alert-danger.cls1.cls2, div#body_main div.alert.alert-success.cls1.cls2"
  #
  # @param type: [Symbol, Array<Symbol>, NilClass] :notice, :alert, :warning, :success or their array.
  #    If nil, everything defined in {ApplicationController::FLASH_CSS_CLASSES}
  #    Note that the actual CSS is "alert-danger" (Bootstrap) for :alert, etc.
  # @param category: [Symbol] :both, :error_explanation (for save/update), :div (normal flash)
  # @param extra: [String, NilClass] Extra CSS following the returned CSS-selector (placed after a space!)
  # @param extra_attributes: [String, Array, NilClass] Extra CSS classes (attributes) to append the last element in the returned CSS-selector (placed without a space)
  #   This is useful to further edit the returned CSS in case there are more than one "OR" condition.
  # @return [String] CSS for Flash-message part; e.g., ".alert, div#error_explanation"
  def css_for_flash(type=nil, category: :both, extra: nil, extra_attributes: nil, return_array: false)
    caller_info = _get_caller_info_message(bind_offset: 0)
    #bind = caller_locations(1,1)[0]  # Ruby 2.0+
    #caller_info = sprintf "%s:%d", bind.absolute_path.sub(%r@.*(/test/)@, '\1'), bind.lineno
    ## NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"

    extra_attributes =
      if extra_attributes.blank?
        []
      else
        [extra_attributes].flatten 
      end

    all_flash_types = ApplicationController::FLASH_CSS_CLASSES.keys.map(&:to_s) # String
    types = type && (type.respond_to?(:flatten) ? type.map(&:to_s) : [type.to_s]) || all_flash_types
    if types.any?{|i| !ApplicationController::FLASH_CSS_CLASSES.keys.include?(i)}
      raise "(#{caller_info}) (#{__FILE__}) Flash type (#{types.inspect}) must be included in ApplicationController::FLASH_CSS_CLASSES="+ApplicationController::FLASH_CSS_CLASSES.keys.map(&:to_sym).inspect
    end

    categories = 
      case category.to_sym
      when :both
        ["div", "div#error_explanation"]
      when :error_explanation
        ["div#error_explanation", "div.error_explanation"]  # the latter is needed when called from turbo.
      else
        ["div"]
      end

    categories.map{|ea_cat|
      types.map{|i| "div#body_main "+ea_cat+"."+(ApplicationController::FLASH_CSS_CLASSES[i].strip.split+extra_attributes).join(".")+(extra.present? ? " "+extra : "")}.join(", ")  # "div#body_main p.alert.alert-danger, div#body_main p.alert.alert-warning" etc
    }.join(", ")
  end

  # Returns the XPATH string to extract the flash messages.
  #
  # @example
  #    xpath_for_flash(:notice, category: :error_explanation)
  #      # => "div#body_main div.alert.alert-info.notice"
  #    css_for_flash(:warning, category: :both, extra: "a em")
  #      # => "div#body_main div.alert.alert-warning a em, div#body_main div#error_explanation.alert.alert-warning a em"
  #    css_for_flash([:alert, :success], category: :div, extra_attributes: ["cls1", "cls2"])
  #      # => "div#body_main div.alert.alert-danger.cls1.cls2, div#body_main div.alert.alert-success.cls1.cls2"
  #
  # @param type: [Symbol, Array<Symbol>, NilClass] :notice, :alert, :warning, :success or their array.
  #    If nil, everything defined in {ApplicationController::FLASH_CSS_CLASSES}
  #    Note that the actual CSS is "alert-danger" (Bootstrap) for :alert, etc.
  # @param category: [Symbol] :both, :error_explanation (for save/update), :div (normal flash)
  # @param extras: [Array<String>, NilClass] Extra tags following the returned CSS-selector (placed after a space!)
  # @param extra_attributes: [String, Array, NilClass] Extra CSS classes (attributes) to append the last element in the returned CSS-selector (placed without a space)
  #   This is useful to further edit the returned CSS in case there are more than one "OR" condition.
  # @return [String] CSS for Flash-message part; e.g., ".alert, div#error_explanation"
  def xpath_for_flash(type=nil, category: :both, extras: nil, extra_attributes: nil, return_array: false)
    caller_info = _get_caller_info_message(bind_offset: 0)
    #bind = caller_locations(1,1)[0]  # Ruby 2.0+
    #caller_info = sprintf "%s:%d", bind.absolute_path.sub(%r@.*(/test/)@, '\1'), bind.lineno
    ## NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"

    extras = [] if extras.blank?

    extra_attributes =
      if extra_attributes.blank?
        []
      else
        [extra_attributes].flatten 
      end

    all_flash_types = ApplicationController::FLASH_CSS_CLASSES.keys.map(&:to_s) # String
    types = type && (type.respond_to?(:flatten) ? type.map(&:to_s) : [type.to_s]) || all_flash_types
    if types.any?{|i| !ApplicationController::FLASH_CSS_CLASSES.keys.include?(i)}
      raise "(#{caller_info}) (#{__FILE__}) Flash type (#{types.inspect}) must be included in ApplicationController::FLASH_CSS_CLASSES="+ApplicationController::FLASH_CSS_CLASSES.keys.map(&:to_sym).inspect
    end

    category_tag = "div"
    categories = 
      case category.to_sym
      when :both
        ["div", "div[@id='error_explanation']"]
      when :error_explanation
        [       "div[@id='error_explanation']"]
      else
        ["div"]
      end

    categories.map{|ea_cat|
      css_klasses = types.map{|i|
        str0 = (ApplicationController::FLASH_CSS_CLASSES[i].strip.split + extra_attributes).map{|ea_klass|
          sprintf("[contains(@class, '%s')]", ea_klass)
        }.join("")
        ([str0] + extras).join("//")
      }
      css_klasses.map{|ea_xpk|
        sprintf("//div[@id='body_main']/%s%s[1]", ea_cat, ea_xpk)  # the flash part should appear immediately after div#body_main
      } 
    }.flatten.join("|")
  end

  # Asserts in a Conroller test no presence of alert on the page and prints the alert in failing it
  #
  # This tests both a flash and screen. In some cases, the previous flash remains
  # in testing.  In such case, specify +screen_test_only: true+
  def my_assert_no_alert_issued(screen_test_only: false)
    caller_info = _get_caller_info_message(bind_offset: 0)
    #bind = caller_locations(1,1)[0]  # Ruby 2.0+
    #caller_info = sprintf "%s:%d", bind.absolute_path.sub(%r@.*(/test/)@, '\1'), bind.lineno
    ## NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"

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
    caller_info = _get_caller_info_message(bind_offset: bind_offset)
    #bind = caller_locations(1+bind_offset, 1)[0]  # Ruby 2.0+
    #caller_info = sprintf "%s:%d", bind.absolute_path.sub(%r@.*(/test/)@, '\1'), bind.lineno
    ## NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"

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
    caller_info = _get_caller_info_message(bind_offset: bind_offset)
    #bind = caller_locations(1+bind_offset, 1)[0]  # Ruby 2.0+
    #caller_info = sprintf "%s:%d", bind.absolute_path.sub(%r@.*(/test/)@, '\1'), bind.lineno
    ## NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"

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
  # @param model [ActiveRecord]
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


  # collecgion of basic model-testings of weight like a negative value.
  #
  # At return, the status of the model unchanges from what was passed.
  #
  # @example
  #     user_assert_model_weight(model, allow_nil: true)  # defined in test_helper.rb
  #
  # @param model [ActiveRecord] should be valid
  # @param allow_nil: [Boolean] 
  def user_assert_model_weight(model, allow_nil: true)  # allow_duplication??
    caller_info_prefix = sprintf("(%s):", _get_caller_info_message(bind_offset: 0))  # defined in test_helper.rb
    assert model.valid?, "#{caller_info_prefix} The passed Model has to be valid, but... Errors=#{model.valid?; model.errors.inspect} Model=#{model.inspect}"

    backup_weight = model.weight
    begin
      model.weight = nil
      if allow_nil
        assert_nil model.weight, "#{caller_info_prefix} nil weight should be allowed, but..." 
      else
        refute_nil model.weight, "#{caller_info_prefix} nil weight should be prohibited, but..."
      end
      model.weight = "nai-weight"
      refute model.valid?, "#{caller_info_prefix} Non-numeric-type weight should not be allowed, but..."
      model.weight = -3
      refute model.valid?, "#{caller_info_prefix} Negative weight should not be allowed, but..."
      model.weight = 4
      assert model.valid?, "#{caller_info_prefix} Sanity check-1 failed."
    ensure
      model.weight = backup_weight
      assert model.valid?, "#{caller_info_prefix} Sanity check-2 failed."
    end
  end


  # Returns the String for the caller information
  #
  # @example
  #    assert abc, sprintf("(%s): abc=%s", _get_caller_info_message(bind_offset: 0), abc.inspect)  # defined in test_helper.rb
  #
  # @example displays the exact line where an error occurs
  #    assert false, _get_caller_info_message(bind_offset: -1, prefix: true)+" Something went wrong."
  #
  # @param bind_offset: [Integer] offset for caller_locations (used for displaying the caller routine). Default (=0) assumes this method is called in a test library method that is called from an original test routine. Therefore, specify "-1" to get the information of the caller itself (Second example above).
  # @param fmt: [String] sprintf format. It must contain %s (for path) and %d (or %s) (for line number) in this order.
  # @param prefix: [Boolean] If true (Def: false), the return is enclosed with a pair of parentheses, followed by a colon
  # @return [String]
  def _get_caller_info_message(bind_offset: 0, fmt: "%s:%d", prefix: false)
    bind = caller_locations(1+BASE_CALLER_INFO_BIND_OFFSET+bind_offset, 1)[0]  # Ruby 2.0+

    # NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"
    ret = sprintf fmt, bind.absolute_path.sub(%r@.*(/test/)@, '\1'), bind.lineno
    (prefix ? sprintf("(%s):", ret) : ret)
  end
  private :_get_caller_info_message

  # Internal common routine.
  #
  # @param model [ActiveRecord]
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
  #
  # @example
  #   fill_autocomplete('Title', with: 'Madon', select: "Madonna")  # defined in test_helper.rb
  #   fill_autocomplete('#musics_grid_title_ja', use_find: true, with: 'Peace a', select: "Give Peace")  # defined in test_helper.rb
  #
  # @param field [String] either Text or CSS
  # @param use_find: [Boolean] if true (Def: false), page.find(field) is used to fill in.
  def fill_autocomplete(field, use_find: false, **options)
    if use_find
      page.find(field).fill_in(with: options[:with])
      prefix = ""
    else
      fill_in field, with: options[:with]
      prefix = "#"
    end

    page.execute_script %Q{ $('#{prefix+field}').trigger('focus') }
    page.execute_script %Q{ $('#{prefix+field}').trigger('keydown') }

    selector = %Q{ul.ui-autocomplete li.ui-menu-item:contains("#{options[:select]}")}  # has to be double quotations (b/c of the sentence below)
    ## Or, more strictly,
    #selector = %Q{ul.ui-autocomplete li.ui-menu-item div.ui-menu-item-wrapper:contains("#{options[:select]}")}  # has to be double quotations (b/c of the sentence below)

    caller_info = _get_caller_info_message(bind_offset: bind_offset)
    #bind = caller_locations(1,1)[0]  # Ruby 2.0+
    #caller_info = sprintf "%s:%d", bind.absolute_path.sub(%r@.*(/test/)@, '\1'), bind.lineno
    ## NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"

    # page.should have_selector selector  # I think this is for RSpec only. # This ensures to wait for the popup to appear.
    #print "DEBUG: "; p page.find('ul.ui-autocomplete div.ui-menu-item-wrapper')['innerHTML']
    ## assert page.has_selector? selector  # Does not work (maybe b/c it is valid only for jQuery; officially CSS does not support "contains" selector, which is deprecated): Selenium::WebDriver::Error::InvalidSelectorError: invalid selector: An invalid or illegal selector was specified
    begin
      assert_selector selector.sub(/:contains.*/, ''), wait: 3  # This MAY ensure to wait for the popup to appear??
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

  # Get Integer PID from Show page in Model.
  #
  # @return [Integer]
  def retrieve_pid_in_show
    pid_str =
      if defined?(page) && page.respond_to?(:find)
        page.find(PAGECSS[:show][:pid]).text
      else
        raise "unsupported"
      end
    pid_str.to_i
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
