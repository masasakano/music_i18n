require "test_helper"

class Harami1129ReviewsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @harami1129_review = harami1129_reviews(:h1129review_ai_singer)
    @editor    = roles(:general_ja_editor).users.first  # Editor cannot manage.
    @moderator = users(:user_moderator_all)  # Only Harami moderator can manage.
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should fail in get index" do
    get harami1129_reviews_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor
    assert_response :redirect
    assert_redirected_to new_user_session_path
    sign_out @editor
  end

  test "should get index" do
    sign_in @moderator
    ability = Ability.new(@moderator)
    assert ability.can?(:read, Harami1129Review)
    get harami1129_reviews_url
    assert_response :success
  end

  test "should get new" do
    get new_harami1129_review_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @moderator
    get new_harami1129_review_url
    assert_response :success
  end

  test "should create harami1129_review" do
    sign_in @moderator
    assert_no_difference("Harami1129Review.count") do
      # unique constraint error
      post harami1129_reviews_url, params: { harami1129_review: { checked: @harami1129_review.checked, engage_id: @harami1129_review.engage_id, harami1129_col_name: @harami1129_review.harami1129_col_name, harami1129_col_val: @harami1129_review.harami1129_col_val, harami1129_id: @harami1129_review.harami1129_id, note: @harami1129_review.note, user_id: @harami1129_review.user_id } }
    end

    h1129_kubota = harami1129s(:harami1129_ihojin1)
    assert_difference("Harami1129Review.count") do
      post harami1129_reviews_url, params: { harami1129_review: { checked: false, engage_id: h1129_kubota.engage_id, harami1129_col_name: "ins_singer", harami1129_col_val: h1129_kubota.ins_singer, harami1129_id: h1129_kubota.id, note: nil, user_id: @moderator.id } }
    end

    assert_redirected_to harami1129_review_url(Harami1129Review.last)
  end

  test "should show harami1129_review" do
    sign_in @moderator
    get harami1129_review_url(@harami1129_review)
    assert_response :success
  end

  test "should get edit" do
    sign_in @moderator
    get edit_harami1129_review_url(@harami1129_review)
    assert_response :success
  end

  test "should update harami1129_review" do
    sign_in @moderator
    patch harami1129_review_url(@harami1129_review), params: { harami1129_review: { checked: @harami1129_review.checked, engage: @harami1129_review.engage, harami1129_col_name: @harami1129_review.harami1129_col_name, harami1129_col_val: @harami1129_review.harami1129_col_val, harami1129: @harami1129_review.harami1129, note: @harami1129_review.note, user_id: @harami1129_review.user_id } }
    assert_redirected_to harami1129_review_url(@harami1129_review)
  end

  test "should destroy harami1129_review" do
    sign_in @moderator
    assert_no_difference("Harami1129Review.count", -1) do
      delete harami1129_review_url(@harami1129_review)
    end
    sign_out @moderator

    # Only admin can delete them.
    sign_in users(:user_sysadmin)
    assert_difference("Harami1129Review.count", -1) do
      delete harami1129_review_url(@harami1129_review)
    end
    assert_redirected_to harami1129_reviews_url
  end
end
