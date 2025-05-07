# coding: utf-8
require "test_helper"

class ActiveSupport::TestCase
  UNAUTHENTICATED_USER_NAME = 'Unauthenticated(Public)'

  # @note The definition name should not begin with "test_" because otherwise the definition
  #       would be actually run in every testing, maybe scores of times in total!
  #
  # @example
  #   run_test_create_null(ChannelOwner)
  #
  # @param klass [ApplicationRecord, String] of the model to test like ChannelOwner
  # @param col_name: [Symbol, String] an exsiting column
  # @param extra_colnames: [Array<Symbol, String>] form parameters that are mandatory, e.g., :langcode
  def run_test_create_null(klass, col_name: :note, extra_colnames: [])
    caller_info = _get_caller_info_message

    camel_str = (klass.respond_to?(:name) ? klass.name : klass.to_s.camelize)
    snake_str = camel_str.underscore

    if extra_colnames.blank? && klass.respond_to?(:name) && !klass.column_names.include?(col_name.to_s)
      raise "FATAL: Specified class #{klass.name} does not have the column '#{col_name}' strangely. Contact the code developper (#{__FILE__}:#{__method__} called from #{caller_info})."
    end

    hs_in = extra_colnames.map{|i| [i, ""]}.to_h.with_indifferent_access
    hs_in[col_name] = "" if col_name
    assert_no_difference(camel_str+".count") do
      post send(snake_str.pluralize+"_url"), params: { snake_str => hs_in}
      #post send(snake_str.pluralize+"_url"), params: { snake_str => { col_name => "" }}
      # assert flash[:alert].present?, "Did not fail with Flash-alert for a null create."  # flash does not work well for some reason in this helper thought it would work if directly included in a Controller test.
    end
    assert_response :unprocessable_entity
    assert_includes css_select('.alert-danger h2').text, "prohibited", "Called from #{caller_info}"
    
    css1 = ".alert-danger #error_explanation_list"
    assert_select css1, {count: 1}, "Text: #{css_select(css1).to_s}"
    assert_operator 1, :<=, css_select(css1+" li").size, "At least one error should be reported."
    # print "DEBUG(#{__FILE__}):response: "; puts @response.body
  end

  # Test a title in show for BaseWithTranslation
  #
  # @example
  #   assert_base_with_translation_show_h2  # defined in /test/helpers/controller_helper.rb
  def assert_base_with_translation_show_h2
    caller_info = _get_caller_info_message

    css = css_select('h2')[0]
    assert css, "(#{__method__}) called from #{caller_info}): H2 does not seem to exist."
    assert_equal "All registered translated names", (css && css.text), "(#{__method__}) called from #{caller_info}): No Translation table seems to exist."
  end


  # Test get-index for an access-restricted page
  #
  # Public access should be completely banned.
  #
  # @param model [Class] ActiveRecord
  # @yield [User, ActiveRecord] Anything while the user is successfully authorized, i.e., only for viewings by success_users
  def assert_authorized_index(model, fail_users: [], success_users: [], h1_title: nil, &bl)
    index_path = Rails.application.routes.url_helpers.polymorphic_path(model)
    h1_title ||= model.name.pluralize
    _assert_authorized_get_set(index_path, model_record=model, fail_users: fail_users, success_users: success_users, h1_title_regex: h1_title, include_w3c_validate: true, &bl)
  end


  # Test get-show for an access-restricted page
  #
  # Public access should be completely banned.
  #
  # @param record [ActiveRecord]
  # @param opts [Hash] Notably, you may give +{skip_public_access_check: true}+
  # @yield [User, ActiveRecord] Anything while the user is successfully authorized, i.e., only for viewings by success_users
  def assert_authorized_show(record, fail_users: [], success_users: [], h1_title_regex: nil, include_w3c_validate: true, **opts, &bl)
    show_path = Rails.application.routes.url_helpers.polymorphic_path(record)

    if h1_title_regex.blank?
      tit = 
        %i(title_or_alt title).each do |metho|
          break record.send(metho) if record.respond_to?(metho)
          nil
        end

      re = (tit.respond_to?(:gsub) ? ".+"+Regexp.quote(tit) : "")
      h1_title_regex = /^#{Regexp.quote(record.class.name)}#{re}/
    end

    _assert_authorized_get_set(show_path, model_record=record, fail_users: fail_users, success_users: success_users, h1_title_regex: h1_title_regex, include_w3c_validate: include_w3c_validate, **opts, &bl)
  end


  # Test get-new for an access-restricted page
  #
  # @param model [Class] ActiveRecord
  # @yield [User, ActiveRecord] Anything while the user is successfully authorized, i.e., only for viewings by success_users
  def assert_authorized_new(model, fail_users: [], success_users: [], h1_title_regex: nil, &bl)
    new_path = Rails.application.routes.url_helpers.polymorphic_path(model, action: :new)
    h1_title_regex ||= /^New #{Regexp.quote(model.name)}/

    base_proc = proc{|user|
      assert css_select("section#form_edit_translation input##{model.name.underscore}_alt_title").present?, "#{_get_caller_info_message(prefix: true)} New should have a field for alt_title, but..." if model.method_defined?(:alt_title)  # used in BaseWithTranslation only
      assert css_select("section#sec_primary textarea##{model.name.underscore}_note").present?, "#{_get_caller_info_message(prefix: true)} New should have a field for note, but..."  # "note" is applicable in any model of this framework
    }

    _assert_authorized_get_set(new_path, model_record=model, fail_users: fail_users, success_users: success_users, h1_title_regex: h1_title_regex, include_w3c_validate: true, base_proc: base_proc, &bl)
  end


  # Test get-new for an access-restricted page
  #
  # @param record [ActiveRecord]
  # @yield [User, ActiveRecord] Anything while the user is successfully authorized, i.e., only for viewings by success_users
  def assert_authorized_edit(record, fail_users: [], success_users: [], h1_title_regex: nil, &bl)
    edit_path = Rails.application.routes.url_helpers.polymorphic_path(record, action: :edit)
    h1_title_regex ||= /^Edit(ing)? #{Regexp.quote(record.class.name)}/

    _assert_authorized_get_set(edit_path, model_record=record, fail_users: fail_users, success_users: success_users, h1_title_regex: h1_title_regex, include_w3c_validate: true, &bl)
  end


  # Test HTTP-get for the unauthorized and authorized for an action to an access-restricted page
  #
  # Public access is assumed to be completely banned.
  #
  # @param path [String]
  # @option model_record [Class<ActiveRecord>, ActiveRecord] Unless include_w3c_validate is true, this is not used...
  # @param params [Hash]
  # @param fail_users: [Array<User>] Unauthorized users
  # @param success_users: [Array<User>] Authorized users
  # @param h1_title_regex: [Regexp, String, NilClass] If String, a complete match
  # @param skip_public_access_check: [Boolean] Unless true (Def: false), this checks whether public access is ceratinly banned.
  # @param include_w3c_validate: [Boolean] If true, may w3c-validate
  # @param bind_offset: [Integer, NilClass] Depth of the call (to get caller information for error messages)
  # @param base_proc: [Proc, NilClass] a Proc to run prior to the given block.
  # @yield [User, ActiveRecord] Anything while the user is successfully authorized, i.e., only for viewings by success_users
  def _assert_authorized_get_set(path, model_record=nil, params: nil, fail_users: [], success_users: [], h1_title_regex: nil, skip_public_access_check: false, include_w3c_validate: true, bind_offset: DEF_CALLER_INFO_BIND_OFFSET, base_proc: nil, &bl)
    raise ArgumentError, "At least one user must be specified." if fail_users.empty? && success_users.empty?
    model = (model_record.respond_to?(:name) ? model_record : model_record.class)
    model_w3c_validate = (include_w3c_validate ? model : nil)

    # h1_title ||= model.name.pluralize
    h1_title = h1_title_regex if !h1_title_regex.respond_to?(:named_captures)

    ## Public access forbidden
    _assert_login_demanded(path, bind_offset: bind_offset) unless skip_public_access_check

    ## Forbidden because not sufficiently authorized though authenticated
    fail_users.each do |user|
      _assert_unauthorized_access(path, user, params: params, bind_offset: bind_offset)
    end

    ## Access granted for the sufficiently authorized
    success_users.each do |user|
      _assert_authorized_access(path, user, params: params, h1_title_regex: h1_title_regex, model_w3c_validate: model_w3c_validate, bind_offset: bind_offset, base_proc: base_proc, &bl)
    end
  end
  private :_assert_authorized_get_set

  # Test access denied by non-authenticated
  #
  # @param path [String] path to access
  # @param params [Hash, NilClass]
  # @param bind_offset: [Integer, NilClass] Depth of the call (to get caller information for error messages)
  def _assert_login_demanded(path, params: nil, bind_offset: DEF_CALLER_INFO_BIND_OFFSET)
    caller_info_prefix = sprintf("(%s):", _get_caller_info_message(bind_offset: bind_offset))  # defined in test_helper.rb

    get path, params: params
    assert_response :redirect, "#{caller_info_prefix}: Public access to #{path} should be denied but is not..."
    assert_redirected_to new_user_session_path, "#{caller_info_prefix}: Wrong redirection from #{path} ..."
  end
  private :_assert_login_demanded

  # Test access denied by authenticated but not sufficiently authorized
  #
  # @param path [String] path to access
  # @param user [User, Nilclass] nil means unauthenticated
  # @param params [Hash, NilClass]
  # @param bind_offset: [Integer, NilClass] Depth of the call (to get caller information for error messages)
  # @param base_proc: [Proc, NilClass] a Proc to run prior to the given block.
  # @yield [User, String] 2-elements of User and String(Path). Anything while the user is logged in.
  def _assert_unauthorized_access(path, user, params: nil, bind_offset: DEF_CALLER_INFO_BIND_OFFSET, base_proc: nil)
    caller_info_prefix = sprintf("(%s):", _get_caller_info_message(bind_offset: bind_offset))  # defined in test_helper.rb

    sign_in user if user
    get path, params: params
    assert_response :redirect, "#{caller_info_prefix}: User=#{user.display_name.inspect} should NOT be able to access #{path} but they are..."
    assert_redirected_to (user ? root_path : new_user_session_path)

    base_proc.call(user, nil) if base_proc
    yield(user, path) if block_given?
    sign_out user if user
  end
  private :_assert_unauthorized_access


  # Test access of POST/DELETE/PATCH denied by authenticated but not sufficiently authorized to either :create or :destroy or :update
  #
  # @example create
  #    hs2pass = { langcode: "ja", title: "The Test", best_translation_is_orig: str_form_for_nil, site_category_id: @site_category.id.to_s }.with_indifferent_access
  #    assert_equal :create, assert_unauthorized_post(nil, DomainTitle, params: hs2pass) # defined in /test/helpers/controller_helper.rb
  #
  # @example destroy
  #    assert_equal :destroy, assert_unauthorized_post(User.first, Artist.first) # defined in /test/helpers/controller_helper.rb
  #
  # @example update 1 (checking also if attributes have unchanged)
  #    note3 = "aruyo3"
  #    action = assert_unauthorized_post(mymdl, user: @translator, params: {note: note3}, unchanged_attrs: [:note, :memo_editor]){ # defined in /test/helpers/controller_helper.rb
  #      refute_equal note3, mymdl.reload.note
  #    }
  #    assert :update, action
  # 
  # @example update 2
  #    mdlp = Parent.last
  #    action = assert_unauthorized_post(mymdl, user: @translator, params: {parent: mdlp}){ # defined in /test/helpers/controller_helper.rb
  #      refute_equal mdlp.id, mymdl.parent.id  # If more complicated comparison is required.
  #    }
  #    assert :update, action
  #
  # @param model_record [Class<ActiveRecord>, ActiveRecord] Class for :create and ActiveRecord for :destroy
  # @param user [User, NilClass]  nil means public (or a user already logged in)
  # @param path_or_action [String, Symbol, NilClass] path to access or action or Symbol of :create or :destroy or :update
  # @param params: [Hash, NilClass]
  # @param method: [Symbol, String, NilClass] :post (Def) or :delete or :patch. If nil, guessed from other parameters.
  # @param diff_count_command: [String, NilClass] Count method like 'Article.count*10 + Author.count'. In default, it is guessed from model_record
  # @param unchanged_attrs: [Array<Symbol>] Attributes that should not change after :update. Looked up only if action is :update.
  # @oaram is_debug: [Boolean] If true (Def: false), error message in saving is displayed to STDOUT
  # @param bind_offset: [Integer, NilClass] Depth of the call (to get caller information for error messages); 0 if you directly call this from your test script and want to know the caller location in your test-script.
  # @param base_proc: [Proc, NilClass] a Proc to run prior to the given block. [User, (Class<ActiveRecord>, ActiveRecord]Class<ActiveRecord>)] is passed. The 2nd element is the given model_record
  # @yield [User, (Class<ActiveRecord>, ActiveRecord)] Executed while the user is logged in, after evaluation. The 2nd element is the given model_record
  # @return [Symbol] action like :create (to check if this method is performing as intended)
  def assert_unauthorized_post(model_record, user: nil, path_or_action: nil, params: nil, method: nil, diff_count_command: nil, unchanged_attrs: [], is_debug: false, bind_offset: DEF_CALLER_INFO_BIND_OFFSET, base_proc: nil)
    action, method, path, model, opts = _get_action_method_path(model_record, path_or_action, method, params)

    caller_info_prefix = _get_caller_info_message(bind_offset: bind_offset, prefix: true)  # defined in test_helper.rb
    diff_count_command ||= model.name+".count"
    unchanged_attrs = [unchanged_attrs].flatten
    orig_attrs = unchanged_attrs.map{|i| model_record.send(i)} if :update == action

    #msg = sprintf("DEBUG(%s:%s): %s Path=%s, action=%s, method=%s, Examining-command=%s params=%s", File.basename(__FILE__), __method__, caller_info_prefix, path, action.inspect, method.inspect, diff_count_command.inspect, opts.inspect)
    #Rails.logger.debug msg

    sign_in user if user
    user_txt, user_current = _get_quoted_user_display_name(user, model, path)

    assert_no_difference(diff_count_command, "#{caller_info_prefix} (#{self.class.name}) User=#{user_txt} should NOT be able to #{action} at #{path} but they are (according to #{diff_count_command.inspect})...") do
      send(method, path, **opts)
    end

    assert_response :redirect, "#{caller_info_prefix} User=#{user_txt} should be redirected after denied access to #{action} at #{path} but ..." if user
    assert_redirected_to root_path, "#{caller_info_prefix} User=#{user_txt} should be redirected to Root-path after denied access to #{action} at #{path} but it is actually redirected to #{response.redirect_url.inspect}..." if user

    # called before the final asserts and yield
    base_proc.call(user || user_current, record_after) if base_proc

    if :update == action
      model_record.reload
      unchanged_attrs.each_with_index do |eatt, i|
        assert_equal orig_attrs[i], model_record.send(eatt)
      end
    end

    yield(user || user_current, model_record) if block_given?
    sign_out user if user

    action
  end

  # Test successful access by sufficiently authorized
  #
  # @param path [String] path to access
  # @param user [User]
  # @param params [Hash, NilClass]
  # @param h1_title_regex: [Regexp, String] If String, a complete match
  # @param model_w3c_validate: [Class, NilClass] ActiveRecord class. In specified, may w3c-validate
  # @oaram is_debug: [Boolean] If true (Def: false), error message in saving is displayed to STDOUT
  # @param bind_offset: [Integer, NilClass] Depth of the call (to get caller information for error messages)
  # @param base_proc: [Proc, NilClass] a Proc to run prior to the given block.
  # @yield [User, nil] Anything while the user is logged in.
  def _assert_authorized_access(path, user, params: nil, h1_title_regex: nil, model_w3c_validate: nil, is_debug: false, bind_offset: DEF_CALLER_INFO_BIND_OFFSET, base_proc: nil)
    caller_info_prefix = sprintf("(%s):", _get_caller_info_message(bind_offset: bind_offset))  # defined in test_helper.rb
    # h1_title ||= model.name.pluralize
    h1_title = h1_title_regex if !h1_title_regex.respond_to?(:named_captures)

    sign_in user if user
    get path, params: params
    user_current = response.request.env['warden'].user  ## if a user is already logged in
    user_txt = ((u=(user || user_current)) ? u.display_name.inspect : UNAUTHENTICATED_USER_NAME)

    assert_response :success, "#{caller_info_prefix}: User=#{user_txt} should be able to access #{path} but they are not..."

    if h1_title_regex
      tit = css_select('h1')[0]
      assert tit, "#{caller_info_prefix}: H1 does not seem to exist."
      if h1_title
        assert_equal h1_title, tit.text.strip, "#{caller_info_prefix}: H1 title differs from the expected #{h1_title.inspect}: #{tit.inspect}"
      else
        assert_match h1_title_regex, tit.text.strip, "#{caller_info_prefix}: H1 title does not match #{h1_title_regex.inspect}: #{tit.inspect}"
      end
    end

    w3c_validate "#{model_w3c_validate.name} - #{path}" if model_w3c_validate  # defined in /test/test_w3c_validate_helper.rb (see for debugging help)

    base_proc.call(user || user_current, nil) if base_proc
    yield(user || user_current, path) if block_given?
    sign_out user if user
  end
  private :_assert_authorized_access


  # Test POST/DELETE/PATCH by sufficiently authorized, which may succeed (at least in authorization) or fail (due to another condition)
  #
  # @example create fails (diff_num: 0)
  #    hs2pass = { langcode: "ja", title: "The Test", best_translation_is_orig: str_form_for_nil, site_category_id: @site_category.id.to_s }.with_indifferent_access
  #    assert_authorized_post(DomainTitle, user: @admin, params: {title: ""}, diff_num: 0) # defined in /test/helpers/controller_helper.rb
  #
  # @example create succeeds, returning the craeted model
  #    sign_in @moderator_ja
  #    action, record = assert_unauthorized_post(DomainTitle, params: hs2pass) # defined in /test/helpers/controller_helper.rb
  #    assert_equal :create, action
  #    assert record.id  # should be true (because diff_num=1 has been already tested, meaning a record has been craeted)
  #
  # @example destroy
  #    action, _ = assert_authorized_post(Music.last, user: @moderator) # defined in /test/helpers/controller_helper.rb
  #    assert_equal :destroy, action
  #
  # @example update 1
  #    action, mdl2 = assert_authorized_post(mdl1, params: {note: "aruyo"}, updated_attrs: [:note]) # defined in /test/helpers/controller_helper.rb
  #    assert_equal :update, action
  #    assert_equal mdl2, mdl1  # sanity check; NOTE mdl2 is already reloaded.
  #
  # @example update 2 (passing Hash for updated_attrs; you can actually check if the attribute unchanges because the algorithm does not check if the value is updated but checks if the value is equal to the given one.)
  #    action, _ = assert_authorized_post(mdl1, params: {note: "aruyo"}, updated_attrs: {note: "aruyo"}) # defined in /test/helpers/controller_helper.rb
  #    assert_equal :update, action
  #
  # @param model_record [Class<ActiveRecord>, ActiveRecord] Class for :create and ActiveRecord for :destroy and :update
  # @param user: [User, NilClass]  nil means either public or a user is already logged in
  # @param path_or_action [String, Symbol, NilClass] path to access or action or Symbol of :create or :destroy of :update
  # @param redirected_to: [String, Proc, NilClass] Usually guessed from path. If Proc, it is called on the spot (which can be helpful in :create)
  # @param params: [Hash, NilClass] innermost Hash of params
  # @param method: [Symbol, String, NilClass] :post (Def: :create) or :delete (for :destroy) or :patch (for :update).  If nil, guessed from other parameters.
  # @param diff_count_command: [String, NilClass] Count method like 'Article.count*10 + Author.count'. In default, it is guessed from model_record
  # @param diff_num: [Integer, NilClass] 1 or 0 or -1 in Default for respective actions of :create and :update and :destroy. If this is 0 in :create, it is interpreted as no Model being expected to be created (but the authorization passes).
  # @param updated_attrs: [Array<Symbol>, Hash] Attributes that should be updated after :update/:create, which you want to check (this does not need to be a complete list at all!). If Hash, +{key => expected-value}+. If Array, the expected values are taken from the given +params+.
  # @param exp_response: [Symbol, String, NilClass] If you expect this to fail, specify :unprocessable_entity
  # @param err_msg: [String, NilClass] Custom error message for assert_response
  # @oaram is_debug: [Boolean] If true (Def: false), error message in saving is displayed to STDOUT
  # @param bind_offset: [Integer, NilClass] Depth of the call (to get caller information for error messages); 0 if you directly call this from your test script and want to know the caller location in your test-script.
  # @param base_proc: [Proc, NilClass] a Proc to run prior to the given block. [User, ActiveRecord] is passed.
  # @yield [User, ActiveRecord] Executed while the user is logged in after running other tests.
  # @return [Array<Symbol, ActiveRecord, NilClass>] Pair of Array. 1st element is action. 2nd element is, if successful (in :create), returns the created (or updated) model, else nil.
  def assert_authorized_post(model_record, user: nil, path_or_action: nil, redirected_to: nil, params: nil, method: nil, diff_count_command: nil, diff_num: nil, updated_attrs: [], exp_response: nil, err_msg: nil, is_debug: false, bind_offset: DEF_CALLER_INFO_BIND_OFFSET, base_proc: nil)
    action, method, path, model, opts = _get_action_method_path(model_record, path_or_action, method, params)

    updated_attrs = _get_hash_attrs_from_array_or_hash(updated_attrs, params)

    diff_num ||=
      case action
      when :create;   1
      when :destroy; -1
      when :update;   0
      else
        raise "should never happen."
      end

    exp_response ||= ((0 == diff_num && action != :update) ? :unprocessable_entity : :redirect)
    diff_count_command ||= model.name+".count"

    #caller_info_prefix = _get_caller_info_message(bind_offset: bind_offset, prefix: true)  # defined in test_helper.rb
    #msg = sprintf("DEBUG(%s:%s): %s Path=%s, action=%s, method=%s, Examining-command=%s (expected_diff=%s) params=%s", File.basename(__FILE__), __method__, caller_info_prefix, path, action.inspect, method.inspect, diff_count_command.inspect, diff_num.inspect, opts.inspect)
    #Rails.logger.debug msg

    sign_in user if user
    user_txt, user_current = _get_quoted_user_display_name(user, model, path)
    model_last_be4 = model.order(:created_at, :id).last if :create == action

    assert_difference(diff_count_command, diff_num, "#{_get_caller_info_message(bind_offset: bind_offset, prefix: true)} User=#{user_txt} should #{action} at #{path} but failed (according to #{diff_count_command.inspect}; expected difference of #{diff_num}) for #{action.inspect}...") do
      send(method, path, **opts)
      (puts "DEBUG(#{File.basename __FILE__}:#{__method__}): Flash after saving ActiveRecord =========="; puts css_select(css_for_flash).to_s) if is_debug  # defined in test_helper.rb
      assert_response exp_response, ("#{_get_caller_info_message(bind_offset: bind_offset, prefix: true)} User=#{user_txt}" + (err_msg.present? ? ": "+err_msg : " should get response #{exp_response.inspect} after #{action} at #{path}, but status=#{_http_status_inspect(response.status)}..."))
    end

    ret = ((:update == action) ? model_record.reload : nil)
    if (:create == action && 0 != diff_num)
      ret = model.order(:created_at, :id).last
      refute_equal model_last_be4, ret if model_last_be4  # as long as there is a single model before processing.
    end

    record_after =
      if :destroy == action
        model_record  # This is usually ActiveRecord, though this may be a Class (Model) if the user passes so, specifiying the path directly
      elsif ret.respond_to?(:id)
        ret    # :update or successful :create
      else
        model  # This is the case when :create and creation fails.
      end

    if :redirect == exp_response
      redirected_to_path = _get_expected_redirected_to_after_post(redirected_to, action, model, model_record, record_after)
      regex = /\?(locale=en&.+|.+&locale=en\b.*)/
      if regex =~ redirected_to_path 
        ## => "/places/328056410/anchorings/980190963?locale=en&note=note-1&title=&url_form=non-existing1.example.com%2FPlace%2Fnewabc.html%3Fq%3D123%26r%3D456%23anch"
        #  WARNING: I don't know why!!!  But since they are query parameters, it does not matter much...
        ################################## Check it out!!!!
        Rails.logger.warn "WARNING(#{__FILE__}:#{__method__}): Redirected path has so many query parameters for some reason: "+redirected_to_path
        redirected_to_path.sub!(regex, "?locale=en")
      end
      assert_redirected_to(redirected_to_path, "#{_get_caller_info_message(bind_offset: bind_offset, prefix: true)} User=#{user_txt} should be redirected to #{redirected_to_path} after #{action} at #{path} but..." )
    end

    # called before the final asserts and yield
    base_proc.call(user || user_current, record_after) if base_proc

    if [:create, :update].include? action
       if :create == action && 0 == diff_num
         # skips  (b/c no Model is expected to be created)
       else
         assert ret, "#{_get_caller_info_message(bind_offset: bind_offset, prefix: true)} User=#{user_txt} failed with Update or Create, although the diff_num test passed (meaning redirection or some after-processing went wrong?)."
         updated_attrs.each_pair do |eatt, exp|
           assert_equal exp, ret.send(eatt), "#{_get_caller_info_message(bind_offset: bind_offset, prefix: true)} User=#{user_txt} checking the updated status of attr=(#{eatt}) fails."
         end
       end
    end

    # called right at the end
    yield(user || user_current, record_after) if block_given?
    sign_out user if user

    [action, ret]
  end  # def assert_authorized_post(model_record, ...)

  # Get a Hash from Array/Hash.  If Array, the expected path of redirected_to from the argument
  #
  # @param attrs [Hash, Array, NilClass] if Hash, does nothing. If Array, convers it into Hash, referring to template params
  #    e.g., if Array is [:a, :c], and templates is {a: 1, b: 2, }
  # @param params
  # @return [Hash] with_indifferent_access
  def _get_hash_attrs_from_array_or_hash(attrs, params)
    attrs = {}.with_indifferent_access if attrs.blank?
    return attrs if attrs.respond_to?(:merge)

    raise ArgumentError, "Null params given despite a significant set of attributes to compare (#{attrs.inspect}) are specified." if !params
    attrs = [attrs].flatten.map(&:to_s)
    reths = params.with_indifferent_access.slice(*(attrs)).with_indifferent_access
    if attrs.size != reths.keys.size
      raise ArgumentError, "Some specified attributes (#{(attrs - reths.keys).inspect}) not present in params."
    end
    reths
  end
  private :_get_hash_attrs_from_array_or_hash

  # Get the expected path of redirected_to from the argument
  #
  # @param redirected_to: [String, Proc, NilClass] Usually guessed from path. If Proc, it is called on the spot (which can be helpful in :create)
  # @param action: [Symbol]
  # @return [String]
  def _get_expected_redirected_to_after_post(redirected_to, action, model, model_record, record_after)
    if redirected_to.respond_to?(:call)
      redirected_to.call(record_after)
    elsif redirected_to
      redirected_to
    else
      redirect_path_arg =
        case (action.to_sym rescue action)
        when :create
          model.last
        when :destroy
          model
        when :update
          model_record
        else
          raise "should never happen."
        end
      Rails.application.routes.url_helpers.polymorphic_path(redirect_path_arg)
    end
  end
  private :_get_expected_redirected_to_after_post

  # @param model [ActiveRecord]
  # @return [Array<String, User>] 2-element Array of User display-name double-quoted and User
  def _get_quoted_user_display_name(user, model, path)
    return [user.display_name.inspect, user] if user

    # Gets a user-name if already logged-in.
    get path
    #get Rails.application.routes.url_helpers.polymorphic_path(model)  # GET Index. Unless you make an HTTP request, you cannot get it... (This does not work for more complicated paths.)

    if (logged_user=response.request.env['warden'].user)  ## if a user is already logged in
      [logged_user.display_name.inspect, logged_user]
    else
      [UNAUTHENTICATED_USER_NAME, nil]
    end
  end

  # Internal routine to process arguments
  #
  # @param model_record [Class<ActiveRecord>, ActiveRecord] Class for :create and ActiveRecord for :destroy
  # @option path_or_action [String, Symbol, NilClass] path to access or action or Symbol of :create or :destroy
  # @param method: [Symbol, String, NilClass] either :post (Def) or :delete. If nil, path must be an action, and this is automatically set.
  # @param params: [Hash, NilClass]
  # @return [Array] [action, method, path, model, hs_params]  Here, hs_params can be directly passed to POST like:  +post path, **hs_params+
  def _get_action_method_path(model_record, path_or_action, method, params)
    model = (model_record.respond_to?(:name) ? model_record : model_record.class)
    path = path_or_action

    case path_or_action
    when :create, :destroy, :update
      path, action = nil, path_or_action
    end

    action ||=
      if (model == model_record)
        :create
      elsif params.present?
        :update
      else
        :destroy
      end

    method ||=
      case action
      when :create
        :post
      when :update
        :patch
      when :destroy
        :delete
      else
        raise "should never: #{action.inspect}"
      end
        
    path ||= Rails.application.routes.url_helpers.polymorphic_path(model_record)

    hs_params = (params.present? ? {params: { model.name.underscore => params }} : {})

    [action, method, path, model, hs_params]
  end
  private :_get_action_method_path

  # @return [String] Inspect String of HTTP response code
  def _http_status_inspect(status)
    description =
      case status.to_s.to_i
      when 200
        "OK"
      when 204
        "No Content"
      when 302
        "Found (Redirect)"
      when 400
        "Bad Request"
      when 401
        "Unauthorized"
      when 403
        "Forbidden"
      when 404
        "Not Found"
      when 422
        ":unprocessable_entity"
      when 500
        "Internal Server Error"
      else
        nil
      end

    description ? sprintf("%s <%s>", status, description) : status.to_s
  end
end

