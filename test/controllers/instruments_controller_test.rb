# coding: utf-8
require "test_helper"

class InstrumentsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @instrument = instruments(:instrument_uklele)
    @sysadmin  = users(:user_sysadmin)
    @syshelper = users(:user_syshelper)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @moderator_ja    = users(:user_moderator_general_ja)  # Same as Translator.
    # @hs_create_lang = {
    #   "langcode"=>"ja",
    #   "title"=>"The Tｅst7",
    #   "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"",
    # }
    @ar_create_trans = [
      { langcode: "ja",
        title: "The Tｅst7",  # including ZENKAKU
        ruby: "", romaji: "",
        kind: "full",
        is_orig: true,  # is_orig field is disabled for Instrument, so this should be ignored.
        start_year: "", end_year: "",
        is_formal: "true",
        is_official: "true",
        is_true_name:  get_params_from_bool(false),  # ignored
        is_for_record: get_params_from_bool(false),  # ignored
        is_literal:    get_params_from_bool(false),  # defined in test_helper.rb
        is_internal:   get_params_from_bool(false),  # defined in test_helper.rb
        note: "Trans-note Japanese name"
      }.with_indifferent_access,
      { title: "The Test7 in English",
        ruby: "", romaji: "",
        langcode: "en",
        kind: "",  # displayed as "(auto)"
        is_orig: false,  # is_orig field is disabled for Music, so this should be ignored.
        start_year: "", end_year: "",
        is_formal: "true",
        is_official: "true",
        is_true_name:  get_params_from_bool(false),  # ignored
        is_for_record: get_params_from_bool(false),  # ignored
        is_literal:    get_params_from_bool(false),  # defined in test_helper.rb
        is_internal:   get_params_from_bool(false),  # defined in test_helper.rb
        note: "Trans-note English name"
      }.with_indifferent_access
    ]
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    get instruments_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @moderator_harami
    get instruments_url
    assert_response :success
  end

  test "should get new" do
    sign_in @editor_harami
    refute @editor_harami.moderator?
    refute Ability.new(@editor_harami).can?(:read, Instrument)
    get new_instrument_url
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @editor_harami

    sign_in @moderator_harami
    #sign_in @syshelper
    get new_instrument_url
    assert_response :success
  end

  test "should create instrument" do
    hs2pass = { note: "", weight: 54, translations_attributes: @ar_create_trans }.with_indifferent_access
    assert_no_difference("Instrument.count") do
      post instruments_url, params: { instrument: hs2pass }
    end

    [@editor_harami, @trans_moderator].each do |ea_user|
      sign_in ea_user
      assert_no_difference("Instrument.count") do
        post instruments_url, params: { instrument: hs2pass }
      end
      assert_redirected_to root_path
      sign_out ea_user
    end

    sign_in @moderator_harami
    #sign_in @syshelper
    assert_difference("Instrument.count") do
      post instruments_url, params: { instrument: hs2pass }
      assert_response :redirect
    end

    inst_last = Instrument.last_created # defined in application_record.rb
    assert_redirected_to instrument_url(inst_last)
    follow_redirect!
    assert_response :success  # redirect success
    flash_regex_assert(/Instrument was successfully created\b/, "flash message should exist, but...", type: [:success, :notice]) # defined in test_helper.rb

    assert_equal 54, inst_last.weight
    assert  inst_last.translations.pluck(:is_orig).all? { _1.nil? }

    assert_no_difference("Instrument.count") do
      post instruments_url, params: { instrument: { note: "", weight: 12345 } }
    end
    assert_response :unprocessable_content
    flash_regex_assert(/errors? prohibited this [^\s]* from being saved\b/i, "flash message should exist, but...", type: :alert, system_test: false) # defined in test_helper.rb
    flash_regex_assert(/No Translation is\b/i, "flash message should exist, but...", type: :alert, system_test: false) # defined in test_helper.rb
  end

  test "should show instrument" do
    get instrument_url(@instrument)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor_harami
    get instrument_url(@instrument)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @editor_harami

    sign_in @trans_moderator
    get instrument_url(@instrument)
    assert_response :success, "Any moderator should be able to read, but..."
  end

  test "should get edit" do
    sign_in @editor_harami
    get edit_instrument_url(@instrument)
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @editor_harami

    sign_in @moderator_harami
    #sign_in @sysadmin
    get edit_instrument_url(@instrument)
    assert_response :success
  end

  test "should update instrument" do
    patch instrument_url(@instrument), params: { instrument: { note: @instrument.note, weight: 91 } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @trans_moderator
    patch instrument_url(@instrument), params: { instrument: { note: @instrument.note, weight: 91 } }
    assert_response :redirect
    assert_redirected_to root_path
    sign_out @trans_moderator

    sign_in @moderator_harami
    patch instrument_url(@instrument), params: { instrument: { note: @instrument.note, weight: 91 } }
    assert_redirected_to instrument_url(@instrument)
    assert_equal 91, @instrument.reload.weight

    assert_redirected_to instrument_url(@instrument)
  end

  test "should destroy instrument" do
    sign_in @trans_moderator 
    assert_no_difference("Instrument.count") do
      delete instrument_url(@instrument)
      assert_response :redirect
    end
    assert_redirected_to root_path, "Failure in deletion leads to Root-path"
    sign_out @trans_moderator

    sign_in @moderator_harami
    #sign_in @syshelper
    assert_difference("Instrument.count", -1) do
      delete instrument_url(@instrument)
      assert_response :redirect
    end
    assert_redirected_to instruments_url

    assert_no_difference("Instrument.count", "Unknown should not be destroyed by Moderator, but...") do
      delete instrument_url(Instrument.unknown)
      assert_response :redirect
    end
    assert_redirected_to root_path, "Failure in deletion leads to Root-path"
  end
end
