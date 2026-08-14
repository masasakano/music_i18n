# coding: utf-8
require 'test_helper'
#require "capybara/minitest"

class StimulusHelperTest < ActionView::TestCase
  HELPER = StimulusHelper

  ## add this
  #include Devise::Test::IntegrationHelpers
  #include Capybara::Minitest::Assertions

  #
  # cf. https://gorails.com/blog/how-to-test-helpers-in-rails-with-devise-current_user-and-actionview-testcase
  def current_user
    @current_user
  end

  # mocking can? in View context
  def can?(*arg)
    Ability.new(@current_user).can?(*arg)
  end

  setup do
    # @current_user = User.first
  end

  teardown do
    Rails.cache.clear
  end

  ### --------------------------

  test "stimulus_controller_block" do
    c_kebab = "cascading-select"
    content_text = "Something..."
    hs_in = {
      select_name: (select_name=:event_id),
      required: false
    }

    act = stimulus_controller_block(
      "cascadingSelect",
      (html="<p>#{content_text}</p>".html_safe),
      values: hs_in,
      actions: (acti="keydown.esc@window->dropdown#close"),
      data: (hs_extra={something_extra: nil}),
      style: (style="color: red;"))
    nodes = Nokogiri::HTML(act).css("div")
    assert_equal 1, nodes.size

    node = nodes.first
    assert_equal c_kebab, node["data-controller"]
    assert_equal select_name.to_s, node["data-#{c_kebab}-select-name-value"]
    assert_nil                     node["data-#{c_kebab}-select-required-value"]
    assert_equal acti,    node["data-action"]
    assert_equal style,   node["style"]
    assert_equal html,         node.inner_html
    assert_equal content_text, node.text
  end

  #   <%= stimulus_controller_block("cascadingSelect",
  #                                  values: {select_name: my_param_name(:event_id), required: false},
  #                                  actions: "keydown.esc@window->dropdown#close",
  #                                  data: {something_extra: nil},
  #                                  style: "color: red;") do %>
  #     <p>Something...</p>
  #   <% end %>
end


