require "test_helper"

class ModelSummariesControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @model_summary = model_summaries(:model_summary_Sex)
    @syshelper = users(:user_syshelper)  # Syshelper can manage.
    @moderator = users(:user_moderator)
  end

  # add this
  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    get model_summaries_url
    assert_redirected_to new_user_session_path

    sign_in @moderator
    get model_summaries_url
    assert_response :success
    ## TODO: "Static Page" should not be vieweable.
  end

  test "should get new" do
    sign_in @syshelper
    get new_model_summary_url
    assert_response :success
  end

  test "should create model_summary" do
    sign_in @syshelper
    assert_no_difference("ModelSummary.count") do
      # unique validation error
      post model_summaries_url, params: { model_summary: { modelname: @model_summary.modelname, langcode: "en", title: "tilte-0" } }
      # format validation error
      post model_summaries_url, params: { model_summary: { modelname: "lower_case_is_wrong", langcode: "en", title: "tilte-1" } }
    end

    assert_difference("ModelSummary.count") do
      post model_summaries_url, params: { model_summary: { modelname: "NaiyoNew", langcode: "en", title: "this is a model." } }
    end
    assert_redirected_to model_summary_url(ModelSummary.last)
  end

  test "should show model_summary" do
    sign_in @syshelper
    get model_summary_url(@model_summary)
    assert_response :success
  end

  test "should get edit" do
    sign_in @syshelper
    get edit_model_summary_url(@model_summary)
    assert_response :success
  end

  test "should update model_summary" do
    sign_in @syshelper
    patch model_summary_url(@model_summary), params: { model_summary: { modelname: @model_summary.modelname, note: "new-note" } }
    assert_redirected_to model_summary_url(@model_summary)
    @model_summary.reload
    assert_equal "new-note", @model_summary.note
  end

  test "should destroy model_summary" do
    sign_in @syshelper
    assert_difference("ModelSummary.count", -1) do
      delete model_summary_url(@model_summary)
    end

    assert_redirected_to model_summaries_url
  end
end
