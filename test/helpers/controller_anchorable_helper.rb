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

  # Tests authorized accesses to the parent page, where Anchoring-s are listed in the first place
  #
  # @param anchoring [Anchoring, BaseWithTranslation]
  # @return [Integer] Number of asserts executed
  def _assert_authorized_get_to_parent(anchoring, fail_users: [], success_users: [], h1_title_regex: nil, **opts)
    raise ArgumentError, "At least one user must be specified." if fail_users.empty? && success_users.empty?
    parent = (anchoring.respond_to?(:anchorable) ? anchoring.anchorable : anchoring)
    #path = Rails.application.routes.url_helpers.polymorphic_path(parent)
    #_assert_authorized_get_set(path, parent, model_record, fail_users: fail_users, success_users: success_users, h1_title_regex: nil) # defined in /test/helpers/controller_helper.rb
    if !h1_title_regex
      title_core = Regexp.quote(parent.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either, article_to_head: true))
      h1_title_regex = /\b#{title_core}\b/
    end

    assert_authorized_show(parent, h1_title_regex: h1_title_regex, skip_public_access_check: true, fail_users: fail_users, success_users: success_users, **opts){ |user, record|
      assert_match(/^Links\b/, css_select('h3.links_anchoring').first.text.strip)  # defined in /app/views/layouts/_index_anchorings.html.erb
    }
  end

  # Tests authorized accesses to :new and maybe :edit
  #
  # @param anchoring [Anchoring, BaseWithTranslation] If the target record (of BaseWithTranslation like Artist), namely "anchorable", is given, only :new is tested, not :edit
  # @return [Integer] Number of asserts executed
  def _assert_authorized_gets_to_anchorables(anchoring, fail_users: [], success_users: [])
    raise ArgumentError, "At least one user must be specified." if fail_users.empty? && success_users.empty?
    n_asserts = 0
    %i(new edit).each do |action|
      next if :edit == action && !anchoring.respond_to?(:anchorable)
      if :new
      end
      path = path_anchoring(anchoring, action: action)  # defined in base_anchorables_helper.rb
      model_record = ((:new == action) ? Anchoring : anchoring) 
      _assert_authorized_get_set(path, model_record, fail_users: fail_users, success_users: success_users, h1_title_regex: nil) # defined in /test/helpers/controller_helper.rb
      n_asserts += 1
    end
    return n_asserts
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
  # @param url_wiki: [String] JA-Wikipedia URL
  # @param wiki_name: [String] Entry name for the JA-Wikipedia
  # @param wiki_lang: [String] 2-letter locale, like "ja"
  # @param success_users: [Array<User>] only a single user is tested so far...(mandatory)
  # @return [Anchoring] created one.
  def _assert_create_anchoring_url_wiki(parent_record, url_wiki: nil, wiki_name: nil, wiki_lang: "ja", fail_users: [], success_users: [], is_debug: false)
    wiki_ja_domain = "ja.wikipedia.org"
    url_str = (url_wiki || sprintf("%s/%s/%s", wiki_ja_domain, "wiki", "%E5%B0%8F%E6%9E%97%E5%B9%B8%E5%AD%90#%E5%87%BA%E6%BC%94")) # "/wiki/小林幸子#出演
    wiki_name ||= "小林幸子"
    note = "note-3-"+__method__.to_s

    new3 = _assert_create_anchoring_url_existing_domain(parent_record, url_str: url_str,
              fail_users: fail_users, success_users: success_users, note: note, is_debug: is_debug)

    assert_equal wiki_lang, new3.url.orig_langcode.to_s
    trans = new3.url.orig_translation
    assert_equal wiki_name,  trans.title, "#{_get_caller_info_message(prefix: true)} Wiki-name is wrong... #{[url_wiki, wiki_name, wiki_lang].inspect}"
    assert_equal wiki_lang,  trans.langcode
    assert_equal site_categories(:site_category_wikipedia), new3.site_category

    assert_includes new3.url.title,    trans.title, 'sanity check'
    assert_includes new3.domain_title.title(langcode: "en"), 'Wikipedia', "#{_get_caller_info_message(prefix: true)} DomainTitle is not wiki?..."
    new3
  end

  ## Chronicle URL and Anchoring addition
  #
  # @return [Anchoring] created one.
  def _assert_create_anchoring_url_chronicle(parent_record, fail_users: [], success_users: [], is_debug: false)
    chronicle = "https://nannohi-db.blog.jp/archives/8522599.html"
    note = "note-4-"+__method__.to_s

    newa = _assert_create_anchoring_url_existing_domain(parent_record, url_str: chronicle,
              fail_users: fail_users, success_users: success_users, note: note, is_debug: is_debug)
    #action, new_mdl5 = assert_authorized_post(Anchoring, user: @moderator_ja, path_or_action: path_create, redirected_to: proc_art0_path, params: hschronicle, method: :post, diff_count_command: EQUATION_MODEL_COUNT, diff_num: 10011){ |user, record| # defined in /test/helpers/controller_helper.rb

    assert_equal chronicle, newa.url.url
    assert_equal "ja",      newa.url.url_langcode.to_s
    assert_equal site_categories(:site_category_chronicle), newa.site_category
    newa
    # trans = newa.url.orig_translation
    # assert_equal "ハラミちゃんが表紙の「月刊ショパン5月号」発売", trans.title
    # assert_equal "ja",       trans.langcode
    #}
  end

  # General (wrapper) method for creating Anchoring AND Url but for existing Domain and DomainTitle
  #
  # @param parent_record [BaseWithTranslation] like Artist instance
  # @param url_str: [String] of URL, mandatory.
  # @param success_users: [Array<User>] only a single user is tested so far...(mandatory)
  # @return [Array<Anchoring>] created one.
  def _assert_create_anchoring_url_existing_domain(parent_record, url_str: , diff_num: 10011, fail_users: [], success_users: [], **opts)
    tnow = Time.now.utc
    anc = _assert_create_anchoring_url_core(parent_record,
             fail_users: fail_users, success_users: success_users,
             url_str: url_str, diff_num: diff_num, **opts)

    assert_operator tnow, :<, anc.created_at, 'sanity check'
    assert_operator tnow, :>, anc.domain.created_at, "#{_get_caller_info_message(prefix: true)} Existing Domain should have been identified, but..."
    assert_operator tnow, :>, anc.domain_title.created_at
    anc
  end

  ## Failed in creation of Anchoring because its URL matches an existing one
  #
  # @param ref_anchoring [Anchoring]
  # @param success_users: [Array<User>] only a single user is tested so far...(mandatory)
  # @return [Anchoring] or model...?  refute, anyway
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
    _assert_create_anchoring_url_core(record2upd, diff_num: diff_num, **(opts.merge({is_create: false})))
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
  # @param action:  [Symbol] experimental...
  # @param exp_response: [Symbol, Integer] passed to assert_authorized_post
  # @param updated_attrs: [Array] passed to assert_authorized_post. Default is %i(note) unless (exp_response: :unprocessable_entity)
  # @oaram is_debug: [Boolean] If true (Def: false), error message in saving is displayed to STDOUT
  # @return [Anchoring] created one.
  # @yield [Anchoring] Hash [allopts] to be passed to {#assert_authorized_post} is given and you can modify and return it. Useful for :update. If the block returns nil, allopts is not modified.
  def _assert_create_anchoring_url_core(parent_record, fail_users: [], success_users: [], title: "", url_langcode: nil, url_str: nil, domain_prefix: "", path_suffix: "", diff_num: 21111, site_category_id: nil, note: nil, is_create: true, action: nil, exp_response: nil, updated_attrs: nil, is_debug: false)
    raise ArgumentError, "At least one user must be specified." if fail_users.empty? && success_users.empty?
    if parent_record.respond_to?(:anchorable)
      anchoring = parent_record
      parent_record = parent_record.anchorable
    end

    raise ArgumentError, "single user only so far" if 1 != success_users.size
    action ||= (is_create ? :create : :update)
    path =
      case action
      when :create
        path_anchoring(parent_record, action: :create)  # defined in base_anchorables_helper.rb
      when :update
        path_anchoring(anchoring,     action: :update)
      else
        raise
      end

    opts = { path_id_symbol(parent_record) => parent_record.id }
    path_generate_method_str = parent_record.class.name.underscore + "_anchoring_path"
    proc_record_path = Proc.new{|record| send(path_generate_method_str, id: record.id, **opts)}  # Redirected path for create & update
    # NOTE: For :destroy, it should be plural: "_anchorings_path"

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

    updated_attrs ||= ((:unprocessable_entity == exp_response) ? [] : %i(note))
    allopts = {
      user: success_users.first,
      path_or_action: path,
      redirected_to: proc_record_path,
      params: hsprms,
      method: (is_create ? :post : :patch),
      diff_count_command: EQUATION_MODEL_COUNT,
      updated_attrs: updated_attrs,
      diff_num: (diff_num || 21111),
      exp_response: exp_response,
      is_debug: is_debug,
    }

    allopts = (yield(allopts) || allopts) if block_given?

    fail_users.each do |euser|
      assert_authorized_post(Anchoring, **(allopts.merge({user: euser, diff_num: 0, exp_response: :unprocessable_entity}))) # defined in /test/helpers/controller_helper.rb
    end

    re = Regexp.new(%r@https?://@)
    model_record = ((:create == action) ? Anchoring : anchoring) 

    action, new_mdl = assert_authorized_post(model_record, **allopts){ |_, record| # defined in /test/helpers/controller_helper.rb
      if record.respond_to?(:url) && (:unprocessable_entity != exp_response)  # this is the Anchoring class when failing.
        assert_match(re, record.url.url)  # NOTE: url_form becomes nil after "reload"; hence you would either check it here in the yield block or include it in updated_attrs as a Hash like {url: nerurl3}
        assert_equal url_str.sub(re, ""), record.url.url.sub(re, "")
      end
    }
    assert_equal((is_create ? :create : :update), action, "#{_get_caller_info_message(prefix: true)} should never fail, but...")
    new_mdl
  end # def _assert_create_anchoring_url_core

end
