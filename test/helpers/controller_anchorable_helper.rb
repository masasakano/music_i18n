# coding: utf-8
require "test_helper"

# This file is designed to be included in Controller-test filles about Anchoring 

module ActiveSupport::TestCase::ControllerAnchorableHelper
  include BaseAnchorablesHelper

  # Base arguments for Anchorings testing.  There should always be present.
  BASE_ARGS = {
    # title: "",  # mandatory on create, non-existent otherwise.
    url_form: "",  # mandatory
    url_langcode: "",
    #domain_id: "",  # mandatory at the model level but not in Controller
    # weight: "",       # currently not provided
    note: "",
    # memo_editor: nil, # currently not provided
    site_category_id: "",  # "" in default on create
  }.with_indifferent_access

  EQUATION_MODEL_COUNT = 'Translation.count*10000 + DomainTitle.count*1000 + Domain.count*100 + Url.count*10 + Anchoring.count*1'

  # Returns params Hash.
  #
  # Everything given here must be non-nil, otherwise raises an Error.
  # For the parameters that are not given, the default one is used.
  #
  # @param anchoring [Anchoring, Class<ActiveRecord>] Anchoring instance for :update or model for :create
  #    If anchoring is an Anchoring, the value is substituted unless the new one is given by the argument.
  # @param title: [String] mandatory on :create
  # @return [Hash] 
  def _build_params(anchoring, title: nil, **opts)
    param_keys = %i(url_form url_langcode note site_category_id)
    reths = 
      if !anchoring.respond_to?(:new_record?) || anchoring.new_record?
        raise ArgumentError, "String Title must be given (which may be empty). anchoring=#{anchoring.inspect}" if !title
        BASE_ARGS.merge({title: title}).with_indifferent_access
      else
        # so far, title in edit is simply ignored here because the future specification is uncertain.
        BASE_ARGS.merge({}).with_indifferent_access
      end

    param_keys.each do |ek|
      if opts.has_key?(ek) || opts.has_key?(ek.to_s)
        raise ArgumentError, "Value for Key (#{ek.inspect}) is nil, but it must be a String (which may be empty)." if !opts[ek]
        reths[ek] = opts[ek]
      elsif anchoring.respond_to? :anchorable
        reths[ek] =
          case ek.to_sym
          when :url_form
            anchoring.url.url
          when :site_category_id
            anchoring.site_category.id
          else
            anchoring.url.send(ek)
          end
      end
    end

    reths
  end

  # @param anchoring [Anchoring]
  def _refute_public_accesses_to_anchorables(anchoring)
    %i(new edit).each do |action|
      _assert_login_demanded(path_anchoring(anchoring, action: action)) # defined in /test/helpers/controller_helper.rb / base_anchorables_helper.rb
    end
  end

  # @param anchoring [Anchoring]
  def _assert_authorized_gets_to_anchorables(anchoring, fail_users: [], success_users: [])
    %i(new edit).each do |action|
      path = path_anchoring(anchoring, action: action)  # defined in base_anchorables_helper.rb
      model_record = ((:new == action) ? Anchoring : anchoring) 
      _assert_authorized_get_set(path, model_record, fail_users: fail_users, success_users: success_users, h1_title_regex: nil) # defined in /test/helpers/controller_helper.rb
    end

    # hs2pass5 = hsprms.merge({url_form: "https://naiyo.com/abc", note: "invisible5"})
    # assert_equal :create, assert_unauthorized_post(Anchoring, user: nil, params: hs2pass5, path_or_action: paths[:create]) # defined in /test/helpers/controller_helper.rb
  end

  ## Successful creation of Anchoring and Url with NON-existing Domain and DomainTitle and then with existing ones
  #
  # @param parent_record [BaseWithTranslation] like Artist instance
  # @param success_users: [Array<User>] only a single user is tested so far...(mandatory)
  # @return [Array<Anchoring>] created one.
  def _assert_create_anchoring_urls_domains(parent_record, fail_users: [], success_users: [], is_debug: false)
    ##### Creating Domain, DomainTitle
    non_existing_domain = "non-existing1.example.com"
    url1 = sprintf("%s/%s/%s", non_existing_domain, parent_record.class.name, "newabc.html?q=123&r=456#anch")
    note1 = "note-1"

    new1 = _assert_create_anchoring_url_core(parent_record,
              fail_users: fail_users, success_users: success_users,
              url_str: url1, note: note1,
              diff_num: 21111,
              is_debug: is_debug)
    
    assert_equal SiteCategory.unknown, new1.site_category, "SiteCategory should be the unknown one, but..."   # this should have been checked in updated_attrs
    assert_includes new1.url.title,          non_existing_domain
    assert_includes new1.domain_title.title, non_existing_domain

    ##### Existing Domain, DomainTitle, specifying a title and url_langcode
    url2 = url1.sub(/c\.html/, 'cde')
    note2 = "note-2"
    title2 = "My 2nd Domain"
    url_langcode2 = "kr"

    new2 = _assert_create_anchoring_url_core(parent_record,
              fail_users: fail_users, success_users: success_users,
              url_str: url2, note: note2,
              title: title2,
              url_langcode: url_langcode2,
              diff_num: 10011,
              is_debug: is_debug)
    
    assert_equal SiteCategory.unknown, new2.site_category, "#{_get_caller_info_message(prefix: true)} SiteCategory should be the unknown one, but..."   # this should have been checked in updated_attrs
    assert_equal title2,        new2.url.title, "#{_get_caller_info_message(prefix: true)} title unexpected..."
    assert_equal url_langcode2, new2.url.url_langcode
    assert_equal new1.domain, new2.domain, "#{_get_caller_info_message(prefix: true)} Domain should unchange, but..."
    assert_equal (dt=new1.domain_title), (dt2=new2.domain_title), "#{_get_caller_info_message(prefix: true)} DomainTitle should unchange, but..."
    assert_includes dt.title, dt2.title
    assert_equal  dt.created_at, dt.updated_at

    [new1, new2]
  end # def _assert_create_anchoring_url_domains
  

  ## Successful creation of Anchoring and Url with wiki (hence existing Domain and DomainTitle)
  #
  # @param parent_record [BaseWithTranslation] like Artist instance
  # @param success_users: [Array<User>] only a single user is tested so far...(mandatory)
  # @return [Anchoring] created one.
  def _assert_create_anchoring_url_wiki(parent_record, fail_users: [], success_users: [], is_debug: false)
    tnow = Time.now.utc

    ##### Creating Domain, DomainTitle
    wiki_ja_domain = "ja.wikipedia.org"
    url3 = sprintf("%s/%s/%s", wiki_ja_domain, "wiki", "%E5%B0%8F%E6%9E%97%E5%B9%B8%E5%AD%90#%E5%87%BA%E6%BC%94") # "/wiki/小林幸子#出演
    note3 = "note-3"

    new3 = _assert_create_anchoring_url_core(parent_record,
              fail_users: fail_users, success_users: success_users,
              url_str: url3, note: note3,
              diff_num: 10011,
              is_debug: is_debug)
    
    assert_equal "ja", new3.url.orig_langcode.to_s
    trans = new3.url.orig_translation
    assert_equal "小林幸子", trans.title
    assert_equal "ja",       trans.langcode
    assert_operator tnow, :<, new3.created_at, 'sanity check'
    assert_operator tnow, :>, new3.domain.created_at, "Existing Domain should have been identified, but..."
    assert_operator tnow, :>, new3.domain_title.created_at
    assert_equal site_categories(:site_category_wikipedia), new3.site_category

    assert_includes new3.url.title,          trans.title, 'sanity check'
    assert_includes new3.domain_title.title(langcode: "en"), 'Wikipedia', "#{_get_caller_info_message(prefix: true)} DomainTitle is not wiki?..."
    new3
  end

  ## Failed in creation of Anchoring because its URL matches an existing one
  #
  # @param ref_anchoring [Anchoring]
  # @param success_users: [Array<User>] only a single user is tested so far...(mandatory)
  # @return [Array<Anchoring>] created one.
  def _refute_create_identical_anchoring(ref_anchoring, fail_users: [], success_users: [], **opts)
    opts = {note: 'should fail..', diff_num: 0, is_create: true}.merge(opts)
    _assert_create_anchoring_url_core(ref_anchoring,
                                      fail_users: fail_users, success_users: success_users, **opts)
  end

  ## Should create a new Anchoring (=association) for an existing Url for a model
  #
  # as long as the model does not already have an Anchoring for the Url.
  #
  # @param ref_anchoring [Anchoring]
  # @param anchorable [BaseWithTranslation, NilClass] can be nil only IF ref_anchoring is dup-ped and already set for the associting BaseWithTranslation but not saved (i.e., new_record?)
  # @param success_users: [Array<User>] only a single user is tested so far...(mandatory)
  # @param is_debug [Boolean] to display the error message in saving
  # @return [Anchoring] created one.
  def _assert_create_anchoring_existing_url(ref_anchoring, anchorable=nil, fail_users: [], success_users: [], **opts)
    if anchorable
      ref_anchoring = ref_anchoring.dup
      ref_anchoring.anchorable_type = anchorable.class.name
      ref_anchoring.anchorable_id   = anchorable.id
    end

    opts = {note: 'should succeed in creating an Anchoring..', diff_num: 1, is_create: true}.merge(opts)

    _assert_create_anchoring_url_core(ref_anchoring,
                                      fail_users: fail_users, success_users: success_users, **opts)
  end

  # :update version of _assert_create_anchoring_url_core
  #
  # @param record2upd [Anchoring] the one to update. The values here are set for the form.
  # @param diff_num [Integer] Default is 0. Be warned that some type of updates create new models of Domain, DomainTilte (and its Translation).
  # @param is_debug [Boolean] to display the error message in saving
  # @return [Anchoring] created one.
  def _assert_update_anchoring_url(record2upd, diff_num: 0, **opts)
    parent_record = record2upd.anchorable
    _assert_create_anchoring_url_core(parent_record, diff_num: diff_num, **(opts.merge({is_create: false})))
  end


  ## Successful creation of Anchoring and Url
  #
  # @param parent_record [BaseWithTranslation, Anchoring] like Artist instance. Or, existing Anchoring instance can be given for a reference OR to update it (in combination of (is_create: false)).
  # @param success_users: [Array<User>] only a single user is tested so far...(mandatory)
  # @param title: [String] non-nil
  # @param url_langcode: [String, NilClass]
  # @param url_suffix: [String, NilClass] You can directly specify this (without "https://"). If nil, Default.
  # @param domain_prefix: [String] if url_suffix is nil, you can specify this. Must be valid characters for Domain.
  # @param path_suffix: [String]  Must be valid characters for Path.
  # @param site_category_id: [String] if nil, Default is used.
  # @param note: [String] if nil, Default is used.
  # @param is_create: [Boolean] Def: true
  # @oaram is_debug: [Boolean] If true (Def: false), error message in saving is displayed to STDOUT
  # @return [Anchoring] created one.
  # @yield [Anchoring] Hash [allopts] to be passed to {#assert_authorized_post} is given and you can modify and return it. Useful for :update. If the block returns nil, allopts is not modified.
  def _assert_create_anchoring_url_core(parent_record, fail_users: [], success_users: [], title: "", url_langcode: nil, url_str: nil, domain_prefix: "", path_suffix: "", diff_num: 21111, site_category_id: nil, note: nil, is_create: true, is_debug: false)
    if parent_record.respond_to?(:anchorable)
      anchoring = parent_record
      parent_record = parent_record.anchorable
    end

    raise ArgumentError, "single user only so far" if 1 != success_users.size
    path = path_anchoring(parent_record, action: :create)  # defined in base_anchorables_helper.rb

    opts = { path_id_symbol(parent_record) => parent_record.id }
    path_create_method_str = parent_record.class.name.underscore + "_anchoring_path"
    proc_record_path = Proc.new{|record| send(path_create_method_str, id: record.id, **opts)}

    if !url_str
      url_str = 
        if anchoring 
          anchoring.url.url
        else
          domain_str = domain_prefix + "non-existing1.example.com"
          sprintf("%s/%s/%s", domain_str, parent_record.class.name, "newabc#{path_suffix}?q=123&r=456#anch")
        end
    end

    note ||= "note-1"

    hsprms = _build_params(
      anchoring || Anchoring,
      title: title,
      url_form: url_str,
      note: (note || "note-1")
    ) # Title, SiteCategory auto-guessed. url_langcode is nil in default.

    hsprms[:url_langcode]     = url_langcode.to_s     if url_langcode
    hsprms[:site_category_id] = site_category_id.to_s if site_category_id

    allopts = {
      user: success_users.first,
      path_or_action: path,
      redirected_to: proc_record_path,
      params: hsprms,
      method: (:is_create ? :post : :patch),
      diff_count_command: EQUATION_MODEL_COUNT, updated_attrs: %i(note),
      diff_num: (diff_num || 21111),
      is_debug: is_debug,
    }

    allopts = (yield(allopts) || allopts) if block_given?

    fail_users.each do |euser|
      assert_authorized_post(Anchoring, **(allopts.merge({user: euser, diff_num: 0, exp_response: :unprocessable_entity}))) # defined in /test/helpers/controller_helper.rb
    end

    re = Regexp.new(%r@https?://@)
    action, new_mdl = assert_authorized_post(Anchoring, **allopts){ |_, record| # defined in /test/helpers/controller_helper.rb
      if record.respond_to?(:url)  # this is the Anchoring class when failing.
        assert_match(re, record.url.url)  # NOTE: url_form becomes nil after "reload"; hence you would either check it here in the yield block or include it in updated_attrs as a Hash like {url: nerurl3}
        assert_equal url_str.sub(re, ""), record.url.url.sub(re, "")
      end
    }
    assert_equal((:is_create ? :create : :update), action, "#{_get_caller_info_message(prefix: true)} should never fail, but...")
    new_mdl
  end # def _assert_create_anchoring_url_core

end
