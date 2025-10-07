# coding: utf-8

require 'test_helper'

class ModuleCommonTest < ActiveSupport::TestCase

  test "css_for_flash" do
    exp = "div#body_main div#error_explanation.notice.alert.alert-info, div#body_main div.error_explanation.notice.alert.alert-info"
    assert_equal exp, css_for_flash(:notice, category: :error_explanation)

    exp = "div.invalid-feedback, div#body_main div.alert.alert-warning a em, div#body_main div#error_explanation.alert.alert-warning a em"
    assert_equal exp, css_for_flash(:warning, category: :both, extra: "a em")

    exp = "div#body_main div.alert.alert-danger.cls1.cls2, div#body_main div.alert.alert-success.cls1.cls2"
    assert_equal exp, css_for_flash([:alert, :success], category: :div, extra_attributes: ["cls1", "cls2"])
  end

  test "xpath_for_flash" do
    exp = "//div[@id='body_main']/div[@id='error_explanation'][contains(@class, 'notice')][contains(@class, 'alert')][contains(@class, 'alert-info')][1]"
    assert_equal exp, xpath_for_flash(:notice, category: :error_explanation)

    exp = "//div[@id='body_main']/div" +                     "[contains(@class, 'alert')][contains(@class, 'alert-warning')]//a//em[1]" +
         "|//div[@id='body_main']/div[@id='error_explanation'][contains(@class, 'alert')][contains(@class, 'alert-warning')]//a//em[1]"
    assert_equal exp, xpath_for_flash(:warning, category: :both, extras: %w(a em))

    exp = "//div[@id='body_main']/div[contains(@class, 'alert')][contains(@class, 'alert-danger')][contains(@class, 'cls1')][contains(@class, 'cls2')][1]" +
         "|//div[@id='body_main']/div[contains(@class, 'alert')][contains(@class, 'alert-success')][contains(@class, 'cls1')][contains(@class, 'cls2')][1]"
    assert_equal exp, xpath_for_flash([:alert, :success], category: :div, extra_attributes: ["cls1", "cls2"])
  end

  test "recognize_path_with_static_page" do
    exp = {controller: "places", action: "index"}
    assert_equal exp, recognize_path_with_static_page("/places")

    assert_raises(ActionController::RoutingError){
      recognize_path_with_static_page("/non_existent", method: "POST")
    }
  end
end

