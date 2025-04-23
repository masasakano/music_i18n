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

  module ClassMethods
  end

  module_function

  # Returns the "normalized" URL/URI.
  #
  # "Normalized" is used for searching purposes only. No guarantee that the normalized URL is acutally network-reachable.
  #
  # Prefix "https" is allowed, but removed on return in default.
  # The prefix "www." is removed on return unless the input is totally invalid as a URI (like "www.x")
  # The host part is down-cased.
  # Port number is allowed, but removed on return.
  # A trailing forward slash is allowed, but removed on return unless it has significant queries or fragments or unless it is an invalid URI (like "www.x/abc/").
  # Queries and fragments are preserved.
  #
  # For :youtube, "youtu.be" is returned.
  #
  # @example
  #   "example.com/abc?q=1&r=2#xyz" == Url.self.normalized_url("ftp://www.example.com/abc?q=1&r=2#xyz")
  #
  # @param with_scheme: [Boolean] If true (Def: false), "http(s?)://" or "ftp://" remains.
  # @param with_www: [Boolean] If true (Def: false), the initial "www." remains (if the input has it).
  # @param with_extra_trailing_slash: [Boolean] If true (Def: false), the extra surplus forward slash between the host and domain when the URL contains only the domain with no path, query, or fragment remains. Else removed.  Extra multiple forward slashes there and tail of the path are always removed. This is ignored and forcibly true if with_path is true.
  # @param with_path: [Boolean] If true (Def), the path part (like +abc/def.html+) remains.  I am not sure how the prefix forward slash remains or not. In specifying false, make sure to specify +delegate_special: false+ ; in which case with_query and with_fragment are ignored and treated as false.
  # @param with_query: [Boolean] If true (Def), the query part remains.
  # @param with_fragment: [Boolean] If true (Def), the fragment part (like "#my_name" at the tail) remains.
  # @param delegate_special: [Boolean] If true (Def), handling of some domains (particularly Youtube) are delegated to other routines, where the options above are basically ignored!
  # @return [String, NilClass] normalized URL String. In an unlikely case of null String, nil is returned.
  def normalized_url(url_in, with_scheme: false, with_www: false, with_port: false, with_extra_trailing_slash: false, with_path: true, with_query: true, with_fragment: true, delegate_special: true)
    return if !url_in

    # Gets a valid URI with "https://" or a scheme (if it appears to be valid)
    # In fact, this calls the URI module, so there is an overhead.
    url = scheme_and_uri_string(url_in).join
    return url if url.blank?

    if delegate_special && :youtube == ApplicationHelper.guess_site_platform(url)
      return ApplicationHelper.normalized_uri_youtube(url, long: false, with_scheme: false, with_host: true, with_time: false, with_query: true).sub(%r@/+$@, "")
    end

    u2 = URI.parse(url)
    return url if u2.host.blank?  # invalid URI

    url = ""
    url << u2.scheme << "://" if with_scheme && u2.scheme.present?
    host = u2.host.downcase
    url << (with_www ? host : host.sub(/\Awww\./, ""))
    url << (with_port ? ":#{u2.port}" : "")

    return url if !with_path

    # u2.path seems complicated!! It sometimes has a prefix of "/" but sometimes does not!
    if u2.path.present?
      path = u2.path.sub(%r@/+\Z@, "/")
      if with_extra_trailing_slash || %r@[^/]@ =~ path || u2.query.present? || u2.fragment.present?
        url << "/" + path.sub(%r@\A/+@, "")
      end
    elsif (u2.query.present? || u2.fragment.present?)  # should neer happen?
      url << "/"
    end

    url << "?" << u2.query    if u2.query.present?    && with_query
    url << "#" << u2.fragment if u2.fragment.present? && with_fragment
    url
  end # def normalized_url(url_in)


  # Returns 3-element Array of a network scheme (like "https") and that without it
  #
  # The first element may be blank ("").
  # The second element is a separator ("://"), which is blank if the first element is blank.
  # The third element is guaranteed to have no scheme.
  #
  # If the input has no "https://" but appears to be a valid URI other than that,
  # the prefix "https://" is assumed.
  #
  # @note
  #    Core part of the regular expression for a valid domain: {Domain::REGEXP_DOMAIN_CORE_STR}
  #
  # @example
  #    valid_uri = scheme_and_uri_string("example.com/abc?q=").join
  #
  # @param uri_str [String] URI-like String with/without a scheme part
  # @return [Array[String]] 3-element; e.g., ["https", "://", "example.com/abc?q=5#xyz"]
  def scheme_and_uri_string(uri_str)
    return ["", ""] if uri_str.blank?
    uri = uri_str.strip
    u1 = URI.parse(uri)
    return [u1.scheme, "://", uri.sub(/\A#{Regexp.quote(u1.scheme+"://")}/, "")] if u1.scheme.present?

    return ["", "", uri] if Domain::REGEXP_DOMAIN !~ uri.sub(%r@/.*@, "")
    
    ["https", "://", uri]
  end

  # Returns a URL-String with a guaranteed scheme, as long as its Domain is valid.
  #
  # This always returns String even if the input is nil.
  #
  # @param url [Url, String, NilClass]
  # @return [String]
  def url_prepended_with_scheme(url)
    urlstr = (url.respond_to?(:url) ? url.url : url).to_s.strip
    return urlstr if urlstr.empty?
    scheme_and_uri_string(urlstr).join
  end

  #################
  private 
  #################

end
