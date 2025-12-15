require 'nokogiri'

module SnapshotHelper
  # Takes either a CSS or XPath selector or a Capybara element and returns a static,
  # queryable Nokogiri element. This snapshot is unaffected by future DOM changes.
  #
  # This module is assumed to be used in the context of Capybara system tests.
  #
  # @example  XPath selector
  #    capture_nokogiri_snapshot("//table//tbody//tr")
  #
  # @example  Capybara (page.)find (or find_all()[x] (or all()[x]), associated with [x])
  #    capture_nokogiri_snapshot(find(:xpath, "//table//tbody//tr"))
  #
  # @param capybara_element [String, Capybara::Node::Element] Either CSS/XML selector String or
  #    the result of +page.find+, but NOT +Capybara::Result+ as in the result of +page.find_all+
  #    because it is a little tricky and awkward to builde a Nokogiri::XML::NodeSet (or
  #    Nokogiri::HTML::Document) from an Array-like +Capybara::Result+
  # @return [Nokogiri::XML::NodeSet] A Nokogiri fragment containing the element
  def capture_nokogiri_snapshot(selector_ish)
    if selector_ish.respond_to? :gsub
      capture_nokogiri_snapshot_from_selector(selector_ish)
    elsif selector_ish.respond_to? :evaluate_script  # Capybara::Node::Element]
      # Using .fragment is best for snippets that (likely) don't include <html> or <body> tags.
      Nokogiri::HTML.fragment( selector_ish["outerHTML"] )
    else
      raise ArgumentError, "Wrong input (maybe the returned value of find_all()(?))"+selector_ish.inspect
    end
  end

  # Takes a selector, gets the entire page HTML, parses it into a Nokogiri document,
  # and returns the NodeSet matching the selector.
  #
  # This conversion is necessary to store a snapshot of HTML because Capibara's
  # +page.find+ or +page.find_all+ are a kind of skeleton, the contents of which
  # change as soon as a different page is loaded.
  #
  # @param selector [String] The CSS or XPath selector to locate elements.
  # @return [Nokogiri::XML::NodeSet] A single NodeSet representing the matches found in the static full page snapshot.
  def capture_nokogiri_snapshot_from_selector(selector)
    metho =
      if selector.start_with?("/", ".//")
        page.find_all :xpath, selector  # Without this, the element searched for may have not been fully loaded when page.html is run below.
        :xpath
      else
        page.find_all selector
        :css
      end

    document = Nokogiri::HTML(page.html).public_send(metho, selector)
  end
end
