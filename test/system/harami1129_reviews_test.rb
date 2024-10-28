# coding: utf-8
require "application_system_test_case"

class Harami1129ReviewsTest < ApplicationSystemTestCase
  setup do
    @harami1129_review = harami1129_reviews(:h1129review_ai_singer)
    @moderator = users(:user_moderator_all)  # Only Harami moderator can manage.
  end

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
  end

  test "visiting the index and then new" do
    visit harami1129_reviews_url  # should be redirected to new_user_session_path
    #visit new_user_session_path

    assert page.find(:xpath, xpath_for_flash(:alert, category: :div)).text.strip.include?("need to sign in") # defined in test_helper.rb
                           # "//div[@id='body_main']/div[contains(@class, 'alert-danger')][1]"  (and more)

    fill_in "Email", with: @moderator.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"
    
    refute_selector "h1", text: "HARAMIchan"
    assert_selector "h1", text: "Harami1129 Reviews"  # auto-transferred!
    assert_equal "Signed in successfully.", page.find(:xpath, xpath_for_flash(:notice, category: :div)).text.strip  # Notice message issued.
                                                     # "//div[@id='body_main']/div[contains(@class, 'notice')][1]"  (and more)

    assert_selector 'form.button_to'
    click_on "Create New Harami1129Review"
    assert_selector "h1", text: "New harami1129 review"  # auto-transferred!

    visit harami1129_reviews_url  # Revisits Harami1129Review#index
    assert_selector "h1", text: "Harami1129 Reviews"
    assert_match(/^\d+\z$/, page.find_all("table a:nth-child(1)")[0].text.strip, "Link text should be ID-like, but...")

    page.find_all(:xpath, "//table//td//a[text()='Edit']")[0].click

    assert_selector "h1", text: "Editing"
    check "Reviewed"
    click_on "Update"
    assert_text "Harami1129 review was successfully updated"
    assert  page.find(:xpath, xpath_for_flash(:notice, category: :div)).text.include?("was successfully updated")  # Notice message issued.
    assert_text "Checked: true"

    refute_selector :xpath, "//input[@type='submit' and @value='Destroy this Harami1129Review']"
  end

  #test "should create harami1129 review" do
  #  visit harami1129_reviews_url
  #  click_on "New harami1129 review"

  #  check "Checked" if @harami1129_review.checked
  #  fill_in "Engage id", with: @harami1129_review.engage_id_id
  #  fill_in "Harami1129 col name", with: @harami1129_review.harami1129_col_name
  #  fill_in "Harami1129 col val", with: @harami1129_review.harami1129_col_val
  #  fill_in "Harami1129 id", with: @harami1129_review.harami1129_id_id
  #  fill_in "Note", with: @harami1129_review.note
  #  fill_in "User", with: @harami1129_review.user_id
  #  click_on "Create Harami1129 review"

  #  assert_text "Harami1129 review was successfully created"
  #  click_on "Back"
  #end

  #test "should update Harami1129 review" do
  #  visit harami1129_review_url(@harami1129_review)
  #  click_on "Edit this harami1129 review", match: :first

  #  check "Checked" if @harami1129_review.checked
  #  fill_in "Engage id", with: @harami1129_review.engage_id_id
  #  fill_in "Harami1129 col name", with: @harami1129_review.harami1129_col_name
  #  fill_in "Harami1129 col val", with: @harami1129_review.harami1129_col_val
  #  fill_in "Harami1129 id", with: @harami1129_review.harami1129_id_id
  #  fill_in "Note", with: @harami1129_review.note
  #  fill_in "User", with: @harami1129_review.user_id
  #  click_on "Update Harami1129 review"

  #  assert_text "Harami1129 review was successfully updated"
  #  click_on "Back"
  #end

  #### NOTE: Deletion should be able to be done only by admin! (NOT by a moderator)
  #test "should destroy Harami1129 review" do
  #  visit harami1129_review_url(@harami1129_review)
  #  click_on "Destroy this harami1129 review", match: :first

  #  assert_text "Harami1129 review was successfully destroyed"
  #end
end
