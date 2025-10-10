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
    @trans_moderator = users(:user_moderator_translation)  # Translator-moderator cannot create/edit/delete.
    @moderator_ja    = users(:user_moderator_general_ja)  # Same as Translator.
  end

  test "visiting PlayRole index" do
    ## Gets the sign-in path.
    visit new_user_session_path
    path2signin = current_path

    ## Visits PlayRole#index => redirected to Sign-in
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
    assert_index_fail_succeed(new_play_role_url, h1_title="New PlayRole", user_fail: @trans_moderator, user_succeed: @syshelper)  # defined in test_system_helper.rb

    assert_text "conductor" # inside a table
    assert_equal "unknown", find(:xpath, "//table//tr[last()]//td[2]").text, "reference table should have been sorted by weight, but..."
    assert_equal 999,       find(:xpath, "//table//tr[last()]//td[3]").text.to_f.to_i
    fill_in "Mname", with: "naiyo12"
    fill_in "Weight", with: 41.3
    fill_in "Note", with: ""
    click_on "Create Play role"

    assert_text "PlayRole was successfully created"
    assert_find_destroy_button  # This has no dependent children, hence destroyable.  # defined in test_system_helper.rb

    click_on "Back"

    assert_equal n_models+1, PlayRole.count
  end

  test "should update PlayRole" do
    n_models = PlayRole.count

    assert_index_fail_succeed(play_role_url(@play_role), "PlayRole", user_fail: @trans_moderator, user_succeed: @syshelper)  # defined in test_system_helper.rb
    
    visit play_role_url(@play_role)
    assert_text "Edit this PlayRole"
    click_on "Edit this PlayRole", match: :first

    assert_text "conductor" # inside a table
    fill_in "Mname", with: @play_role.mname
    fill_in "Weight", with: 123456.7
    fill_in "Note", with: @play_role.note
    click_on "Update Play role"

    assert_text "PlayRole was successfully updated"
    assert @play_role.artist_music_plays.exists?, "sanity check."
    assert_find_destroy_button(should_succeed: false)  # because of dependent children

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
