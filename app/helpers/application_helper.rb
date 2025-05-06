# coding: utf-8
module ApplicationHelper

  include ModuleCommon

  # Default directory for test fixtute data
  DEF_FIXTURE_DATA_DIR = Rails.root.join(*(%w(test fixtures data))).to_s

  # Default URL query key parameters to consider (in this framework) on Youtube
  #
  # * "v" (video identifier) is always considered regardless of the specification here.
  # * "t" (timing parameter) is specially handled, and specification here is irrelevant. See relevant methods.
  # * "lc" is for a comment, i.e., comment-highlighting.
  # * "list" is for a Playlist.
  # * "link" is how the URL is accessed(?)
  # * "si" seems to be for tracking.
  # * ... and many more.
  DEF_YOUTUBE_SIGNIFICANT_QUERY_KEYS = %w(lc)

  CSS_CLASSES = {
    consistency_place: "consistency_place",
  }.with_indifferent_access

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

  # Returns a HTML-safe title string followed by a marker if it is orig_langcode
  #
  # See self.html_titles in /app/grids/base_grid.rb
  #
  # This accepts an optional block which should return an Boolean to judge
  # if the marker is appended (true) or not (false).  The reason it is a block
  # is just because of run-time efficiency (in Grids).
  #
  # The returned String has a singleton method "lcode", as long as a proper title
  # or alike is returned (i.e., it is not defined when str_fallback is used
  # in {BaseWithTranslation#title} after all).
  #
  # @example unconditionally marking with an asterisk
  #   s = best_translation_with_asterisk(Artist.second, is_orig_char: "*", langcode: "ja", lang_fallback: true, str_fallback: "")
  #     # => s == 'Queen<span title="Original language">*</span>'  # (HTML-safe)
  #     #    s.lcode == "en"
  #
  # @example conditionally marking with an asterisk
  #   best_translation_with_asterisk(Artist.second, is_orig_char: (can?(:edit, Artist) ? "*" : nil), langcode: "ja", lang_fallback: false)
  #
  # @example conditionally marking with an asterisk with a block
  #   best_translation_with_asterisk(record, is_orig_char: "*", langcode: "ja", lang_fallback: false){|lcode| can?(:edit, record)}
  #
  # @param record [BaseWithTranslation]
  # @param is_orig_char [String, NilClass] Unless nil, title in a language of is_orig is followed by this char (Def: nil). See also yield.
  # @param kwds [Hash] passed to {BaseWithTranslation#title} to {BaseWithTranslation#get_a_title}
  # @return [String] html_safe-ed
  # @yield [String] The locale String is given as an argument, and the block should return a Boolean.
  #   The block is not called unless i_orig_char is significant AND the returned String is the orig_langcode one.
  #   If a block is not given, it is assumed "true" is returned.
  def best_translation_with_asterisk(record, is_orig_char: nil, **kwds)
    tit = record.title(**kwds)

    ret = (tit.present? ? h(tit) : "")
    set_singleton_method_val(:lcode, tit.lcode, target: ret) if tit.respond_to?(:lcode)  # Define Singleton method String#lcode # defined in module_common.rb
    return ret if ret.blank?

    marker = %q[<span title="]+h(I18n.t("datagrid.footnote.is_original"))+%q[">]+h(is_orig_char)+%q[</span>] if is_orig_char && ret.present? && (record.orig_langcode == tit.lcode) && (!block_given? || yield(tit.lcode))
    ret << marker.html_safe if marker
    ret.html_safe
    ret
  end

  # Helper method to return a String with a bracket or empty
  #
  # For Editors only, even an empty "[]" is printed to let them know
  # the data are blank, while the empty one is not displayed for
  # general visitors.
  # 
  # @example 
  #    alt_tit = model.alt_title(langcode: 'en', lang_fallback: false, str_fallback: "")
  #    bracket_or_empty("[%s]", alt_tit, can?(:update, model))  <%# defined in application_helper.rb %>
  # 
  # @param fmt [String] sprintf format
  # @param prms [String, Array<String>]
  # @param is_editor [Boolean]
  # @return [String] html_safe unless blank
  def bracket_or_empty(fmt, prms, is_editor)
    prms = [prms].flatten
    is_all_safe = (fmt.html_safe? && prms.all?{|i| i.blank? || i.html_safe?})

    str_core = sprintf(fmt, *(prms.map{|i| i ? i : ""}))
    str_core = (is_all_safe ? str_core.html_safe : ERB::Util.html_escape(str_core))
 
    ret_str =
      if prms.any?(&:present?)
        str_core
      elsif is_editor
        '<span class="editor_only">' + str_core + '</span>'
      else
        ""
      end

    ret_str.html_safe
  end

  # Returns String "01:23:45" or "23:45" from second
  #
  # @param sec  [Integer, NilClass]
  # @param return_nil: [Boolean] If true (Def: false) and if nil is given, nil is returned.
  # @param return_if_zero: [Object] What returns when sec is 0 or "0" or "abc" (Def: "00:00")
  # @param negative_from_60min: [Boolean] if true (Def: false) and if a negative value is given, it is added to 60min;
  #     sec2hms_or_ms(-6, negative_from_60min: true)
  #       # => "59:54"
  # @return [String]
  def sec2hms_or_ms(sec, return_nil: false, return_if_zero: "00:00", negative_from_60min: false)
    return if sec.nil? && return_nil
    sec = 0 if sec.blank?
    sec = sec.to_i
    return return_if_zero if 0 == sec 
    fmt = ((sec.abs <= 3599) ? "%M:%S" : "%H:%M:%S")
    
    sign = ((sec < 0) ? "-" : "")
    if negative_from_60min
      sign = ""
    else
      sec = sec.abs
    end

    sign+Time.at(sec).utc.strftime(fmt)
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
  # @param blank_is_nil: [Boolean] if true (Def: false) and if "" is given, nil is returned.
  # @return [Integer] in seconds.  If nil is given, nil is returned.
  def hms2sec(str, blank_is_nil: false)
    return str if !str
    return nil if blank_is_nil && str.blank?
    str = str.strip
    sign = ((/\A\-/ =~ str) ? -1 : 1)
    str = str[1..-1] if sign == -1
    sign * str.split(':').map(&:to_i).inject(0){ |a, b| a * 60 + b }
  end

  # Returns <title> for HTML from Path
  #
  # This assumes the langcode is 2-characters and no Models are 2-character long.
  #
  # This method returns always a String no matter what so that no exceptions would be ever raised.
  #
  # @return [String]
  def get_html_head_title
    retstr = ""
    hsroute = Rails.application.routes.recognize_path(pat=url_for)  # :only_path is true <https://api.rubyonrails.org/classes/ActionView/RoutingUrlFor.html>
    model_name = hsroute[:controller].singularize.camelize
    # e.g., hsroute === {:controller=>"play_roles", :action=>"index", :locale=>"ja"}
    retstr = model_name
    record = ""
    title = ""

    begin
      model_class = model_name.constantize
    rescue NameError #=> er
      #print "DEBUG(#{__method__}): #{er.inspect}"
      return retstr
    end

    case hsroute[:action]
    when "show", "edit", "update"
      record = 
        begin
          model_class.find(hsroute[:id])
        rescue
          nil
        end
      title = 
        if !record
          ""
        elsif BaseWithTranslation == model_class.superclass
          record.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either)
        else
          str = %i(title machine_title mname display_name name).each do |candkey|
            next if !record.respond_to?(candkey)
            s = record.send(candkey)
            break s.to_s.strip if s.present?
          end
          str ? str : ""
        end
    end

    action_str = 
      case hsroute[:action]
      when "index", "new", "create", "show", "edit", "update", "destroy"
        hsroute[:action]
      else
        ""
      end

    tit_display = ((title.size <= 20) ? title[0..19] : title[0..18]+"…")
    retstr << sprintf(" %s %s", action_str, tit_display)

    langcode_str = (hsroute[:locale] || "")
    if langcode_str.blank? && (fragment=pat.split('/')[0]).size == 2
      langcode_str = ' ['+fragment.upcase+']'
    end
    langcode_str = ' ['+langcode_str+']' if langcode_str.present?

    retstr << langcode_str

  rescue  # to make sure a page is displayed no matter what!
    retstr || ""
  end # def get_html_head_title


  # Returns an HTML link for (YouTube) Channel
  #
  # So far, only Youtube is considered. Else, a html-escaped bare word is returned.
  #
  # @example Standard link
  #   link_to_channel("click here", model.id_at_platform, kind: "id", platform: model.channel_platform)
  #
  # @example ID is the anchor to highlight
  #   link_to_channel(model.id_human_at_platform, kind: "handle", platform: model.channel_platform)
  #
  # @param word [String, NilClass, Symbol] Hilighted word (for users to click).
  #    If nil, returns a null string.
  #    If the special symbol :uri, the raw URI. Otherwise it must be String.
  # @option root_kwd [String, NilClass] ID String for Youtube. If nil, word is used. This is optional.
  # @param kind [String, Symbol] id or handle
  # @param platform [ChannelPlatform, String] So far, only "youtube" is accepted.
  # @param target: [Boolean] if true (Def), +target="_blank"+ is added.
  # @param link_title: [String] title attribute for the anchor
  # @param kwds [Hash] optional arguments passed to link_to
  # @return [String] HTML of <a> for YouTube link
  def link_to_channel(word, root_kwd=nil, kind: "id", platform: "youtube", target: true, link_title: "Youtube", **kwds)
    return '' if word.blank?
    s_platform = (platform.respond_to?(:mname) ? platform.mname : platform.to_s).downcase
    return ERB::Util.html_escape(word) if "youtube" != s_platform

    word = ((word == :uri) ? nil : word.to_s)
    root_kwd ||= word if word

    uri = "https://www.youtube.com/" +
      case kind.to_s.downcase
      when "id"
        "channel/"+root_kwd
      when "handle"
        "@"+root_kwd.sub(/\A@/, "")
      else
        raise ArgumentError, "wrong kind (#{kind.inspect})"
      end

    word = sprintf("%s", uri) if !word
    opts = { title: link_title }.merge(kwds)
    opts[:target] = "_blank" if target
    ActionController::Base.helpers.link_to word, uri, **opts
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
  # This is a wrapper of {ApplicationHelper.normalized_uri_youtube} to get a full valid URI/URL,
  # with/without a timing parameter but nothing else.
  #
  # Use {ApplicationHelper.get_id_youtube_video} if you only want the ID String.
  # Or, for full control, use the said method.
  #
  # @param root_kwd [String]
  # @option timing [Integer, NilClass] in second
  # @param long: [Boolean] if false (Def), youtu.be, else www.youtube.com
  # @param with_http: [Boolean, Symbol] if true (Def: false), returned string contains "https://". If :HaramiVid, it follows the standard of the current uri attribute values in HaramiVid in DB. The default follows with_scheme in {ApplicationHelper._normalized_uri_youtube_core}
  # @return [String] youtu.be/Wfwe3f8 etc
  def self.uri_youtube(root_kwd, timing=nil, long: false, with_http: false)
    raise "(#{__method__}) nil is not allowed for root_kwd" if !root_kwd
    raise "root_kwd=#{root_kwd.inspect} must contain no spaces." if /[[:space:]]/ =~ root_kwd

    root_kwd = _prepend_youtube(root_kwd)

    hs2pass = {long: long, with_host: true, with_time: false, with_query: true, with_scheme: with_http}
    normalized_txt = normalized_uri_youtube(root_kwd, **hs2pass)
    if :youtube == normalized_txt.platform  # singleton method
      normalized_txt = normalized_uri_youtube(root_kwd, **(hs2pass.merge({with_query: false})))  # This removes some default white-listed query parameters, including "lc"; see DEF_YOUTUBE_SIGNIFICANT_QUERY_KEYS
    end

    uri = Addressable::URI.parse( normalized_txt )

    return uri.to_s if :youtube != normalized_txt.platform

    timing = nil if timing == "" || timing == "0" || timing == "0s" || timing == 0
    if timing
      query_hs = Rack::Utils.parse_query uri.query
      query_hs["t"] = timing.to_s+"s"
      uri.query = query_hs.to_param
    end

    uri.to_s
  end

  # Guesses the site platform and returns it.
  #
  # @parm str [String, URI] may include "http://" or not.  Query parameters can be included, too.
  # @return [Symbol, String, NilClass] nil if input is blank. Symbols like (:youtube, :tiktok). String for domain ("www." is removed) if there is a valid host. Otherwise, the input String as it is.
  def self.guess_site_platform(str)
    return nil if str.blank?
    uri = Addressable::URI.parse(str)
    uri = Addressable::URI.parse("https://"+str) if !uri.host
    return nil if !uri.host
    
    case (host=uri.host.sub(/\Awww\./, "").downcase)
    when "youtu.be", /\Ayoutube\.[a-z]{2,3}(\.[a-z]{2})?\z/i
      :youtube
    when /\Atiktok\.[a-z]{2,3}(\.[a-z]{2})?\z/i
      :tiktok
    when "t.co", /\A(twitter|x)\.[a-z]{2,3}(\.[a-z]{2})?\z/i  # though "t.co" may point to anything!
      :twitter
    when /\Ainstagram\.[a-z]{2,3}(\.[a-z]{2})?\z/
      :instagram
    else
      host
    end
  end


  # Returns parsed URI whether the input has a scheme (https) at the head or not
  #
  # If the input *looks like* a URI but does not have a scheme, a scheme is added.
  # Otherwise, the input String is treated as it is.
  #
  # @parm uri_str [String] may include "http://" or not.
  # @return [Addressable::URI] 
  def self.parsed_uri_with_or_not(uri_str, def_scheme: "https")
    uri_str2pass = 
      if %r@\A([^:/]+:///?)?((?:www\.)[^.]|youtu.be/)(.+)@ =~ uri_str
        ($1.blank? ? def_scheme+"://" : $1) + $2 + $3
      else
        uri_str
      end

    Addressable::URI.parse(uri_str2pass)
  end

  # @param uri [URI::Generic]
  # @param without_slash: [Boolean] If true (false), the leading forward slash is deleted if host exists.
  # @return [String]
  def self.uri_path_query(uri, without_slash: false)
    ret = [uri.path, uri.query].compact.join("?")
    (without_slash && uri.host.present?) ? ret.sub(%r@\A/@, "") : ret  # the leading slash is removed if present?
  end

  # Prepend "youtu.be" if necessary.
  #
  # @param str [String] e.g., "abc12d", "youtu.be/"abc12d", "www.youtube.co.jp/"abc12d", "tiktok.com/abc", "https://x.com/abc"
  # @return [String] e.g., "youtu.be/Input-String/xyz" or the given String as it is if they already includwe the domain.
  def self._prepend_youtube(str)
    str = str.strip
    return str if %r@\A[a-z]+://@ =~ str           # "http://xxx.yyy" unchanges
    return str if str.split("/")[0].include?(".")  # "example.com/abc" unchanges
    return str if %r@[^/]*youtu(\.be|be.[a-z.]+)@ =~ str  # "youtu.be/ABC" or "www.youtube.co.jp/abc" unchanges
    "youtu.be/"+str
  end
  private_class_method :_prepend_youtube
  

  # Returns a YouTube URI with/without the preceeding "https//" from a valid URI
  #
  # Youtube has various forms of URIs
  #
  #   "youtu.be/WFfas92FA?t=24"
  #   "youtube.com/shorts/WFfas92FA?t=24"
  #   "https://www.youtube.com/watch?v=WFfas92FA?t=24s&link=youtu.be"
  #   "https://www.youtube.com/live/vXABC6EvPXc?si=OOMorKVoVqoh-S5h?t=24"
  #   "https://www.youtube.com/embed/agbNymZ7vqZ"
  #
  # For Youtube links, most query parameteres are removed (but v and lc (if with_query is true (Def))
  # and t (if with_time is true)), which can be controlled with +white_list+ argument.
  # For other sites, they are preserved unless with_query is false.
  #
  # @example Youtube
  #    k = "https://Youtu.Be:80/BBBCCCCQxU4?si=AAA5OOL6ivmJX999&t=53s&link=youtu.be&list=OLAK5uy_k-vV"
  #    normalized_uri_youtube(k, with_scheme: false, with_query: true, with_time: false, with_host: false) # => "BBBCCCCQxU4"
  #    normalized_uri_youtube(k, with_scheme: false, with_query: true, with_time: false, with_host: true) # => "youtu.be/BBBCCCCQxU4"
  #    normalized_uri_youtube(k, with_scheme: true,  with_query: false, with_time: true, with_host: true) # => "https://youtu.be/BBBCCCCQxU4?t=53"
  # @example other platforms
  #    k = "https://www.EXAMPLE.com/LIVE/watch?v=BBBCCCCQxU4&t=53&si=XXX"
  #    normalized_uri_youtube(k, with_scheme: false, with_query: true,  with_time: false, with_host: false) # => "LIVE/watch?v=BBBCCCCQxU4&t=53&si=XXX"
  #    normalized_uri_youtube(k, with_scheme: false, with_query: false, with_time: false, with_host: false) # => "LIVE/watch"
  #
  # @param uri_str [String] e.g., "https://www.youtube.com/watch?v=IrH3iX6c2IA" ; a simple String "IrH3iX6c2IA" is invalid.
  # @param long: [Boolean] if false (Def), youtu.be, else www.youtube.com ; for any other URIs, ignored.
  # @param with_scheme: [Boolean] if true (Def: false), returned string contains "https://" . Even if this is false, the returns String contains any other schemes like "sftp" than "https" as long as with_host is true
  # @param with_host: [Boolean]
  # @param with_query: [Boolean] For Youtube, this is used in conjuntion with +white_list+ (see {DEF_YOUTUBE_SIGNIFICANT_QUERY_KEYS} for detail; many parameters are filtered out even when this is true. For any other URLs, this means for all query parameters. Recommended to set true.
  # @param with_time: [Boolean] Only for Youtube.
  # @param white_list: [Array<String>] Only for Youtuber. Only listed ones survive even when with_query==true. "lc" is for a comment, i.e., comment-highlighting.
  # @return [String] youtu.be/Wfwe3f8 etc; the singleton method :platform is defined.
  def self.normalized_uri_youtube(uri_str, with_query: true, **kwds)
    ret, uri = _normalized_uri_youtube_core(uri_str, with_query: with_query, **kwds)

    # Note: for Youtube in the "long" format, the query parameter "v" is essential.
    if (:youtube == uri.platform || with_query) && uri.query.present?
      ret << "?"+uri.query
    end
    ret
  end
    
  # @param root_or_uri [String] Either an ID string of "IrH3iX6c2IA" or URI like "https://www.youtube.com/watch?v=IrH3iX6c2IA". Unlike {ApplicationHelper.normalized_uri_youtube}, this accepts the former, too.
  # @return [String] Youtube Video ID, as long as it is Youtube link (you can check it with (:youtube == ret_str.platform))
  def self.get_id_youtube_video(root_or_uri)
    uri_str = _prepend_youtube(root_or_uri)
    ret, _ = _normalized_uri_youtube_core(uri_str, with_scheme: false, with_host: false, with_time: false, with_query: false)
    ret
  end

  # internal method.  See {ApplicationHelper.normalized_uri_youtube} for detail
  #
  # @note if the original contains the unsafe scheme and if the platform is a known one,
  #    the scheme is replaced with "https".
  # @note if with_host==true and if the original input contains other than "https",
  #    the output will include the scheme regardless of the given +with_scheme+ parameter
  def self._normalized_uri_youtube_core(uri_str, long: false, with_scheme: false, with_host: true, with_time: false, with_query: true, white_list: DEF_YOUTUBE_SIGNIFICANT_QUERY_KEYS)
    raise "(#{__method__}) nil is not allowed for uri_str" if uri_str.blank?
    with_scheme = HaramiVid.uri_in_db_with_scheme? if :HaramiVid == with_scheme
    raise ArgumentError, "(#{__method__}) with_scheme must be Boolean or :HaramiVid, but (#{with_scheme.inspect})" if ![true, false].include?(with_scheme)

    ## NOTE: manual processing instead of letting URI.parse() to judge is necessary
    #    because "youtube.com:8080/" is considered to have uri.scheme of "youtube.com" (!)
    s = ((%r@\A[a-z]{2,9}://?@ !~ uri_str.strip) ? "https://" : "")+uri_str  # "telnet" and "gopher" are the longest and "ftp" is the shortest I can think of, hence {2, 9}.
    uri = Addressable::URI.parse(s)

    # This sets an instance variable: uri.platform
    adjust_queries!(uri, long: long, with_query: with_query, with_time: with_time, white_list: white_list)

    ret = ""
    ret.instance_eval{singleton_class.class_eval { attr_accessor "platform" }} if !ret.respond_to?(:platform)  # these 2 linew are equivalent to ModuleCommon#set_singleton_method_val
    ret.platform = uri.platform  # Define Singleton method String#platform

    if "http" == uri.scheme && ret.platform.is_a?(Symbol)
      uri.scheme = "https"  # For major sites, unsafe scheme "http" is replaced with "https".
    end

    if with_scheme
      ret << (uri.scheme + "://") 
    elsif ("https" != uri.scheme) && with_host
      Rails.logger.info("NOTE(#{__method__}): A non-standard scheme is given with with_host=true; so even though with_scheme=true is specified, the scheme is forcibly added to the output. URI-string=#{uri_str.inspect}")
      ret << (uri.scheme + "://") 
    end
    ret << uri.host             if with_scheme || with_host  # with_scheme has a priority.
    ret << (":"+uri.port.to_s)  if uri.port.present? && ![80, 443].include?(uri.port)
    ret << (ret.blank? ? uri.path.sub(%r@\A/@, '') : uri.path)

    [ret, uri]
  end

  # Rewrites the given URI model, maybe modifying the host and/or removing some (or most) query parameters
  #
  # @param uri [URI] This must be an already properly parsed URI
  # @param long: [Boolean] Only for Youtube. If false (Def), youtu.be, else www.youtube.com
  # @param with_time: [Boolean] Only for Youtube.
  # @param with_query: [Boolean] For Youtube, all queries but white listed ones are ignored even if this is set true. The time parameter is independent and depends on with_time. For every other URI, whether all queries are taken into account or not.
  # @param white_list: [Array<String>] Only for Youtuber. Only listed ones survive even when with_query==true. "lc" is for a comment, i.e., comment-highlighting.
  # @return [URI] the same as the given main parameter, which is destructively modified.
  def self.adjust_queries!(uri, long: false, with_query: true, with_time: false, white_list: DEF_YOUTUBE_SIGNIFICANT_QUERY_KEYS)
    uri.host = uri.host.downcase
    platform = guess_site_platform(uri.to_s)

    uri.instance_eval{singleton_class.class_eval { attr_accessor "platform" }} if !uri.respond_to?(:platform)  # these 2 linew are equivalent to ModuleCommon#set_singleton_method_val
    uri.platform = platform  # Define Singleton method String#platform

    return nil if platform.blank?
    case platform
    when Symbol
      query_hs = Rack::Utils.parse_query uri.query
      case platform
      when :youtube
        uri.path = uri.path.sub(%r@\A/(shorts|live|embed)/@, '/')

        identifier = (query_hs["v"] || uri.path.sub(%r@\A/@, ""))
        slice_keys = ([(long ? "v" : nil), (with_time ? "t" : nil)] + (with_query ? white_list : [])).compact
        query_hs = query_hs.slice(*slice_keys)
        query_hs["t"].sub!(/s\z/, "") if query_hs.has_key?("t")

        if long
          uri.host = "www.youtube.com"
          uri.path = "/watch"
          query_hs["v"] = identifier
        else
          uri.host = "youtu.be"
          uri.path = "/"+identifier
        end
      when :tiktok
        query_hs = query_hs.except("is_from_webapp", "sender_device", "web_id", "utm_source")
      when :instagram
        query_hs = query_hs.except("utm_source")
      end

      uri.query = query_hs.to_param
    else
      # do nothing
    end
    uri
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
  # The reverse helper (to get 1i, 2i, 3i, ... form) is {#get_params_from_date_time}
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

  # Reverse of {#get_date_time_from_params} in Application.helper
  #
  # pReturns a Hash like params from Date/DateTime
  #   {"r_date(1i)"=>"2019", "r_date(2i)"=>"1", "r_date(3i)"=>"9"}
  #
  # @param dt [Date, DateTime]
  # @param kwd [String, Symbol] Keyword of params
  # @param maxnum [Integer, NilClass] Number of parameters in params
  #    In default (if nil is given), 3 for Date and 5 for DateTime
  #    (n.b., "second" is not included as in Rails default).
  # @return [Hash] with_indifferent_access
  def get_params_from_date_time(dt, kwd, maxnum=nil)
    is_date = (dt.respond_to? :julian?)
    num = (maxnum || (is_date ? 3 : 5))

    if is_date
      num = [num, 3].min
      dtoa = %i(year month day).map{|i| sprintf("%0"+((:year == i) ? 4 : 2).to_s+"d", dt.send(i))}[0..(num-1)]
    else
      num = [num, 6].min
      dtoa = dt.to_a[0,6].reverse[0..(num-1)].map.with_index{|v, i| sprintf("%0"+((0 == i) ? 4 : 2).to_s+"d", v)}
    end

    s_kwd = kwd.to_s
    (1..num).to_a.map{|i| [sprintf("#{s_kwd}(%di)", i), dtoa[i-1]]}.to_h.with_indifferent_access
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
    when "0", 0, "false", false  # TrueClass, FalseClass are not the values in params.  But playing safe...
      false
    when "1", 1, "true", true
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
  # @return [String] singular name of the model from any
  def get_modelname(model)
    (model.respond_to?(:name) ? model.name : (model.class.respond_to?(:name) ? model.class.name : model.to_s)).underscore.singularize
  end

  # plural snake-case name of the model or any String (which usually agrees with table_name but no guarantee)
  #
  # @param model [Class, ApplicationRecord, String, Symbol]
  # @return [String]
  def plural_underscore(model)
    get_modelname(model).pluralize
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

  # Returns a sanitized (scrubs) HTML-frament, using rails-html-sanitizer Gem (which is a wrapper of Loofah)
  #
  # The default unsafe tags are all removed regardless of the specified permitted.
  #
  # @see https://github.com/rails/rails-html-sanitizer?tab=readme-ov-file#scrubbers
  # @see /config/application.rb
  #
  # @param str [String] This String is destructively sanitized.
  # @param targetblank: [Boolean] If true (Def), target="_blank" attribute is added to links
  # @param permitted: [Array] Array of permitted HTML tags
  # @return [Rails::HTML5::FullSanitizer] sanitized fragment
  def sanitized_html_fragment(str, targetblank: true, permitted: Rails.application.config.default_html_sanitize_permit_list)
    scrubber = Rails::HTML::PermitScrubber.new
    scrubber.tags = permitted
    html_fragment = Loofah.fragment(str)
    html_fragment.scrub!(:targetblank) if targetblank
    html_fragment.scrub!(scrubber)
    html_fragment
  end

  # Returns a sanitized String (wrapper of {#sanitized_html_fragment})
  #
  # @param #see sanitized_html_fragment
  # @return [String] sanitized String
  def sanitized_html(*args, **kwds)
    sanitized_html_fragment(*args, **kwds).to_s
  end

  # Returns the full path for the test data with the given root filename Regexp (or String) with one of candidate suffixes
  #
  # @param re [Regexp, String] to identify the file. If String, it is a partial match.
  # @param from_env: [Boolean] set this true to test dotenv-rails
  # @param suffixes: [Array<String>,String] Acceptable suffixes.
  # @return [String, NilClass]
  def get_fullpath_test_data(re, from_env: false, suffixes: %w(html md))
    if from_env
      fdir  = ENV['STATIC_PAGE_ROOT']   # defined in .env
      return if !fdir
      fnames = ENV['STATIC_PAGE_FILES'] # defined in .env
      return if !fnames
      fnames = fnames.split(/,/)
    else
      fdir = DEF_FIXTURE_DATA_DIR
      # fdir  = 'file://'+fdir.to_s
      fnames = Dir.glob(fdir.to_s+"/*.{#{[suffixes].flatten.join(',')}}").map{|i| i.sub(%r@.*/@, '')}
      #fnames = Dir.glob(fdir.to_s+"/*.{html,md}").map{|i| i.sub(%r@.*/@, '')}
    end

    fname = fnames.find{|i| re.respond_to?(:gsub) ? i.include?(re) : (re =~ i)}
    fname && fdir.sub(%r@/$@, '')+'/'+fname || nil
  end

  # Saves the marshal-led object to the specified file.
  #
  # @param obj [Object] any Ruby object (but not IO etc). Singleton methods are not saved.
  # @param fullpath [String] to save.
  def save_marshal(obj, fullpath)
    open(fullpath, "w"){|io|
      Marshal.dump(obj, io)
    }
  end

  # Wrapper of +ruto_link+ in Gem +rails_autolink+ to limit the length up to 50 (or else) like "https://ja.wikipedia.org/wiki/%E3%83%8F%E3%83%8..."
  def auto_link50(text, limit: 50)
    auto_link(text){|i| truncate(i, length: limit)}
  end

  # Country list where Japan comes at the top.
  #
  # You may combine this with:
  #   Country.sort_by_best_titles(countries_order_jp_top)
  #
  # @param rela [Relation, Country]
  # @return [Relation]
  def countries_order_jp_top(rela=Country)
    rela.order(Arel.sql(sql_order_jp_top))
  end

  # string for ORDER BY sql statements
  #
  # @return [String]
  def sql_order_jp_top
    "CASE countries.id WHEN #{Country.unknown.id rescue 9} THEN 0 WHEN #{Country['JP'].id rescue 9} THEN 1 ELSE 9 END"
  end

  # returns HTML for consistent or inconsistent Place
  #
  # The default return when inconsistent is:
  #   <span class="editor_only">(<span class="lead text-red"><strong>INCONSISTENT</strong>)</span></span>
  #
  # @example printed only if inconsitent
  #   html_consistent_or_inconsistent(is_consistent=false, postfix=" with Event".html_safe) if can_edit  # defined in application_helper.rb
  #
  # @example printed both, with no parentheses, for moderator CSS class.
  #   html_consistent_or_inconsistent(is_consistent=true, print_consistent: true, with_parentheses: false, span_class: "moderator_only my_other_class") if can_edit # defined in application_helper.rb
  #
  # @param is_consistent [Boolean] true if consistent
  # @param print_consistent: [Boolean] If true (Def: false), "consistent" is returned if consistent
  # @param with_parentheses: [Boolean] If true (Def), a pair of parentheses are included.
  # @param span_class: [String, NilClass] Returned HTML contains a pair of span tag with the given class. Def: "editor_only". If nil, just a class of "inconsistent_place" is used for the (outer) span.
  # @param prefix: [String] a html_safe String prepended to "INCONSISTENT" (or "consistent"); ENSURE this is html_safe. You may a trailing space for this.  This is printed before the parenthesis in the site default colour.
  # @param postfix: [String] a html_safe String appended to "INCONSISTENT" (or "consistent"); ENSURE this is html_safe. You may include a leading space for this.  This is printed inside the parentheses (if present) in red.
  # @return [String] html_safe String of "<span ...>INCONSISTENT<...>" or "consistent" or empty String. This can contain spaces (to specify more than one classes).
  def html_consistent_or_inconsistent(is_consistent, print_consistent: false, with_parentheses: true, span_class: "editor_only", prefix: "".html_safe, postfix: "".html_safe)
    return "".html_safe if is_consistent && !print_consistent
    raise ArgumentError, "postfix #{postfix.inspect} is NOT html_safe." if !postfix.html_safe?

    tag_class = ERB::Util.html_escape(span_class.present? ? [CSS_CLASSES[:consistency_place], (span_class.present? ? span_class : nil)].compact.join(" ") : "")

    core_html =
      if is_consistent
        (print_consistent ? "consistent"+postfix : "").html_safe
      else
        ('<span class="lead text-red"><strong>INCONSISTENT</strong>'+postfix+'</span>').html_safe
      end

    parenthesized_core_html = ((with_parentheses && !core_html.empty?) ?  ("("+core_html+")").html_safe : core_html)

    safe_html_in_tagpair(prefix + parenthesized_core_html, tag_class: tag_class)
  end

  # Pair of html_safe String of (usually) either span (Def) or div
  #
  # @example
  #   safe_html_in_tagpair("10 &gt; 9<br>8".html_safe, tag_class: "moderator_only smaller")  # defined in application_helper.rb
  #   # => '<span class="moderator_only smaller">10 &gt; 9<br>8</span>'  [html_safe-ed]
  #
  # @param safe_content [String] to be encomapassed in a pair of HTML tags. Assumed to be html_safe
  # @param tag_class: [String] String of CSS class(es) like "editor_only my_class1"
  # @param tag: [String] HTML tag (Def: "span")
  # @return [String] html_safe-ed 
  def safe_html_in_tagpair(safe_content, tag_class: "editor_only", tag: "span")
    raise "Argument has to be a html_safe String. Contact the code developer." if safe_content.present? && !safe_content.html_safe?
    pair = tag_pair_span(tag_class: tag_class, tag: tag)
    pair[0] + safe_content + pair[1]
  end

  # Pair of html_safe String of (usually) either span (Def) or div
  #
  # @example
  #   ary = tag_pair_span(tag_class: "moderator_only") # defined in application_helper.rb
  #
  # @param tag_class: [String] String of CSS class(es) like "editor_only my_class1"
  # @param tag: [String] HTML tag (Def: "span")
  # @return [Array<String>] 
  def tag_pair_span(tag_class: "editor_only", tag: "span")
    safe_tag = (tag.html_safe? ? tag : ERB::Util.html_escape(tag))
    raise if (tag.blank? || /\A[a-z0-9_]+\z/i !~ tag)
    raise if (tag_class.present? && /[<>]/ =~ tag_class)
    safe_tag_class = (tag_class.html_safe? ? tag_class : ERB::Util.html_escape(tag_class)) if tag_class
    s = "<" + safe_tag + (tag_class.present? ? " class=\"#{safe_tag_class}\"" : "") + ">"
    outer_span_pair = [s]
    outer_span_pair << (outer_span_pair[0].present? ? "</#{safe_tag}>" : "")
    outer_span_pair.map(&:html_safe)
  end

  # sorted Array ignoring the differences between lower-upper-case letters and hiragana and katakana
  #
  # @note
  #   If you use this in a class definition in ApplicationGrid, you perhaps need to
  #   explicitly specify +langcode: I18n.locale+ in the Proc in the caller.
  #   Otherwise, "en" would be used.  Be warned!
  #
  # @param ary [Relation, Array<BaseWithTranslation>]
  # @return [Array<String, Integer>]
  def sorted_title_ids(ary, **opts)
    hsopts = {langcode: I18n.locale, lang_fallback_option: :either}.merge opts
    ary.map{|i|
      str = i.title_or_alt(**opts)
      [str.tr('ア-ンA-Z', 'あ-んa-z'), str, i.id]
    }.sort{|a,b| a[0] <=> b[0]}.map{
      |j| j[1..2]
    }
  end

  # Returns "0.0" or "1.0" or "0.33" (neither "1.00" nor "0.3333")
  #
  # @param num [Numeric, String]
  # @return [String] "" if nil is given.
  def print_1or2digits(num)
    return "" if !num
    fmt = ((num*10 == (num*10).to_i) ? "%3.1f" : "%4.2f")
    sprintf(fmt, num)
  end

  # Returns "0.0" or "1.0" or "0.33" (neither "1.00" nor "0.3333")
  #
  # NOTE: If the given number is over 0 or negative, this returns "".
  #
  # @param num [Numeric, String]
  # @return [String] "" if nil is given.  Examples: " 0%", " 1%", "23%", "100%"
  def print_percent_2digits(num)
    return "" if !num || num < 0 || num > 1
    sprintf("%3d%%", num*100).sub(/^\s/, "")
  end

  
  # Returns I18n Period range (in Date) string from Date
  #
  # @param date_from [Date]
  # @param date_to [Date]
  # @param langcode: [String, Symbol] Default: +I18n.locale+
  # @param undefined_period_str: [Object] when a period is basically undefined (from too early in date to too late), this Object is returned (Def: "").
  # @return [String]
  def period_date2text(date_from, date_to, langcode: I18n.locale, undefined_period_str: "")
    period_strs = [date_from, date_to].map{ |ed|
      date2text(ed.year, ed.month, ed.day, langcode: langcode, lower_end_str: "", upper_end_str: "") # defined in module_common.rb
    }

    return undefined_period_str if period_strs.all?(&:blank?)

    range_separator = (("ja" == langcode.to_s) ? " 〜 " : " &ndash; ").html_safe
    period_strs.join(range_separator).html_safe
  end

  # @param record [ActiveRecord, Class<ActiveRecord>, Sombol]
  # @param method: [Symbol, ActiveRecord, Class<ActiveRecord] this can be like :crud or :ud as defined in ability.rb
  # @param permissive: [Symbol] If true (Def), a strange value is allowed, and returns true in that case (to play safe for in cases such that the result is not critical for the Website like for H1 title.  If false, raises an error in such a case.
  # @return [String] html_safe String to display if the page is editor-only? (maybe moderator or admin only)
  def publicly_viewable?(record, method: :show, permissive: true)
    if !record.respond_to?(:attribute_names)  # this should never happen!
      return true if permissive
      raise ArgumentError, "Strange argument to #{File.basename __FILE__}:#{__method__} of [record, method]=#{[record, method].inspect}"
    end

    Ability.new(nil).can?(method, record)
  end

  # @param record [ActiveRecord, Class<ActiveRecord>]
  # @param method: [Symbol] this can be like :crud or :ud as defined in ability.rb
  # @return [String] html_safe String to display if the page is editor-only? (maybe moderator or admin only)
  def h1_note_editor_only(record, method: :show)
    return "" if publicly_viewable?(record, method: method, permissive: true)

    ret = '<span class="editor_only text-red">&nbsp;&nbsp;[Editor-only Page]</span>'.html_safe
  end

  # Returns a block of safe-HTML in a div/span of editor/moderator-only IF it is viewable by the user.
  #
  # If the input is not HTML-safe, it is sanitized according to the standard `sanitize` helper
  # (See your initilizer to see the available anchors).
  # The recommended way is to give the content as the ERB block (see an example below).
  # Then, the content is sanitized (or not for the part you choose so) acccording to the ERB standard way.
  #
  # This method is a handy helper for anything related to the Editor-privilege. In particularly
  # this is most useful when you think the component may become public
  # in the future; with this method, the part is guaranteed NOT to be enclosed
  # with the editor-only style once it has become public.
  #
  # @example
  #    <%= editor_only_safe_html(@place, method: :edit, tag: "span", class: "lead", title: "not for public") do %>
  #      <%= link_to 'Edit', edit_place_path(@place) %>
  #      <br>
  #    <% end %>
  #
  # @example
  #    can_index = can?(:index, Event)
  #    editor_only_safe_html(:pass, can_index, text: link_to(t('layouts.back_to_index'), placec_path)+"<br>".html_safe)
  #
  #
  # @param record [ActiveRecord, Class<ActiveRecord>, Symbol] If Symbol of :pass, the Boolean value of the method is used for ability check.
  # @param method: [Symbol, Boolean] Mandatory, unlike {#publicly_viewable?}. This can be like :crud or :ud as defined in ability.rb .  Or, if +record+ is :pass, this Boolean value is used and detailed ability check is skipped, and the unauthenticated is assumed to be prohibited to access.
  # @param tag: [String] "div"(Def) or "span". Or, "p" if you want.  (For developers: the namespace collides with the default helper method +tag+ inside this method, so be careful!)
  # @param class: [String] space-separated CSS classes for the tag.
  # @param only: [Symbol, String] If Symbol like :editor, "editor_only" is the CSS class. Or you can explicitly specify the CSS class in String.
  # @param text: [String, NilClass] you can supply the enclosed text either with this argument or through yield.
  # @param permissive: [Boolean] Default is false, unlike {#publicly_viewable?}.  Use so unless the permission is not a big-deal one.
  # @param opts: [Hash] Any additional parameters (e.g., "title") are passed to ApplicationController.helpers.tag
  # @return [String] html_safe String to display if the page is editor-only? (maybe moderator or admin only)
  # @yield Returned text will be inside the block.
  def editor_only_safe_html(record, method:, tag: "div", class: "", only: :editor, text: nil, permissive: false, **opts)
    if !permissive
      if !((:pass == record && [true, false, nil].include?(method)) || 
           (record.respond_to?(:attribute_names) && method.is_a?(Symbol)))
        msg = "ERROR(#{__method__}): Wrong argument: [record, method]=#{[record, method].inspect}"
        logger.error msg
        raise ArgumentError, msg
      end
    end

    return "" if (:pass == record && !method) || (:pass != record && !can?(method, record))

    html_classes = [(obj=binding.local_variable_get(:class)).present? ? obj : nil].compact

    # Adds "editor_only" to the output CSS
    if (:pass == record && method) || !publicly_viewable?(record, method: method, permissive: permissive)
      html_classes.push(only.is_a?(Symbol) ? (only.to_s+"_only") : only)  # no need of h() or sanitize because the tag helper takes care of it.
    end

    if block_given?
      warn "WARNING(#{__method__}): Argument text is ignored as a block is also given." if text.present?
      text = capture{(s=yield); s.html_safe? ? s : sanitize(s)}  ## NOTE: capture{}  is the key!!  sanitize() is unnecessary for the ERB block but maybe is for a direct block input.
    elsif !text.respond_to?(:html_safe?)
      raise ArgumentError, "text must be a String, be it a direct argument or yield block."
    end

    text = sanitize(text) if !text.html_safe?  # capture-d text seems always html_safe. However, text passed as an argument may not be.
    # Note: Array#html_safe? exists but Array#html_safe does not, and raises NoMethodError  

    ApplicationController.helpers.tag.send(tag, text, class: html_classes, **opts)
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
