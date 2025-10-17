# coding: utf-8
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require "test_model_helper"
require "test_controller_helper"
require "test_system_helper"
# require "controller_anchorable_helper.rb"  # required in each test file that requires this.
require_relative './test_w3c_validate_helper'


# require(Rails.root.to_s+"/db/seeds/common.rb")  # This is implicitly invoked below.
Dir[Rails.root.to_s+"/db/seeds/*.rb"].uniq.each do |seed|
  next if /^seeds_/ =~ File.basename(seed)  # Skipping reading the old-style Modules
  require seed
end
require Rails.root.to_s+"/db/seeds/event_groups" # EventGroup

ActiveRecord::FixtureSet.context_class.include Seeds

class ActiveSupport::TestCase
  include ApplicationHelper
  include TestW3cValidateHelper

  # Add more helper methods to be used by all tests here...
  include Devise::Test::IntegrationHelpers
  include Warden::Test::Helpers

  ### Index
  # Ruby related
  # Bind/Caller related
  # Model-test related
  # Harami1129 related
  # Routes related
  # User related
  # Controller-test/params related
  # System-test related (auto-complete)
  # HTML/XPath/URL/scraping related
  # Gem related

  DEF_RELPATH_HARAMI1129_LOCALTEST = 'test/controllers/harami1129s/data/harami1129_sample.html'

  # Default value for bind_offset in {#_get_caller_info_message}
  DEF_CALLER_INFO_BIND_OFFSET = nil

  # Used in the method {#_get_caller_info_message}. 0 means the caller (of the method) itself. 1 means its parent.
  BASE_CALLER_INFO_BIND_OFFSET = 1

  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Disable routing-filter in testing
  RoutingFilter.active = false

  # CSS for pages
  PAGECSS = {
    # new_trans_lang_radios: 'form div.field.radio_langcode',  # eg: page.find(PAGECSS[:new_trans_lang_radios]).choose('English')  # if NOT simple_form
    new_trans_lang_radios: 'form.simple_form fieldset.radio_buttons.choose_langcode',  # for simple_form
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
    pagenation_stats: "/*[#{ModuleCommon.xpath_contain_css(ApplicationGrid::CSS_CLASSES[:pagenation_stats])}]",  # unique to this app as defined in app/views/layouts/_grid_table_tail.html.erb
  }.with_indifferent_access
  XPATHGRIDS.merge!({
    th_tr: XPATHGRIDS[:table]+'//thead//tr',
    tb_tr: XPATHGRIDS[:table]+'//tbody//tr',
  })
  XPATHGRIDS.merge!({
    td_title: XPATHGRIDS[:tb_tr]+"//td[@data-column='title']",  # for Harami1129
  })

  # XPATH-related parameters
  #
  # fmt is for sprintf
  XPATHS = {
    anchoring: {
      section_fmt: "//*[@id='anchoring_index_%s']",  # for sprintf, where %s is like HaramiVid
      list: (anchoring_list="//"+ModuleCommon.xpath_contain_css("anchoring_list", complete_for: "ul")),  # more accurately, preceded with sprintf(XPATHS[:anchoring][:section_fmt], MyModel.name)
      item: (anchoring_item=anchoring_list+"//li"),  # more accurately, preceded with sprintf(XPATHS[:anchoring][:section_fmt], MyModel.name)
      new_link:     "//a[@data-turbo-frame='new_anchoring'][contains(.,'New Anchoring')]",  # more accurately, preceded with sprintf(XPATHS[:anchoring][:section_fmt], MyModel.name)
      edit_button:  anchoring_item+"//button[contains(@type, 'submit')][contains(.,'Edit')]",
      destroy_link: anchoring_item+"//a[@data-turbo-method='delete'][contains(.,'Destroy')]",
      form_new:   (anchoring_form_new="//form[@id='new_anchoring']"),  # more accurately, preceded with sprintf(XPATHS[:anchoring][:section_fmt], MyModel.name)
      form_edit: (anchoring_form_edit=anchoring_list+"//form[" + ModuleCommon.xpath_contain_css('edit_anchoring') + "]"),
    },
    form: {
      fmt_button_submit:      "//form[contains(@class, 'button_to')]//button[@type='submit'][contains(text(), '%s')]", # 1 parameter: Label like "Destroy" for a button compiled by button_to (Rails-7.2)
      fmt_any_button_submit: "//form//button[@type='submit'][contains(text(), '%s')]", # 1 parameter: Label like "Destroy" (Rails-7.2)
    }.with_indifferent_access,
    all_translation_table: { # table ID is like "#all_registered_translations_music"
      buton_add_trans:    "//table[contains(@class, 'all_registered_translations')]//tr[contains(@class, 'lang_banner')]//form[contains(@class, 'button_to')]//button[@type='submit'][contains(text(), '%s')]", # 1 parameter (hence containing multiple components): Label ('Add translation') (Rails-7.2)
      buton_add_trans_lc: "//table[contains(@class, 'all_registered_translations')]//tr[contains(@class, 'lang_banner_%s')]//form[contains(@class, 'button_to')]//button[@type='submit'][contains(text(), '%s')]", # 2 parameters: locale, Label ('Add translation') (Rails-7.2)
    }.with_indifferent_access,
  }.with_indifferent_access

  ################################################################
  # Ruby related
  ################################################################

  # Suppresses STDERR temporarily
  #
  # @see ModuleCommon#silence_streams
  #
  # @return [String] STDERR
  # @yield Inside the given block, STDERR is suppressed
  def with_captured_stderr
    syncval = $stderr.sync
    begin
      $stderr.sync = true
      original_stderr = $stderr
      $stderr = StringIO.new
      yield
      $stderr.string
    ensure
      $stderr = original_stderr  # restore $stderr to its previous value
      $stderr.sync = syncval
    end
  end

  # Suppresses STDOUT temporarily
  #
  # @see ModuleCommon#silence_streams
  #
  # @return [String] STDOUT
  # @yield Inside the given block, STDOUT is suppressed
  def with_captured_stdout
    syncval = $stdout.sync
    begin
      $stdout.sync = true
      original_stdout = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = original_stdout  # restore $stdout to its previous value
      $stdout.sync = syncval
    end
  end

  ################################################################
  # Bind/Caller related
  ################################################################

  # Returns the String for the caller information
  #
  # @example To display the location of the last caller in the *_test.rb file.
  #    assert abc, sprintf("(%s): abc=%s", _get_caller_info_message, abc.inspect)  # defined in test_helper.rb
  #
  # @example displays the exact line where an error occurs
  #    assert false, _get_caller_info_message(bind_offset: -1, prefix: true)+" Error occurs exactly at this line."
  #
  # @param bind_offset: [Integer, NilClass] offset for caller_locations (used for displaying the caller routine). In default (=nil), the last location in *_test.rb (such as, inside a block). If this is 0, it is useful in the case where this method is called in a test library method that is called from an original test routine. Therefore, specify "-1" to get the information of the caller itself (Second example above).
  # @param fmt: [String] sprintf format. It must contain %s (for path) and %d (or %s) (for line number) in this order.
  # @param prefix: [Boolean] If true (Def: false), the return is enclosed with a pair of parentheses, followed by a colon
  # @return [String]
  def _get_caller_info_message(bind_offset: DEF_CALLER_INFO_BIND_OFFSET, fmt: "%s:%d", prefix: false)
    if !bind_offset
      bind = caller_locations.each{|i| break i if /_test\.rb$/ =~ i.absolute_path }
      if bind.respond_to? :absolute_path
        bind_offset = nil
      else
        bind = nil
        bind_offset = BASE_CALLER_INFO_BIND_OFFSET  # in failure (meaning when this method is NOT called from a Rails test file)
      end
    end

    bind ||= caller_locations(1+BASE_CALLER_INFO_BIND_OFFSET+bind_offset, 1)[0]  # Ruby 2.0+

    # NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"
    ret = sprintf fmt, bind.absolute_path.sub(%r@.*(/test/)@, '\1'), bind.lineno
    (prefix ? sprintf("(%s):", ret) : ret)
  end
  private :_get_caller_info_message

  ################################################################
  # Model-test related
  ################################################################

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

  # collection of basic model-testings of weight like a negative value.
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

  # assert if the instance is updated, checking updated_at
  #
  # @note model is reloaded!
  #
  # @param model [Model]
  # @param msg [String] message parameter for assert
  # @param inspect [Boolean] if true, the difference would be printed if failed.
  # @param refute [Boolean] if true (Def: false), returns true if NOT updated. cf. user_refute_updated_attr?
  # @param bind_offset [Integer, NilClass] offset for caller_locations (used for displaying the caller routine)
  def user_assert_updated?(model, msg=nil, inspect: true, refute: false, bind_offset: DEF_CALLER_INFO_BIND_OFFSET)
    caller_info = _get_caller_info_message(bind_offset: bind_offset)

    upd, msg2pass = _reload_and_get_message(model, msg, inspect, :updated_at, caller_info)
    if refute
      refute_operator upd, :<, model.updated_at, msg2pass
    else
      assert_operator upd, :<, model.updated_at, msg2pass
    end
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
  def user_assert_updated_attr?(model, attr, msg=nil, inspect: true, refute: false, bind_offset: DEF_CALLER_INFO_BIND_OFFSET)
    caller_info = _get_caller_info_message(bind_offset: bind_offset)

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
    user_assert_updated_attr?(model, attr, msg=nil, inspect: true, refute: true)
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
  end

  ################################################################
  # Harami1129 related
  ################################################################

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

  ################################################################
  # Routes related
  ################################################################

  # Wrapper of +Rails.application.routes.recognize_path+
  #
  # This app captures any path in routes; if it is not recognized by existing models,
  # it is paseed to {StaticPagePublicsController}. Therefore,
  #   Rails.application.routes.recognize_path("/non_existent")
  #      # => {controller: "static_page_publics", action: "show", path: "non_existent"}
  #
  # {StaticPagePublicsController#show} may raise ActionController::RoutingError,
  # just the same as +recognize_path()+ does when an invalid path is given.
  #
  # In Rails-7.1 and later, Exceptions are captured in test environments
  # with the default config parameter (usually defined in /config/environments/test.rb )
  #    Rails.application.config.action_dispatch.show_exceptions == :rescuable
  # In such a case, it is impossible to pin down which error was raised
  # after GET (or PATCH or whatever) in a test suite in Rails-7.1 because
  # it only sees the page of 404.
  #
  # This method behaves the same as +Rails.application.routes.recognize_path+
  # taking into account the algorithm of {StaticPagePublicsController}, i.e.,
  # if {StaticPagePublicsController} raises an Exception for the given path, this will. 
  #
  # @example
  #    recognize_path_with_static_page("/places")
  #      # => {controller: "places", action: "index"}
  #    recognize_path_with_static_page("/non_existent", method: "POST")
  #      # => ActionController::RoutingError
  #
  # @param path [String]
  # @param **kwds [Hash] "method:" etc
  # @return [Hash]
  # @raise ActionController::RoutingError
  def recognize_path_with_static_page(path, *arg, **kwds)
    hs = Rails.application.routes.recognize_path(path, *arg, **kwds)
    return hs if "static_page_publics" != hs[:controller]

    _ = StaticPagePublicsController.static_page_from_path(path)  # may raise ActionController::RoutingError
    ret
  end

  ################################################################
  # User related
  ################################################################

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


  ################################################################
  # Controller-test/params related
  ################################################################
  # performs log on and assertion to see if the HTTP response is :success
  #
  # This assumes that no one is logged on when called.
  # Also, the access by the non-authenticated user to the path is assumed to fail.
  #
  # WARNING: When returned, user_succeed is still logged on (unless it is specified nil)
  #
  # @example with path
  #   assert_controller_index_fail_succeed(translations_url, user_fail: users(:user_moderator), user_succeed: @translator)  # defined in test_helper.rb
  #   sign_out @translator
  #
  # @example with Class; checking :index
  #   assert_controller_index_fail_succeed(EngageHow, user_fail: nil, user_succeed: users(:user_moderator))  # defined in test_helper.rb
  #   sign_out users(:user_moderator)
  #
  # @example with Instance; checking :show
  #   assert_controller_index_fail_succeed(Country.unknown, user_fail: nil, user_succeed: nil)  # defined in test_helper.rb
  #
  # @param path2get [String, ActiveRecord, Class] Either the GET access path or Model class or instance
  # @param h1_title [String, NilClass] h1 title string for index page. If nil, it is guessed from the model, assuming the first argument is a model (NOT the path String)
  # @param user_fail: [User, Array<User>, NilClass] who fail(s) to see the index page. Even if nil, the non-authorized user is tested.
  # @param user_user_succeed: [User, NilClass] who succcessfully sees the index page
  def assert_controller_index_fail_succeed(path2get, user_fail: nil, user_succeed: nil)
    if path2get.respond_to?(:rewhere) || path2get.respond_to?(:destroy!)
      # gets the path of either :index or :show
      path2get = Rails.application.routes.url_helpers.polymorphic_path(path2get)
    end
    # h1_title ||= model.class.name.underscore.pluralize.split("_").map(&:capitalize).join(" ")  # e.g., "Event Items"

    # get '/users/sign_in'

    ## Failing in displaying index (although Login itself should succeed)
    fmt1 = "(%s): GET %s should be :redirect for User='%s', but... %s"
    fmt2 = "(%s): GET %s should be redirected to #{user_fail ? 'Root' : 'Login'}, but..."

    user_fails = (user_fail ? [user_fail].flatten.compact : [])
    user_fails = ([nil]+user_fails)

    user_fails.each do |user|
      username = (user ? user.display_name : "Unauthenticated")
      path_redirected = (user ? root_url : new_user_session_path)
      sign_in  user if user
      get path2get
      assert_response          :redirect,   sprintf(fmt1, _get_caller_info_message, path2get, username, response_status_text)  # defined in test_helper.rb
      assert_redirected_to path_redirected, sprintf(fmt2, _get_caller_info_message, path2get)  # defined in test_helper.rb
      sign_out user if user
    end

    return if !user_succeed

    ## Succeeding
    sign_in  user_succeed
    get path2get
    assert_response :success, sprintf("(%s): GET %s should succeed, but...", _get_caller_info_message, path2get, response_status_text)  # defined in test_helper.rb
  end # def assert_controller_index_fail_succeed(path2get, user_fail: nil, user_succeed: nil)


  # performs assertion of errors raised in a Controller
  #
  # This accomodates the varied Controller-test behaviour, which depends on the config setting of
  #   Rails.application.config.action_dispatch.show_exceptions
  # (usually defined in /config/environments/test.rb )
  # In default, it is false before Rails-7.1 (later replaced with :none) and :rescuable in Rails-7.1 or later.
  #
  # @example
  #   assert_controller_dispatch_exception(path, err_class: ActionController::RoutingError)  # defined in test_helper.rb
  #
  # @example
  #   assert_controller_dispatch_exception(path, err_class: ActionController::ParameterMissing, method: :post, hsparams: { engage_how: { note: @engage_how.note } })  # defined in test_helper.rb
  #
  # @example
  #   assert_controller_dispatch_exception(path, err_class: ActionController::ParameterMissing, method: :patch)  # defined in test_helper.rb
  #
  # @example This always fails
  #   assert_controller_dispatch_exception("/")
  #
  # @param path [String] to test
  # @param err_class: [Exception] exception that should be raised
  # @param method: [Symbol, String] :get, :patch, etc
  # @return [void]
  def assert_controller_dispatch_exception(path, err_class: ActionController::RoutingError, method: :get, hsparams: nil)
    fmt = "(%s): "+sprintf("%s %s should fail ", method.to_s.upcase, path).gsub(/%/, "%%") + "%s #{err_class.name}, but..."

    # For ActionController::RoutingError, it can be checked with a low-level method
    # regardless of Rails-7.0/7.1.  For ActiveRecord::RecordNotFound, a low-level examination
    # is trickier, and the exception is not supported, yet.
    if err_class == ActionController::RoutingError
      assert_raises(err_class, sprintf(fmt, _get_caller_info_message, "by")){
        recognize_path_with_static_page(path, method: method) }  # defined in test_helper.rb
    end

    case Rails.application.config.action_dispatch.show_exceptions
    when :rescuable  # Default in Rails-7.1.  err_class is irrelevant so far...
      exp_resp =
        case err_class.to_s  # case uses "===" to compare. So, "==" comparison with Class does not work, hence to_i (!!)
        when "ActionController::RoutingError", "ActiveRecord::RecordNotFound"
          :missing   # :not_found 404
        when "ActionController::ParameterMissing"
          :bad_request
        else
          :error  # may not work...
        end

      send(method, path, params: hsparams)
      response_text = sprintf(" <%s: %s>", response.status, Rack::Utils::HTTP_STATUS_CODES[response.status])
#assert_response :missing
      assert_response exp_resp, sprintf(fmt, _get_caller_info_message, "deu to")+response_text
        # => (/test/controllers/abc_controller_test.rb:123): GET /naiyo should fail due to ActionController::RoutingError, but... <404: Not Found>
    when nil, false, :none  # false used to be default before Rails-7.1
      assert_raises(err_class, sprintf(fmt, _get_caller_info_message, "with")){ send(method, path, params: hsparams) }  # defined in test_helper.rb
        # => (/test/controllers/abc_controller_test.rb:123): GET /naiyo should fail with ActionController::RoutingError, but...
    else
      ## I don't know...
    end
  end # assert_controller_dispatch_exception()


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
  # You may add
  #   follow_redirect!
  # before calling this in some cases.
  # For debugging, insert one of the following statemets (refer to #{css_for_flash})
  #   print "DEBUG:for-flash0: #{css_select(css_for_flash).to_s}\n"
  #   print "DEBUG:for-flash1: #{css_select('div#error_explanation').to_html}\n"
  #   print "DEBUG:for-flash2: #{css_select('p.alert').to_html}\n"
  #
  # @param regex [Regexp] 
  # @param msg [String] 
  # @param type: [Symbol, Array<Symbol>, NilClass] :notice, :alert, :warning, :success or their array.
  #    If nil, everything defined in {ApplicationController::FLASH_CSS_CLASSES}
  #    Note that the actual CSS is "alert-danger" (Bootstrap) for :alert, etc.
  # @param with_html: [Boolean] if true (Def: false), HTML (as opposed to a plain text) is evaluated with regex.
  # @param is_debug: [Boolean] if true (Def: false), prints the CSS selector information
  # @param kwds: [Hash] Optional hash to be passed to {#css_for_flash}, notably +category+ and +extra+
  def flash_regex_assert(regex, msg=nil, type: nil, with_html: false, is_debug: false, **kwds)
    caller_info = _get_caller_info_message(bind_offset: 0)

    printf "DEBUG(#{__method__}): css_for_flash(ARG=#{[type, kwds].inspect})=( %s )\n", css_for_flash(type, **kwds) if is_debug
    csstext = css_select(css_for_flash(type, **kwds)).send(with_html ? :inner_html : :text)
    msg2pass = (msg || sprintf("Fails in flash(%s)-message regexp matching for: ", (type || "ALL")))+csstext.inspect
    assert_match(regex, csstext, "(#{caller_info}): "+msg2pass)
  end

  # Reverse of get_bool_from_params in Application.helper
  #
  # The input should be String.
  #
  # My reverse method +convert_param_bool+ defined in application_controller.rb
  # works in the opposite way in default...  So, you may calle it, explicitly specifying +true_int+ optional parameter like:
  #
  #    convert_param_bool(params[:models][my_param], true_int: 1)
  #
  # @param prmval [String, NilClass] params['is_ok']
  # @return [Boolean, NilClass]
  def get_params_from_bool(val)
    return "" if val.nil?
    val ? "1" : "0"
  end

  # Status of a Checkbox (boolean)
  #
  # It is tricky because
  #
  # * If checked, "checked=checked" is the case, though its values can vary in practice (officially "checked" or an empty String. The value attribute may be "1".
  # * If unchecked, "checked" attribute should be absent. The value attribute may still be "1"(!); it may be "0" but no guarantee!
  #
  # @example
  #    is_checkbox_checked?(css_select("#anchoring_fetch_h1")[0])  #=> true/false
  #    is_checkbox_checked?(".anchoring_fetch_h1", -1)             #=> true/false (last-matching)
  #
  # @param css [HtmlTag]
  # @param index [Integer, NilClass]  If css is the CSS String, this is mandatory.
  def is_checkbox_checked?(css, index=nil)
    checkbox = (css.respond_to?(:attributes) ? css : css_select(css, index))
    raise "CSS-Node looks wrong: #{[css, checkbox].inspect}" if !checkbox
    checkbox['checked'].present?
  end

  # Asserts in a Conroller test no presence of alert on the page and prints the alert in failing it
  #
  # This tests both a flash and screen. In some cases, the previous flash remains
  # in testing.  In such case, specify +screen_test_only: true+
  def my_assert_no_alert_issued(screen_test_only: false)
    caller_info = _get_caller_info_message(bind_offset: 0)

    assert  flash[:alert].blank?, "Failed(#{caller_info}) with Flash-alert: "+(flash[:alert] || "") if !screen_test_only
    msg_alert = css_select(".alert").text.strip
    assert_empty msg_alert, "(#{caller_info}):Alert: #{msg_alert}"
  end


  # This is usually called by a Controller test after GET/PATCH etc.
  #
  # @return [String] e.g., "<404: Not Found>"
  def response_status_text(status_code=response.status)
    sprintf(" <%s: %s>", status_code, Rack::Utils::HTTP_STATUS_CODES[status_code])
  end

  ################################################################
  # System-test related (auto-complete)
  ################################################################

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

    caller_info = _get_caller_info_message()
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


  ################################################################
  # HTML/XPath/URL/scraping related
  ################################################################

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
  # @example printing the flash/error message in Controller tests
  #    puts css_select(css_for_flash).to_s
  #
  # @param type: [Symbol, Array<Symbol>, NilClass] :notice, :alert, :warning, :success or their array.
  #    If nil, everything defined in {ApplicationController::FLASH_CSS_CLASSES}
  #    Note that the actual CSS is "alert-danger" (Bootstrap) for :alert, etc.
  # @param category: [Symbol] :all (:both), :error_explanation (for save/update), :form (simple_form), :div (normal flash)
  # @param extra: [String, NilClass] Extra CSS following the returned CSS-selector (placed after a space!)
  # @param extra_attributes: [String, Array, NilClass] Extra CSS classes (attributes) to append the last element in the returned CSS-selector (placed without a space)
  #   This is useful to further edit the returned CSS in case there are more than one "OR" condition.
  # @return [String] CSS for Flash-message part; e.g., ".alert, div#error_explanation"
  def css_for_flash(type=nil, category: :all, extra: nil, extra_attributes: nil, return_array: false)
    caller_info = _get_caller_info_message(bind_offset: 0)

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

    cat4form="div.invalid-feedback"
    categories = 
      case category.to_sym
      when :all, :both
        ["div", "div#error_explanation"]
      when :error_explanation
        ["div#error_explanation", "div.error_explanation"]  # the latter is needed when called from turbo.
      when :form  # simple_form / displayed under each field
        [cat4form]
      else
        ["div"]
      end
    return cat4form if :form == category.to_sym
    ar0 = ([:all, :both].include?(category.to_sym) ? [cat4form] : [])
    ## NOTE: The SimpleForm CSS for error message does not include anything like "alert". So a separate handling is required... Needs refactoring. TODO.

    (ar0 + categories.map{|ea_cat|
      types.map{|i| "div#body_main "+ea_cat+"."+(ApplicationController::FLASH_CSS_CLASSES[i].strip.split+extra_attributes).join(".")+(extra.present? ? " "+extra : "")}.join(", ")  # "div#body_main p.alert.alert-danger, div#body_main p.alert.alert-warning" etc
    }).compact.join(", ")
  end

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


  # Returns the XPATH string to extract the flash messages.
  #
  # @example  (I am not sure if these actually work...)
  #    xpath_for_flash(:notice, category: :error_explanation)
  #      # => "//div[@id='body_main']/div[@id='error_explanation'][contains(@class, 'notice')][contains(@class, 'alert')][contains(@class, 'alert-info')][1]"
  #    xpath_for_flash(:warning, category: :both, extras: %w(a em))  # NOTE: extras is an Array!
  #      # => "//div[@id='body_main']/div[contains(@class, 'alert')][contains(@class, 'alert-warning')]//a//em[1]|//div[@id='body_main']/div[@id='error_explanation'][contains(@class, 'alert')][contains(@class, 'alert-warning')]//a//em[1]"
  #    xpath_for_flash([:alert, :success], category: :div, extra_attributes: ["cls1", "cls2"])
  #      # => "//div[@id='body_main']/div[contains(@class, 'alert')][contains(@class, 'alert-danger')][contains(@class, 'cls1')][contains(@class, 'cls2')][1]|//div[@id='body_main']/div[contains(@class, 'alert')][contains(@class, 'alert-success')][contains(@class, 'cls1')][contains(@class, 'cls2')][1]"
  #
  # @example  Flash for Error for Turbo
  #    xpath_for_flash(:alert, category: :div, xpath_head: "//form[@id='form_new_anchoring']//")  # defined in test_helper.rb
  #      # => "//form[@id='form_new_anchoring']//div[contains(@class, 'alert')][contains(@class, 'alert-danger')]"
  #
  # @note
  #   Because of potential "OR" conditions, you should not prepend the returned String
  #   with another XPath, but explicitly specify +xpath_head+ (which should usually include
  #   a single trailing forward slash; see below)
  #
  # @param type: [Symbol, Array<Symbol>, NilClass] :notice, :alert, :warning, :success or their array.
  #    If nil, everything defined in {ApplicationController::FLASH_CSS_CLASSES}
  #    Note that the actual CSS is "alert-danger" (Bootstrap) for :alert, etc.
  # @param category: [Symbol] :both, :error_explanation (for save/update), :div (normal flash)
  # @param extras: [Array<String>, NilClass] Extra tags following the returned CSS-selector (placed after a space!)
  # @param extra_attributes: [String, Array, NilClass] Extra CSS classes (attributes) to append the last element in the returned CSS-selector (placed without a space)
  #   This is useful to further edit the returned CSS in case there are more than one "OR" condition.
  # @param xpath_head: [String] XPath to begin with. Should be prefixed with +//+. Also, This should
  #   usually include a *single* trailing forward slash UNLESS this XPath *must* come immediately before
  #   the XPath for the flash messages, in which case *no trailing slash* should be put on this.
  #   The default is "//div[@id='body_main']", meaning the flash part should appear immediately after div#body_main
  # @return [String] CSS for Flash-message part; e.g., ".alert, div#error_explanation"
  def xpath_for_flash(type=nil, category: :both, extras: nil, extra_attributes: nil, return_array: false, xpath_head: "//div[@id='body_main']/")
    caller_info = _get_caller_info_message(bind_offset: 0)

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
        [category_tag, category_tag+"[@id='error_explanation']"]
      when :error_explanation
        [              category_tag+"[@id='error_explanation']"]
      else
        [category_tag]
      end

    categories.map{|ea_cat|
      css_klasses = types.map{|i|
        str0 = (ApplicationController::FLASH_CSS_CLASSES[i].strip.split + extra_attributes).map{|ea_klass|
          sprintf("[contains(@class, '%s')]", ea_klass)
        }.join("")
        ([str0] + extras).join("//")
      }
      css_klasses.map{|ea_xpk|
        sprintf(xpath_head+"%s%s[1]", ea_cat, ea_xpk)
      }
    }.flatten.join("|")
  end # def xpath_for_flash()


  # XPath to match certain statistics on the Grid-index-view statistics line
  #
  # @see ApplicationController.str_info_entry_page_numbers_core
  #
  # @example In system tests, the following three are in practice equivalent (if in English environment)
  #   assert_text 'Page 1 (1—3)/3'  # Page 1 (1—3)/3 [Grand total: 12]
  #   assert_text             xpath_grid_pagenation_stats_with(n_filtered_entries: 3, text_only: true)
  #   assert_selector :xpath, xpath_grid_pagenation_stats_with(n_filtered_entries: 3, text_only: false)
  #   # Debug(to see the text in the block): p find(:xpath, XPATHGRIDS[:pagenation_stats]).text
  #
  # @example
  #   assert_text '第1頁 (1—3)/3 [全登録数: 99]'
  #   assert_selector :xpath, xpath_grid_pagenation_stats_with(n_filtered_entries: 3, n_all_entries: 99, locale: :ja)
  #   # Debug(to see the text in the block): p find(:xpath, XPATHGRIDS[:pagenation_stats])['innerHTML']
  #
  # @param n_filtered_entries: [Integer] mandatory: Number of the filtered entries
  # @param text_only: [Boolean] if true (Def: false), returns a simple text String; otherwise XPath
  # @param start_entry: [Integer, NilClass] Def: 1. If nil, this returns only "/123" (Number of the filtered entries)
  # @param end_entry: [Integer, NilClass] This is equal to, or (usually in tests) smaller than, the maximum number of entries per page on Grid. If nil (Def), the same as n_filtered_entries.
  # @param n_all_entries: [Integer, NilClass] If nil (Def), this part is not included in the returned String.
  # @param langcode: [Symbol, String] :en (Def)
  # @return [String] Either XPath or text for the pagenation stats part on Grid
  def xpath_grid_pagenation_stats_with(n_filtered_entries: , text_only: false, cur_page: 1, start_entry: 1,  end_entry: nil, n_all_entries: nil, langcode: :en)

    exp_txt = ApplicationController.str_info_entry_page_numbers_core(
      n_filtered_entries: n_filtered_entries,
      start_entry: start_entry,
      end_entry: end_entry,
      cur_page: cur_page,
      n_all_entries: n_all_entries,
      langcode: langcode
    )

    return exp_txt if text_only

    sprintf("/%s[%s]",  # the leading '/' is essential.
            XPATHGRIDS[:pagenation_stats],
            ModuleCommon.xpath_contain_text(exp_txt, case_insensitive: false))  # CSS is case-sensitive.
    # "//*[contains(concat(' ', normalize-space(@class), ' '), ' pagenation_stats ')][contains(., 'MY_TEXT_XXX')]"
  end

  ################################################################
  # Gem related
  ################################################################

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

end
