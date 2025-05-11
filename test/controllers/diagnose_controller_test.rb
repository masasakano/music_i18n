# coding: utf-8
require "test_helper"

class DiagnoseControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @url = urls(:one)
    @domain = domains(:one)
    @site_category = site_categories(:one)
    @sysadmin  = users(:user_sysadmin)
    @syshelper = users(:user_syshelper)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @moderator_ja    = users(:user_moderator_general_ja)  # 
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor

    str_form_for_nil = ApplicationController.returned_str_from_form(ApplicationController::FORM_TERNARY_UNDEFINED_VALUE)
    @hs_create_lang = {
      "langcode"=>"ja",
      "title"=>"The Tｅst12",
      "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"",
      "best_translation_is_orig"=>str_form_for_nil,  # radio-button returns "on" for nil
    }.with_indifferent_access
    @hs_base = {
      url: "",  # mandatory
      url_langcode: "",
      domain_id: "",  # mandatory at the model level but not in Controller
      weight: "",
      note: "",
      memo_editor: nil,
    }.merge(
      %w(published_date last_confirmed_date).map{|ew|
        [1,2,3].map{|i| [sprintf("%s(%di)", ew, i), ""]}.to_h  # WARNING: nil instaed of "" would cause a weird Rails-level error of "undefined method `empty?'"
      }.inject({}){|i,j| i.merge j}
    ).with_indifferent_access
    ## NOTE: you may use: ApplicationHelper#get_params_from_date_time
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    get diagnose_index_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor_ja
    get diagnose_index_url
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @translator

    sign_in @moderator_all
    get diagnose_index_url
    assert_response :success
  end
end
