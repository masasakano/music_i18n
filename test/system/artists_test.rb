# coding: utf-8
require "application_system_test_case"

class ArtistsTest < ApplicationSystemTestCase
  setup do
    #@artist = artists(:one)
    @moderator = users(:user_moderator_general_ja)
  end

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
  end

  ### everything listed here is tested in ./artists/merges_test.rb
  #test "visiting the index and then move to new" do
  #  # Artist#index
  #  visit artists_url
  #  assert_selector "h1", text: "Artists"
  #  assert_no_selector 'form.button_to'  # No button if not logged-in.

  #  visit new_user_session_path
  #  fill_in "Email", with: @moderator.email
  #  fill_in "Password", with: '123456'  # from users.yml
  #  click_on "Log in"
  #  assert_selector "h1", text: "Harami-chan"

  #  # Artist#index
  #  visit artists_url
  #  assert_selector "h1", text: "Artists"
  #  assert_selector 'form.button_to'
  #  click_on "Create New Artist"

  #  # Artist#new page
  #  assert_selector "h1", text: "New Artist"
  #end
end

