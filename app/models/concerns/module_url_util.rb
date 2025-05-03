# -*- coding: utf-8 -*-
# require "unicode/emoji"

# Utility module related to handling of URIs/URLs
#
# @example
#   include ModuleUrlUtil
#
# == NOTE
#
module ModuleUrlUtil
  #def self.included(base)
  #  base.extend(ClassMethods)
  #end
  extend ActiveSupport::Concern  # In Rails, the 3 lines above can be replaced with this.

  # extend ModuleApplicationBase
  # extend ModuleCommon

  # Original is obsolete, because this does not support Internationalized Domain Names (IDNs)
  #
  # String expression of the core part of Regular expression of a Domain
  # c.f., https://stackoverflow.com/questions/1128168/validation-for-url-domain-using-regex-rails/16931672
  #REGEXP_DOMAIN_CORE_STR = "(?-mix:[a-z0-9]+([\\-\\.]{1}[a-z0-9]+)*\\.[a-z]{2,63})"
  #
  # I modified it to accept the per-cent format (with 2 capital letters or numbers) and
  # also the purely-number IP-address format (though loosely).
  # Basically, "http://localhost" is rejected, while "お名前.com" or "123.45.67.89" is accepted.
  REGEXP_DOMAIN_CORE_STR = "(?-mix:([a-z0-9]|%[0-9A-F]{2})+([\\-\\.]{1}([a-z0-9]|%[0-9A-F]{2})+)*\\.(?:[a-z]{2,63}|[0-9][0-9]{1,2}))"

  # [Obsolete] (see above) Regular expression of a Domain to be saved in DB
  REGEXP_DOMAIN = /\A#{REGEXP_DOMAIN_CORE_STR}\z/

  module ClassMethods
  end

  module_function

  # Returns the "normalized" URL/URI from an input with/without a scheme (like "https").
  #
  # "Normalized" is used for searching purposes only. No guarantee that the normalized URL is acutally network-reachable.
  #
  # Prefix "https" is allowed, but removed on return in default.
  # The prefix "www." is removed on return unless the input is totally invalid as a URI (like "www.x")
  # The host part is down-cased.
  # Port number is allowed, but removed on return.
  # A trailing forward slash is allowed, but removed on return unless it has significant queries or fragments or unless it is an invalid URI (like "www.x/abc/").
  # Queries and fragments are preserved.
  # IDNs and international characters in other parts are all decoded.
  #
  # For :youtube, "youtu.be" is returned.
  #
  # @example
  #   "example.com/abc?q=1&r=2#xyz" == Url.self.normalized_url("ftp://www.example.com/abc?q=1&r=2#xyz")
  #
  # @param url_in: [String, NilClass] With or without a scheme.
  # @param with_scheme: [Boolean] If true (Def: false), "http(s?)://" or "ftp://" remains.
  # @param with_www: [Boolean] If true (Def: false), the initial "www." remains (if the input has it).
  # @param with_port: [Boolean] If true (Def: false), port part is added like ":8080"
  # @param trim_insignificant_prefix_slash: [Boolean] If true (Def), the multiple forward slashes at the head of the path are always truncated and are maybe even removed IF there is no significant query or fragment to return (e.g., with_query=false and with_fragment=false or when simply no such things are in the input). If with_path==false, this is ignored and treated as true always.
  # @param with_path: [Boolean] If true (Def), the path part (like +abc/def.html+) remains.  I am not sure how the prefix forward slash remains or not. In specifying false, make sure to specify +delegate_special: false+ ; in which case with_query and with_fragment are ignored and treated as false.
  # @param truncate_trailing_slashes: [Boolean] If true (Def: true), the multiple slashes at the tail of the path is truncated to one.
  # @param with_query: [Boolean] If true (Def), the query part remains. Disabled if with_path==false. Note that an empty query is always removed.
  # @param with_fragment: [Boolean] If true (Def), the fragment part (like "#my_name" at the tail) remains. Disabled if with_path==false. Note that an empty fragment is always removed.
  # @param decode_all: [Boolean] If true (Def), IDNs and international characters in other parts are all decoded.
  # @param downcase_domain: [Boolean] If true (Def), Domain part is downcased except for the IDN part.
  # @param delegate_special: [Boolean] If true (Def), handling of some domains (particularly Youtube) are delegated to other routines, where the options above are basically ignored!
  # @return [String, NilClass] normalized URL String. In an unlikely case of null String, nil is returned.
  def normalized_url(url_in,
                     with_scheme: false,
                     with_www: false,
                     with_port: false,
                     trim_insignificant_prefix_slash: true,
                     with_path: true,
                     truncate_trailing_slashes: true,
                     with_query: true,
                     with_fragment: true,
                     decode_all: true,
                     downcase_domain: true,
                     delegate_special: true)

    with_query = with_fragment = false if !with_path

    return if !url_in

    # Gets a valid URI with "https://" or a scheme (if it appears to be valid)
    uri = get_uri(url_in)
    return if uri.blank?
    return url_in.strip if uri.host.blank? || !valid_domain_like?(uri.host)  # invalid URI;  NOT decoded/unencoded, but as it is

    if delegate_special && :youtube == ApplicationHelper.guess_site_platform(uri.to_s)
      return ApplicationHelper.normalized_uri_youtube(uri.to_s, long: false, with_scheme: false, with_host: true, with_time: false, with_query: true).sub(%r@/+$@, "")
    end

    urlstr = ""
    urlstr << uri.scheme << "://" if with_scheme && uri.scheme.present?
    host =
      if decode_all
        Addressable::URI.unencode(encoded_case_sensitive_domain(uri.host, downcase: downcase_domain))
      else
        (downcase_domain ? downcased_domain(uri.host) : uri.host)
      end

    urlstr << (with_www ? host : host.sub(/\Awww\./, ""))
    urlstr << ((with_port && uri.port.present?) ? ":#{uri.port}" : "")  # port is Integer

    return urlstr if !with_path

    tails = []
    tails.push("?" + uri.query)    if uri.query.present?    && with_query
    tails.push("#" + uri.fragment) if uri.fragment.present? && with_fragment

    # "x.com/" => path of "/"; "x.com" => path of "" (it may be nil IF it is not a http(s) or invalid)
    if uri.path.present?
      path = uri.path
      path = path.sub(%r@/+\Z@, "/") if truncate_trailing_slashes
      path = path.sub(%r@\A/+@, "/") if trim_insignificant_prefix_slash
      path = ""       if "/" == path && trim_insignificant_prefix_slash && tails.empty?
      urlstr << path
    elsif !tails.empty?
      urlstr << "/"
    #elsif (uri.query.present? || uri.fragment.present?)  # should never happen?
    #  urlstr << "/"
    end

    urlstr << tails.join("") 

    #urlstr << "?" << uri.query    if uri.query.present?    && with_query
    #urlstr << "#" << uri.fragment if uri.fragment.present? && with_fragment
    decode_all ? Addressable::URI.unencode(urlstr) : urlstr
  end # def normalized_url(url_in)

  # true if it looks like a valid URL with/without a scheme ("https://")
  # 
  # A valid URI may not be a web-based valid URL like:
  # https://stackoverflow.com/a/16359999/3577922
  # 
  #    "urn:isbn:0451450523" =~ URI::regexp  # => 0
  #
  # In contrast, "www.example.com" is NOT a valid URL/URI on its own.
  # But this returns true.
  #
  # @note
  #   The traditional URI raises URI::InvalidURIError in encountering non-ASCII
  #   characters, but Addressable::URI is fine.
  #   Also, Addressable::URI.unencode can decode the entire URL, whereas URI.decode_www_form_component cannot.
  #
  # @param uri_str [String, URI]
  # @return [Boolean]
  def valid_url_like?(uri_in)
    uri = (uri_in.respond_to?(:scheme) ? uri_in : get_uri(uri_in))
    return false if uri.blank? || uri.scheme.blank? || uri.host.blank?

    valid_domain_like?(uri.host)
  end

  # Check with the decoding String
  #
  # If the path (or query or fragment) part is included (except for the preceding single forward slash),
  # false is returned.
  #
  # To check, the domain part is downcased except for the encoded part, which is upcased.
  #
  # @param domain_str [String] e.g., "www.example.com"
  # @return [Boolean]
  def valid_domain_like?(domain_str)
    uri = get_uri(domain_str)  # returns {#blank?} if domain_str is blank? or very wrong.
    return false if uri.blank? || uri.scheme.blank? || uri.host.blank?
    return false if uri.query.present? || uri.fragment.present? || (uri.path.present? && "/" != uri.path)

    !!(REGEXP_DOMAIN =~ encoded_case_sensitive_domain(uri.host))
  end

  # Encodes the Domain-part string where all are downcased except for the encoded parts, which are upcased.
  #
  # @param domain_str [String]
  # @param downcase: [Boolean] if true (Def), the domain is downcased except for the IDN part.
  # @return [Boolean]
  def encoded_case_sensitive_domain(domain_str, downcase: true)
    ret = encoded_urlstr_if_decoded(domain_str)
    return ret if !downcase
    ret.downcase.gsub(/%([a-f0-9]{2})/){'%'+$1.upcase}
  end

  # Domain-part string downcased except for the already encoded parts, which are untouched.
  #
  # @param domain_str [String]
  # @return [Boolean]
  def downcased_domain(domain_str)
    domain_str.gsub(/(?<!%|%[0-9A-Fa-f])([A-Z])/){|a| $&.downcase}
  end

  # Returns Addressable::URI object for any String input.
  #
  # As long as the given String constitutes a valid URI (if maybe without a scheme), 
  # for the returned object "ret", +ret.scheme+ is guaranteed to exist (Default: "https").
  # If the String is invalid as a URL, maybe the given String == +ret.path+ while
  # +ret.scheme+ and +ret.host+ are nil.
  #
  # Be warned that a valid URI does not always constitute a valid URL,
  # especially a URI over the Internet!
  #
  # For example +urn:isbn:0451450523+ is a valid URI (or the scheme +urn+), but it is
  # nothing like a URL.  Or, "file:///home/name/abc" is a valid URI.  Or,
  # "http://localhost" is a valid URI and (I think) URL).  However, it should be
  # invalid in this framework's context because it is not an Internet-valid URL.
  #
  # In other words, you can check whether the String looks like a valid URL by
  # checking:
  #    "Path_is_valid" if ret.scheme.present?
  #
  # for these reason, use {#valid_url_like?} or {#valid_domain_like?} for validity checking.
  #
  # Note that another tricky part with Addressable::URI, which assumes the URL (not quite URI!) is associated
  # with a scheme, is this. The scheme below is wrongly interpreted!  This method takes care of such cases.
  #
  #    Addressable::URI.parse("www.example.com:80/").scheme
  #    # => "www.example.com"
  #
  # ## Algorithm
  #
  # This first tries to parse the raw given String (though stripped) with 
  # Addressable::URI.  Although the result can be very wrong, a proper URL-look
  # String should be somehow parsed.  If it raises the Exception (Addressable::URI::InvalidURIError),
  # this method returns nil as it means the input String is very wrong, except for
  # the cases like "www.お名前.com:80/abc" with an IDN with a port but without a scheme.
  #
  # Then, this method prepends the scheme (https://) if necessary and parses it with
  # Addressable::URI.  If both the scheme and host are present, this returns the value (Addressable::URI).
  # Addressable::URI.  If not, the original parse result is returned.
  #
  # @note
  #    Core part of the regular expression for a valid domain used to be {Domain::REGEXP_DOMAIN_CORE_STR}
  #    However, it does not consider Internationalized Domain Names (IDNs), so it is not used anymore.
  #
  # @note
  #    {ApplicationHelper.parsed_uri_with_or_not} does a similar job, technically.
  #
  # @param uri_str [String] URI-like String with/without a scheme part
  # @return [Addressable::URI, NilClass] trimmed. nil if either the input is nil or the given String
  #    is so invalid to the extent to raise Addressable::URI::InvalidURIError .
  #    If the input is /^\s+$/, return is {Addressable::URI#blank?} == true
  def get_uri(uri_str)
    return nil if uri_str.nil?
    uri_with_scheme = uri_str = uri_str.strip
    uri_with_scheme = "https://"+uri_str if (uri_str.present? && %r@\A[a-z][a-z0-9]+://@ !~ uri_str)

    skip_first = false
    if %r@\A[^:/]+\.(?:[a-z]{2,63}|[1-9]\d{0,2}):\d+(/|$)@ =~ uri_str  # see REGEXP_DOMAIN_CORE_STR
      ret_bkup = nil  # parse would raise Addressable::URI::InvalidURIError
    else
      begin
        ret_bkup = Addressable::URI.parse(uri_str)
      rescue Addressable::URI::InvalidURIError
        return nil
      end
      return ret_bkup if ret_bkup.blank?  # aka if the input String is blank?
    end

    begin
      ret = Addressable::URI.parse(uri_with_scheme)
    rescue Addressable::URI::InvalidURIError
      return nil
    end

    (ret.scheme.present? && ret.host.present?) ? ret : ret_bkup 
  end

  # Returns a URL-String with a guaranteed scheme, as long as its Domain is valid.
  #
  # This always returns String even if the input is nil.
  #
  # @param url [Url, String, NilClass]
  # @param invalid: [NilClass, String<"">, Symbol<:original>] One of nil, "", and :original .
  #    In default (:original), when the input url does not look like a valid URL, this method makes
  #     the best effort and returns a strip-ped given String.
  #    If nil or "", nil or "", respectively, is returned in such a case.
  # @return [String] or nil if (invalid: nil) (NOT default)
  def url_prepended_with_scheme(url, invalid: :original)
    urlstr = (url.respond_to?(:url) ? url.url : url).to_s.strip
    uri = get_uri(urlstr)
    return uri.to_s if valid_url_like?(uri)

    case invalid
    when :original
      urlstr
    when ""
      ""
    when :nil
      warn "WARNING: ':nil' is wrong. You should specify nil. Here :nil is interpreted as nil temporarily."
      nil
    when nil
      nil
    else
      raise ArgumentError, "(#{File.basename __FILE__}:{__method__}): Wrong 'invalid' is given: #{invalid.inspect}"
    end
  end

  # Extracts all the URL-like Strings, returning Array of valid URL-String and its original String.
  #
  # Each element in the returned Array is a pair of Array of Strings, consisting of
  # a "valid" Internet URL prefixed with a scheme (usually "https://") and its raw-extracted String.
  #
  # Note that there can be a duplication even in the second element, let alone the first element of the pairs.
  #
  # @example
  #    extract_url_like_string_and_raws("x\nhttp://example.com\nyoutu.be/XXX?t=53 [https://naiyo] (www.abc.org/?q=1#X) http://t.co/#X")
  #      # => [["http://example.com",        "http://example.com"],
  #      #     ["https://youtu.be/XXX?t=53",  "youtu.be/XXX?t=53"],
  #      #     ["https://www.abc.org/?q=1#X", "www.abc.org/?q=1#X"],
  #      #     ["http://t.co/#X",             "http://t.co/#X"]]
  #
  # @return [Array<String, String>] [[<Proper-URL-String>, <Raw-String>], ...]
  def extract_url_like_string_and_raws(strin)
    extract_raw_url_like_strings(strin).map{|es|
      (s=url_prepended_with_scheme(es, invalid: nil)) ? [s, es] : nil
    }.compact
  end


  # Each element in the returned Array is a "raw" String which has no guarantee to be a valid URL.
  #
  # Note that this extracts Strin starting with "www."
  # As an exception, this extracts String like "youtu.be/XXX" or "youtube.com/XXX" (but NOT "youtu.be/" alone).
  # The preceding characters are checked; "xyoutu.be/XXX" or "x.youtu.be/XXX" would be rejected.
  #
  # This also removes the links in Markdown or in <a> tags, as they should stay in note
  # and not be transferred to Url.
  #
  # @param strin [String, NilClass]
  # @return [Array<String>] e.g., ["http://example.com", "youtu.be/XXX?t=53", "https://naiyo", "www.abc.org/?q=1#X" "http://t.co/#X"]
  def extract_raw_url_like_strings(strin)
    return [] if !strin
    renderer = Redcarpet::Render::HTML.new(prettify: true)
    markdown = Redcarpet::Markdown.new(renderer, {autolink: true})
  
    mded_str = ActionController::Base.helpers.strip_tags( markdown.render(strin) ).gsub(/(\?[a-z]\S*=\S*)&amp;/i, '\1&').gsub(/\\n/, "\n")
    mded_str.scan(%r@(?:(?:\b(?:https?|s?ftp))://|(?<=^|[<\[\(\s])(?:www\.|youtube\.com/|youtu.be/))[^>\)\]\s]+(?=[>\)\]\s]|$)@m)
  end

  # @note
  #   The traditional URI raises URI::InvalidURIError in encountering non-ASCII
  #   characters, but Addressable::URI is fine.
  #   Also, Addressable::URI.unencode can decode the entire URL, whereas URI.decode_www_form_component cannot.
  #
  # @return [String] Encoded URL-string only if it has been decoded.
  def encoded_urlstr_if_decoded(urlstr)
    (/%[a-f0-9]{2}/i =~ urlstr) ? urlstr : Addressable::URI.encode(urlstr)
  end

  #################
  private 
  #################

end
