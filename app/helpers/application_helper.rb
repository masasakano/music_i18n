# coding: utf-8
module ApplicationHelper

  include ModuleCommon

  # For toastr Gem. From
  # <https://stackoverflow.com/a/58778188/3577922>
  def toastr_flash
    flash.each_with_object([]) do |(type, message), flash_messages|
      type = 'success' if type == 'notice'
      type = 'error' if type == 'alert'
      text = "<script>toastr.#{type}('#{message}', '', { closeButton: true, progressBar: true })</script>"
      flash_messages << text.html_safe if message
    end.join("\n").html_safe
  end

  # true if the environmental variable is set and non-false
  def is_env_set_positive?(key)
    ENV.keys.include?(key.to_s) && !(%w(0 false FALSE f F)<<"").include?(ENV[key])
  end

  # Returns a shortest-possible String expression of a float
  #
  # Note that if the number is larger than the maxlength,
  # the returned String length is as such.
  #
  # @example
  #    short_float_str(1.340678, maxlength: 4)  # => "1.34"
  #    short_float_str(7,        maxlength: 4)  # => "7"
  #    short_float_str(12345.78, maxlength: 4)  # => "12345.7" (or something like that! not verified.)
  #    short_float_str(12.40678, maxlength: 4)  # => "12.4"
  #
  # @param num [Numeric] Number
  # @param maxlength [Integer] Maximum length
  # @param str_nil [String] what to return when nil
  def short_float_str(num, maxlength: 4, str_nil: "nil")
    return str_nil if !num
    num_s = num.to_s
    return num_s if num <= maxlength
    length_int = num_s.sub(/\..+/, "").length
    sprintf "%#{maxlength}.#{maxlength-length_int-1}", num_s
  end

  # Returns String "01:23:45" or "23:45" from second
  #
  # @param sec  [Integer, NilClass]
  # @param return_nil: [Boolean] If true (Def: false) and if nil is given, nil is returned.
  # @return [String]
  def sec2hms_or_ms(sec, return_nil: false)
    return if sec.nil? && return_nil
    sec = 0 if sec.blank?
    sec = sec.to_i
    fmt = ((sec <= 3599) ? "%M:%S" : "%H:%M:%S")
    
    Time.at(sec).utc.strftime(fmt)
  end

  # Convert a HMS-type String to Integer second
  #
  # @example
  #   '12:34:56'.split(':').map(&:to_i).inject(0) { |a, b| a * 60 + b }
  #   # => 45296
  #   '34:56'.split(':').map(&:to_i).inject(0) { |a, b| a * 60 + b }
  #   # => 2096
  #
  # @see https://stackoverflow.com/a/27982733/3577922 
  #
  # @param str [String]
  # @return [Integer] in seconds.  If nil is given, nil is returned.
  def hms2sec(str)
    return str if !str
    str.split(':').map(&:to_i).inject(0) { |a, b| a * 60 + b }
  end

  # Returns <title> for HTML from Path
  #
  # This assumes the langcode is 2-characters and no Models are 2-character long.
  #
  # @return [String]
  def get_html_head_title
    ar = url_for.split('/')
    ar = ar.map{|i| i.blank? ? nil : i}.compact
    if (ar.size < 1)
      ''
    else
      langcode_str = ''
      if ar[0].size == 2
        langcode_str = ' ('+ar[0].upcase+')'
        ar.shift
      end
      ar.map{|i| (/^\d*$/ =~ i) ? nil : i}.compact.join('-').capitalize + langcode_str
    end
  end

  # Returns an HTML YouTube link
  #
  # @param word [String, NilClass, Symbol] Hilighted word (for users to click).
  #    If nil, returns a null string.
  #    If the special symbol :uri, the raw URI. Otherwise it must be String.
  # @param root_kwd [String, NilClass] if nil, word is used. This can be omitted.
  # @param timing [Integer, NilClass] in second
  # @param long [Boolean] if false (Def), youtu.be, else www.youtube.com
  # @param target [Boolean] if true (Def), +target="_blank"+ is added.
  # @param kwds [Hash] optional arguments passed to link_to
  # @return [String] HTML of <a> for YouTube link
  def link_to_youtube(word, root_kwd=nil, timing=nil, long: false, target: true, **kwds)
    return '' if word.blank?
    word = ((word == :uri) ? nil : word.to_s)
    root_kwd ||= word if word
    root_kwd = word if root_kwd.respond_to?(:divmod) && !timing && word
    uri = self.method(:link_to_youtube).owner.uri_youtube(root_kwd, timing, long: long, with_http: true) # <= ApplicationHelper.uri_youtube()
    word = sprintf("%s", uri) if !word
    opts = { title: "Youtube" }.merge(kwds)
    opts[:target] = "_blank" if target
    ActionController::Base.helpers.link_to word, uri, **opts
  end

  # Returns a YouTube URI with/without the preceeding "https//"
  #
  # @param root_kwd [String]
  # @option timing [Integer, NilClass] in second
  # @param long: [Boolean] if false (Def), youtu.be, else www.youtube.com
  # @param with_http: [Boolean] if true (Def: false), returned string contains "https://"
  # @return [String] youtu.be/Wfwe3f8 etc
  def self.uri_youtube(root_kwd, timing=nil, long: false, with_http: false)
    raise "(#{__method__}) nil is not allowed for root_kwd" if !root_kwd
    timing   = nil if timing == "" || timing == "0" || timing == 0
    domain = (long ? 'www.youtube.com' : 'youtu.be')
    root_kwd = root_kwd.sub(%r@\A(?:https?://)?(?:www\.)?(?:(?:youtube.com|youtu.be)/*)?@i, "")
    if /[[:space:]]/ =~ root_kwd
      raise "root_kwd=#{root_kwd.inspect} must contain no spaces."
    end
    timing_part = (timing ? sprintf("?t=%ds", timing) : '')
    (with_http ? "https://" : "") + domain + "/" + root_kwd + timing_part
  end

  # Returns a YouTube URI with/without the preceeding "https//" from a valid URI
  #
  # Youtube has various forms of URIs
  #
  #   "youtu.be/WFfas92FA?t=24"
  #   "youtu.be.com/shorts/WFfas92FA?t=24"
  #   "https://www.youtube.com/watch?v=WFfas92FA?t=24s&link=youtu.be"
  #   "https://www.youtube.com/live/vXABC6EvPXc?si=OOMorKVoVqoh-S5h?t=24"
  #   "https://www.youtube.com/embed/agbNymZ7vqZ"
  #
  # For Youtube links, most query parameteres are removed (but v and maybe t (if with_time is true)).
  # For other sites, they are preserved unless with_query is false.
  #
  # @param uri_str [String] e.g., "https://www.youtube.com/watch?v=IrH3iX6c2IA"
  # @param long: [Boolean] if false (Def), youtu.be, else www.youtube.com ; for any other URIs, ignored.
  # @param with_scheme: [Boolean] if true (Def: false), returned string contains "https://"
  # @param with_host: [Boolean]
  # @param with_query: [Boolean] For Youtube, this is ignored. Recommended to set true.
  # @param with_time: [Boolean] Only for Youtube.
  # @return [String] youtu.be/Wfwe3f8 etc
  def self.normalized_uri_youtube(uri_str, long: false, with_scheme: false, with_host: true, with_time: false, with_query: true)
    raise "(#{__method__}) nil is not allowed for uri_str" if uri_str.blank?

    ## NOTE: manual processing instead of letting URI.parse() to judge is necessary
    #    because "youtube.com:8080/" is considered to have uri.scheme of "youtube.com" (!)
    s = ((%r@\A[a-z]{2,9}://?@ !~ uri_str.strip) ? "https://" : "")+uri_str  # "telnet" and "gopher" are the longest and "ftp" is the shortest I can think of, hence {2, 9}.
    uri = URI.parse(s)
    query_hs = Rack::Utils.parse_query uri.query

    uri.host = uri.host.downcase
    is_youtube = (/\A(?:www\.)?(youtube\.com|youtu\.be)\z/ =~ uri.host)
    # domain_orig = $1  # (youtube.com|youtu.be)

    if is_youtube
      uri.path = uri.path.sub(%r@\A/(shorts|live|embed)/@, '/')
      
      identifier = (query_hs["v"] || uri.path.sub(%r@\A/@, ""))

      if long
        uri.host = "www.youtube.com"
        uri.path = "/watch"
        query_hs = query_hs.slice("v", "t")
        query_hs["v"] = identifier
      else
        uri.host = "youtu.be"
        uri.path = "/"+identifier
        query_hs = query_hs.slice("t")
      end
      query_hs = query_hs.slice("v") if !with_time
      query_hs["t"].sub!(/s\z/, "") if query_hs.has_key?("t")
      uri.query = query_hs.to_param
    end

    ret = ""
    ret << (uri.scheme + "://") if with_scheme
    ret << uri.host             if with_scheme || with_host  # with_scheme has a priority.
    ret << (":"+uri.port.to_s)  if ![80, 443].include?(uri.port)
    ret << (ret.blank? ? uri.path.sub(%r@\A/@, '') : uri.path)

    if (is_youtube || with_query) && uri.query.present?
      ret << "?"+uri.query
    end

    ret
  end

  # to check whether a record has any dependent children
  #
  # @see https://stackoverflow.com/a/68129947/3577922
  #
  # @note +Tree::TreeNode+ has the method of the same name: {http://rubytree.anupamsg.me/rdoc/Tree/TreeNode.html#children%3F-instance_method}
  def has_children?
    ## This would be simpler though may initiate more SQL calls:
    #  self.class.reflect_on_all_associations.map{ |a| self.send(a.name).any? }.any?
    self.class.reflect_on_all_associations.each{ |a| return true if self.send(a.name).any? }
    false
  end


  # to check whether a record has any dependent children that
  # would not be cascade-destroyed.
  #
  # @see has_children?
  # @see undestroyable_associations
  #
  # @param skip_nullify: [Boolean] if true (Def), "dependent: :nullify"
  #   will be treated the same as ":destroy", namely they are not counted as "undestroyable".
  def has_undestroyable_children?(**kwd)
    undestroyable_associations(**kwd).each{ |a| return true if self.send(a.name).any? }
    false
  end

  # Returns all undestroyable children
  #
  # @see undestroyable_associations
  #
  # @return [Array<ApplicationRecord>]
  def undestroyable_children(**kwd)
    undestroyable_associations(**kwd).map{ |a| self.send(a.name) }.flatten
    false
  end

  # Returns an Array of associations that may contain dependent children that
  # would not be cascade-destroyed.
  #
  # For example, a user alywas has a role, the association record of which
  # would be destroyed as soon as the user is removed from the DB.
  # That is normal and needs no caution.
  # By contrast, if a user owns an article that would not be cascade-destroyed,
  # deleting of the user must be treated with caution.
  #
  # This method returns the associations that fall into the latter.
  #
  # @see has_undestroyable_children?
  #
  # @param skip_nullify: [Boolean] if true (Def), "dependent: :nullify"
  #   will be treated the same as ":destroy", namely they are not counted as "undestroyable".
  # @return [Array<ActiveRecord::Reflection>]
  def undestroyable_associations(skip_nullify: true)
    destroy_keys = %i(destroy delete destroy_async)
    destroy_keys.push(:nullify) if skip_nullify 
    # Note: the other potentials: [:restrict_with_exception, :restrict_with_error]

    self.class.reflect_on_all_associations.filter{|i|
      opts = i.options
      (!(opts.has_key?(:through) && opts[:through]) &&
       !(opts.has_key?(:dependent) && destroy_keys.include?(opts[:dependent])))
    }
  end
  private :undestroyable_associations


  # Returns either Date or DateTime from Rails form parameters.
  #
  # params obtained from form.date_select contains something like:
  #   "r_date(1i)"=>"2019", "r_date(2i)"=>"1", "r_date(3i)"=>"9"
  #
  # This method converts them to Date or DateTime.
  # In default, Date is returned if the number is 3 or less,
  # unless klass option is given.
  #
  # @param prm [ActionController::Parameters]
  # @param kwd [String] Keyword of params
  # @param klass [Class, NilClass] Date or DateTime, or if nil, it is judged
  #    from the number of the parameters
  # @return [Date, DateTime, NilClass] if none of them is found, nil is returned
  def get_date_time_from_params(prm, kwd, klass=nil)
    num = prm.keys.select{|i| /\A#{Regexp.quote(kwd)}\(\d+i\)\z/ =~ i}.size
    return nil if num == 0
    klass ||= ((num <= 3) ? Date : DateTime)
    begin
      klass.send(:new, *((1..num).to_a.map{|i| prm[sprintf "#{kwd.to_s}(%di)", i].to_i}))
    rescue Date::Error
      warn "Wrong Date format: "+(1..num).to_a.map{|i| prm[sprintf "#{kwd.to_s}(%di)", i].to_i}.inspect
      raise
    end
  end

  # Returns a Boolean value from params value
  #
  # The input should be String.
  #
  # @param prmval [String, NilClass] params['is_ok']
  # @return [Boolean, NilClass]
  def get_bool_from_params(prmval)
    case prmval
    when "", nil  # This should not be the case if params()
      nil
    when "0", 0, "false"
      false
    when "1", 1, "true"
      true
    else
      raise "Unexpected params value=(#{prmval})."
    end
  end

  # Get place from params
  #
  # @param hsprm [Hash, Params]
  # @return [Place]
  def get_place_from_params(hsprm)
    return Place.find(hsprm['place_id'].to_i) if !hsprm['place_id'].blank?
    return Place.find(hsprm['place'].to_i) if !hsprm['place'].blank? && hsprm['place'].respond_to?(:gsub) && /\A\d+\z/ =~ hsprm['place']

    prm = hsprm['place.prefecture_id']
    return Place.unknown(prefecture: Prefecture.find(prm.to_i)) if !prm.blank?

    prm = hsprm['place.prefecture_id.country_id']
    return Place.unknown(country: Country.find(prm.to_i)) if !prm.blank?

    Place.unknown
  end

  # Get an Artist from Title (or maybe ID)
  #
  # Permitted formats:
  #
  # (1) Beatles, The
  # (2) The Beatles
  # (3) ?567            # for artist.id==567
  # (4) Dummy (ID=568)  # for artist.id==568
  #
  # In (4), the String part of "Dummy" is ignored.
  #
  # @param artist_name [String] Maybe Integer-String like "56" to mean Artist primary ID
  # @param model [Model] to add errors
  # @param langcode: [String] To help identify an Artist
  # @param place: [Place] To help identify an Artist (NOT yet supported!)
  # @return [Artist, NilClass] nil if not found or specified
  def get_artist_from_params(artist_name, model, langcode: nil, place: nil)
    return nil if artist_name.blank?
    artist = 
      case artist_name.strip
      when /\A\?(\d+)\z/, /\(ID=(\d+)\)|\?(\d+)\z/i
        Artist.find ($1 || $2).to_i  # "$3" is also desirably OR-ed?
      else
        opts = {match_method_upto: :optional_article_ilike} # See Translation::MATCH_METHODS for the other options
        opts.merge!({langcode: langcode})
        Artist.find_by_a_title :titles, artist_name, **opts
      end
    if !artist
      model.errors.add :artist, 'is not registered. Please register the artist first.'
    end
    artist
  end

  # @return [String] Language switcher link used in application.html.erb, "html_safe"-ed.
  def language_switcher_link
    locale_cur = (I18n.locale.blank? ? 'en' : I18n.locale)

    locale_links = %w(en ja).map{ |elc|
      # Maybe replaced with: I18n.available_locales
      lc2display = BaseWithTranslation::LANGUAGE_TITLES[elc.to_sym][elc]
      cssklass = "lang_switcher_"+elc
      if locale_cur.to_s == elc
        content_tag(:span, lc2display, class: cssklass)
      else
        #link_to lc2display, url_for(locale: elc)  # Rails.application.routes.url_helpers.
        begin
          str_link = link_to(lc2display, url_for(locale: elc, params: params_hash_without_locale))
        rescue ActionController::UnfilteredParameters #=> err
          # When a submitted form results in "422 Unprocessable Entity",
          # the params would include lots of parameters that are not allowed
          # in the original URL.  For example, if an erroneous content is submitted from `new`,
          # it shows back the `new` page with `params` containing loads of data
          # that are *not permitted* in `url_for` for :new, hence raising
          # ActionController::UnfilteredParameters .
          # In such a case, this uses just explicit GET parameters in the following.
          #
          # NOTE that this would be insufficient when `new` (or `edit`) accepts GET query parameters,
          # which is probably not included as the GET parameters in the "SUBMIT" of new or edit.
          # In such a case, `request.query_parameters` would be empty, despite that
          # the original URL may have contained GET query parameters.
          # But I *think* the root of the problem is the submission from `new` or `edit`
          # would not preserve the passed GET parameters; thus, whenever 
          # "422 Unprocessable Entity" happens from "new?prm1=5", it would cause
          # a trouble, regardless of this routine!
          # So, the solution would be, submission from `new` with query parameters
          # should preserve the given GET parameters.  It is perhaps the case for Engage.
          # Check it out.
          str_link = link_to(lc2display, url_for(locale: elc, params: request.query_parameters.except("locale")))

          #logger.info "ERROR01: (#{err.class.name}) #{err}"
          #logger.info "ERROR02: query=#{request.query_parameters.inspect}"
        end
        content_tag(:span, str_link, class: cssklass)   # Rails.application.routes.url_helpers.
      end
    }
    ("["+locale_links.join("|")+"]").html_safe
  end

  # @return [Hash] equivalent to params, excluding action, controller, and locale
  def params_hash_without_locale
    # hsret = {}.merge params  # => (in some cases; see above (language_switcher_link)) ActionController::UnfilteredParameters or ActionView::Template::Error: unable to convert unpermitted parameters to hash
    hsret = {}
    ignores = %w(authenticity_token action commit controller locale)
    params.each_pair do |ek, ev|
      next if ignores.include? ek
      hsret[ek] = ev
    end
    hsret
  end

  # Used for emails sent from the server (esp. by Devise)
  #
  # When the link sent from the server is intercepted by the distributor
  # and if the linke is modified to them
  #
  # @return [Hash] may or may not include key :title
  def self.opts_title_re_mail_distributor
    return {} if ENV['MAIL_DISTRIBUTOR'].blank? || ENV['MAIL_DISTRIBUTOR'].strip.blank?
    domain = (Rails.application.config.action_mailer.smtp_settings[:domain].strip rescue nil)
    return {} if domain.blank?
    {title: I18n.t("mail.Link_handled_by", mail_distributor: ENV['MAIL_DISTRIBUTOR'].strip, domain: domain)}
  end

  # Wrapper of pluralize to handle i18n string
  #
  # @param count [Numeric]
  # @param label [Symbol, String] String passed to +I18n.t()+
  # @param ja_classifier: [String] 助数詞
  # @param ja_particle: [String] 助詞
  # @param locale [Symbol, String] :ja, :en etc
  # @param **kwd [Hash] optional parameters passed to +I18n.t()+, like +:default+, +:my_parameter+
  def pluralize_i18n(count, label, ja_classifier: "個", ja_particle: "の", locale: I18n.locale, **kwd)
    tra = I18n.t(label, **kwd)
    case locale.to_sym
    when :ja
      sprintf "%s%s%s%s", count, ja_classifier, ja_particle, tra
    else
      pluralize(count, I18n.t(label, **kwd))
    end
  end

  # @param model [Class, ApplicationRecord, String, Symbol]
  # @return [String] singular name of the model
  def get_modelname(model)
    (model.respond_to?(:name) ? model.name : (model.class.respond_to?(:name) ? model.class.name : model.to_s)).underscore.singularize
  end

  # Printing an array/relation inline for display
  #
  # @param ary [:map] Array or relation of Models.
  # @return [String] html_safe
  # @yield [String] html_safe [String, Model] is given. Should return the String for each item.
  def print_list_inline(ary, separator: I18n.t(:comma, default: ", "))
    ary.map{|em|
      tit = (em.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either)).html_safe
      (block_given? ? yield(tit, em) : tit)
    }.join(separator).html_safe
  end

  # Grid index path helper
  #
  def grid_index_path_helper(klass, action: "index", column_names: [], max_per_page: 25)
    klass_plural = (klass.respond_to?(:rewhere) ? klass.name : klass.class.name).underscore.pluralize
    Rails.application.routes.url_helpers.url_for(
      only_path: true,
      controller: klass_plural,
      action: action,
      params: {(klass_plural+"_grid") => {
                 column_names: column_names,
                 max_per_page: max_per_page
               }}
    )
  end

  # Ordered model for BaseWithTranslation to be used collection in Simple Form
  #
  # "[[Name, ID], ..."
  #
  # The returned String is NOT html_safe.
  #
  # @param klass [BaseWithTranslation]
  # @param with_weight [String] if true, and if the model has :weight column, ordered by weight.
  def ordered_models_form(klass, with_weight: true)
    raise "Has to be BaseWithTranslation to be ordered." if !klass.method_defined?(:title_or_alt)
    rela =
      if with_weight && klass.attribute_names.include?("weight")
        klass.order(:weight)
      else
        klass.all
      end
    rela.map{|i| [i.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either), i.id]}
  end

  # to suppress warning, mainly that in Ruby-2.7.0:
  #   "Passing the keyword argument as the last hash parameter is deprecated"
  #
  # Especially, the one raised here:
  #   "/active_record/persistence.rb:630: warning: The called method `update!' is defined here"
  def suppress_ruby270_warnings
    begin
      tmp = $stderr
      $stderr = open('/dev/null', 'w')
      yield
    ensure
      $stderr.close if !$stderr.closed?
      $stderr = (tmp ? tmp : STDERR)
    end
  end
end
