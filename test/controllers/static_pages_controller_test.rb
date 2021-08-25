require "test_helper"

class StaticPagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @static_page = static_pages(:static_one)
    @admin     = roles(:syshelper).users.first  # Only Admin can read/manage
    @moderator = roles(:general_ja_moderator).users.first  # Moderator cannot read
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "only admin should get index" do
    get static_pages_url
    assert_response :redirect
    assert_redirected_to new_user_session_path  # Devise sing_in route

    sign_in @moderator
    get static_pages_url
    assert_response :redirect
    assert_redirected_to root_url

    sign_in @admin
    get static_pages_url
    assert_response :success
  end

  test "should get new" do
    sign_in @moderator
    get new_static_page_url
    assert_response :redirect
    assert_redirected_to root_url

    sign_in @admin
    get new_static_page_url
    assert_response :success
  end

  test "should create static_page" do
    commig_msg = 'Initial commmit123.'
    hs_param = { content: 'test-content', page_format_id: @static_page.page_format_id, langcode: @static_page.langcode, mname: @static_page.mname, title: @static_page.title, commit_message: commig_msg }

    sign_in @moderator
    assert_difference('StaticPage.count', 0) do
      post static_pages_url, params: { static_page: hs_param }
    end
    assert_redirected_to root_url

    sign_in @admin
    assert_difference('StaticPage.count', 0) do
      post static_pages_url, params: { static_page: hs_param }
    end
    assert_response :unprocessable_entity
    assert_difference('StaticPage.count', 0) do
      post static_pages_url, params: { static_page: hs_param.merge({title: 'new-t0'}) }
    end
    assert_response :unprocessable_entity
    assert_difference('StaticPage.count', 0) do
      post static_pages_url, params: { static_page: hs_param.merge({mname: 'new-m0'}) }
    end
    assert_response :unprocessable_entity

    with_versioning do
      assert_difference('StaticPage.count', 1) do
        post static_pages_url, params: { static_page: hs_param.merge({mname: 'new-m0', title: 'new-t0'}) }
      end
      assert_response :redirect
      assert_redirected_to static_page_url(StaticPage.last)
      static_page = StaticPage.last
      assert_equal commig_msg, static_page.versions.last.commit_message
      assert_nil   static_page.commit_message
    end
  end

  ### redirector testing ###
  test "redirector using show static_page" do
    path = StaticPagesController.public_path(@static_page, locale=nil)
    assert_equal '/'+@static_page.mname, path  # in Fixture
    get path
    assert_response 301 # Moved Permanently
    assert_redirected_to Addressable::URI.parse(static_page_url(@static_page)).path

    %w(en ja).each do |elc|
      path = StaticPagesController.public_path(@static_page, locale=elc)
      assert_equal "/#{elc}/"+@static_page.mname, path  # in Fixture
      get path
      assert_response 301 # Moved Permanently
      assert_redirected_to '/'+elc+Addressable::URI.parse(static_page_url(@static_page)).path
    end

    path = StaticPagesController.public_path(@static_page, locale='JA')
    assert_raises(ActionController::RoutingError){ get path }
    # assert_response 404 # NOT found
  end

  test "should show static_page" do
    sign_in @moderator
    get static_page_url(@static_page)
    assert_redirected_to root_url

    sign_in @admin
    get static_page_url(@static_page)
    assert_response :success
  end

  test "should get edit" do
    sign_in @moderator
    get edit_static_page_url(@static_page)
    assert_redirected_to root_url

    sign_in @admin
    get edit_static_page_url(@static_page)
    assert_response :success
  end

  test "should update static_page" do
    hs_param = { content: @static_page.content, page_format_id: @static_page.page_format_id, langcode: @static_page.langcode, mname: @static_page.mname, title: @static_page.title }

    sign_in @moderator
    patch static_page_url(@static_page), params: { static_page: hs_param }
    assert_redirected_to root_url

    sign_in @admin
    patch static_page_url(@static_page), params: { static_page: hs_param }
    assert_redirected_to static_page_url(@static_page) # no change, hence no update

    with_versioning do
      assert_equal [], @static_page.versions
      cont_orig = @static_page.content
      str2change = 'another'
      patch static_page_url(@static_page), params: { static_page: hs_param.merge({content: str2change, commit_message: '1st update'}) }
      assert_redirected_to static_page_url(@static_page) # successfully updated

      @static_page.reload
      assert_equal str2change, @static_page.content

      str2change2 = 'another2'
      patch static_page_url(@static_page), params: { static_page: hs_param.merge({content: str2change2, commit_message: '2nd update'}) }
      @static_page.reload
      assert_equal str2change2, @static_page.content
      prev1 = @static_page.versions.last.reify(dup: true)
      assert_equal str2change, prev1.content

      prev2 = @static_page.versions[-2].reify(dup: true)
      assert_equal cont_orig, prev2.content
      assert_equal 2, @static_page.versions.size # 3 versions including the current one, which means the size of PaperTrail Versions is 2, apparently.
    end
  end

  test "should destroy static_page" do
    sign_in @moderator
    assert_difference('StaticPage.count', 0) do
      delete static_page_url(@static_page)
    end
    assert_redirected_to root_url

    sign_in @admin
    assert_difference('StaticPage.count', -1) do
      delete static_page_url(@static_page)
    end
    assert_redirected_to static_pages_url
  end
end
