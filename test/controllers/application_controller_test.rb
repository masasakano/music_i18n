# coding: utf-8
require "test_helper"

class UrlsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "self.str_info_entry_page_numbers_core" do
    hstmpl =  {
      n_filtered_entries: 9, cur_page: 1, start_entry: :default, end_entry: nil, n_all_entries: nil, langcode: "en"
    }
    act = ApplicationController.str_info_entry_page_numbers_core(**hstmpl)
    assert_equal "Page 1 (1—9)/9", act
    act = ApplicationController.str_info_entry_page_numbers_core(**(hstmpl.merge({n_all_entries: 256})))
    assert_equal "Page 1 (1—9)/9 [Grand total: 256]", act

    act = ApplicationController.str_info_entry_page_numbers_core(**(hstmpl.merge({n_filtered_entries: 0})))
    assert_equal "Page 1 (0—0)/0", act
  end

end
