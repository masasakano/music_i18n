# coding: utf-8
require "application_system_test_case"

class PlayRolesTest < ApplicationSystemTestCase
  setup do
    @play_role = play_roles(:play_role_inst_player_main)
    @sysadmin  = users(:user_sysadmin)
    @syshelper = users(:user_syshelper)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @trans_moderator = users(:user_translator)  # Translator cannot create/delete but edit (maybe!).
    @moderator_ja    = users(:user_moderator_general_ja)  # Same as Translator.
  end

  test "visiting the index" do
    ## Gets the sign-in path.
    visit new_user_session_path
    path2signin = current_path

    ## Visits EventItem#index => redirected to Sign-in
    visit play_roles_url
    assert_no_selector 'div#button_create_new_place'
    assert_equal path2signin, current_path, 'Should have been redirected as normal users cannot see PlayRole#index.'
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @moderator_harami.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    assert_selector "h1", text: "PlayRole index"  # should be redirected back to PlayRole#index.
    assert_text "メインゲスト"
    assert_operator page.find_all(:xpath, "//table//tbody//tr").size, :>, 1
  end

  test "should create PlayRole" do
    n_models = PlayRole.count
    visit new_play_role_url  # direct jump -> fail
    refute_text "New PlayRole"
    assert_text "You need to sign in or sign up"

    #visit new_user_session_path  # already on this page.
    fill_in "Email", with: @syshelper.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    visit play_roles_url  # index page
    click_on "New PlayRole"

    assert_text "conductor" # inside a table
    assert_equal "unknown", find(:xpath, "//table//tr[last()]//td[2]").text, "reference table should have been sorted by weight, but..."
    assert_equal 999,       find(:xpath, "//table//tr[last()]//td[3]").text.to_f.to_i
    fill_in "Mname", with: "naiyo12"
    fill_in "Weight", with: 41.3
    fill_in "Note", with: ""
    click_on "Create Play role"

    assert_text "PlayRole was successfully created"
    click_on "Back"

    assert_equal n_models+1, PlayRole.count
  end

  test "should update PlayRole" do
    n_models = PlayRole.count
    visit new_user_session_path
    fill_in "Email", with: @syshelper.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    visit play_role_url(@play_role)
    click_on "Edit this PlayRole", match: :first

    assert_text "conductor" # inside a table
    fill_in "Mname", with: @play_role.mname
    fill_in "Weight", with: 123456.7
    fill_in "Note", with: @play_role.note
    click_on "Update Play role"

    assert_text "PlayRole was successfully updated"
    click_on "Back"
    assert_equal n_models, PlayRole.count
    assert_equal 123456.7, @play_role.reload.weight
  end

  ### not testing for now.
  #test "should destroy PlayRole" do
  #  visit play_role_url(@play_role)
  #  click_on "Destroy this PlayRole", match: :first

  #  assert_text "PlayRole was successfully destroyed"
  #end
end
