# coding: utf-8
require "application_system_test_case"

class EngageHowsTest < ApplicationSystemTestCase
  setup do
    #@engage_how = engage_hows(:one)
    @sysadmin = users(:user_sysadmin)
  end

  test "visiting the index and creating" do
    visit new_user_session_path
    fill_in "Email", with: @sysadmin.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"
    # assert_response :redirect  # NoMethodError
    assert_selector "h1", text: "HARAMIchan"

    visit engage_hows_url
    assert_selector "h1", text: "EngageHows"

    click_on "Create New EngageHow"
    assert_text "New EngageHow"
    assert_selector "h1", text: "New EngageHow"

    fill_in "Note", with: 'create test01'
    click_on "Create EngageHow"

    # assert_response :unprocessable_entity # invalid in system tests.
    assert_text "must exist"

    newname = 'ある名前t02'
    #find_field("EngageHow正式名称", match: :first).fill_in with: newname
    find_field("EngageHow Full Title", match: :first).fill_in with: newname
    # all('input.required').first.set newname  ## an alternative way... but this does not work!
    fill_in "Note", with: 'create test02'
#take_screenshot
    click_on "Create EngageHow"
    assert_text "was successfully created"  ## For some reason, it raises an error of "At least either of Title and AltTitle must exist." despite the fact the screenshot shows a significant title in the field, and indeed, a manual trial works!
    click_on "Back"

    assert_selector "h1", text: "EngageHows"
    assert_text newname
    #assert_selector 'div#div_select_country', text: "Country"
    #assert_selector 'div#div_select_prefecture', visible: :hidden
  end

  #test "updating a Engage how" do
  #  visit engage_hows_url
  #  click_on "Edit", match: :first

  #  fill_in "Note", with: @engage_how.note
  #  click_on "Update Engage how"

  #  assert_text "Engage how was successfully updated"
  #  click_on "Back"
  #end

  #test "destroying a Engage how" do
  #  visit engage_hows_url
  #  page.accept_confirm do
  #    click_on "Destroy", match: :first
  #  end

  #  assert_text "Engage how was successfully destroyed"
  #end
end
