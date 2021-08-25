# coding: utf-8
require 'test_helper'

class Harami1129sControllerModeratorTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------
  # add from here
  include Devise::Test::IntegrationHelpers

  setup do
    # @harami1129 = harami1129s(:harami1129one)
    get '/users/sign_in'
    # sign_in users(:user_001)
    @general_moderator = Role[:moderator, RoleCategory::MNAME_GENERAL_JA].users.first   # moderator/general_ja, who is not qualified to manimuplate Harami1129
    sign_in @general_moderator
    post user_session_url

    # If you want to test that things are working correctly, uncomment this below:
    follow_redirect!
    assert_response :success
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should fail to get index" do
    #print "DEBUG:logged_in?=#{user_signed_in?}; current_user="; p current_user  # => undefined method `user_signed_in?' 'current_user'
    get harami1129s_url
    assert_response :redirect
    assert_redirected_to root_url
  end

  test "should edit and nullify engage_id" do
    # <ActionController::Parameters {"singer"=>"AI", "song"=>"Story", "release_date(1i)"=>"2019", "release_date(2i)"=>"1", "release_date(3i)"=>"9", "title"=>"【即興ピアノ】即興ライブ！！", "link_root"=>"QqIpP4ZvQf4", "link_time"=>"430", "ins_singer"=>"AI", "ins_song"=>"Story", "ins_release_date(1i)"=>"2019", "ins_release_date(2i)"=>"1", "ins_release_date(3i)"=>"9", "ins_title"=>"【即興ピアノ】即興ライブ!!", "ins_link_root"=>"QqIpP4ZvQf4", "ins_link_time"=>"430", "ins_at(1i)"=>"2021", "ins_at(2i)"=>"1", "ins_at(3i)"=>"7", "ins_at(4i)"=>"19", "ins_at(5i)"=>"12", "ins_at(6i)"=>"25", "note"=>"", "not_music"=>"0", "destroy_engage"=>"0"} permitted: true>
    h1129 = harami1129s( :harami1129_ai )
    h1129_org = h1129.dup
    hs = Harami1129sController::INDEX_COLUMNS.map(&:to_s).select{|k, v|
      !%w(destroy_engage human_check human_uncheck).include? k
    }.map{|i| [i, h1129.send(i)]}.to_h

    hs = convert_to_params(hs, maxdatenum: 6)

    exp_date = h1129.ins_release_date.next # +1 day
    hs.merge! convert_to_params({"ins_release_date" => exp_date})
    hs["ins_at(6i)"] = (hs["ins_at(6i)"].to_i + 1).to_s  # +1 sec

    # Form-specific parameter
    hs['destroy_engage'] = '1'
    hs['not_music'] = '0'  # Contradictory

    patch harami1129_url(h1129, params: { harami1129: hs })
    assert_redirected_to root_url
    sign_out @general_moderator

    sign_in users(:user_moderator) # Harami moderator

    # Nothing should change because of the contradiction.
    patch harami1129_url(h1129, params: { harami1129: hs })
    assert_response :success
    assert (200...299).include?(response.code.to_i), "Response.code=#{response.code} is NOT 200"  # should not be like :redirect or 403 forbidden
    h1129.reload
    %i(engage title ins_release_date ins_at not_music).each do |ek|
      exp = h1129_org.send(ek)
      act = h1129.send(ek)
      msg = "Failed in ek="+ek.to_s
      if exp.nil?
        assert_nil        act, msg
      else
        assert_equal exp, act, msg
      end
    end

    ##### engage_id will become nil b/c of destroy_engage="1"

    hs['not_music'] = '1'  # Now, destroy_engage="1" becomes valid
    patch harami1129_url(h1129, params: { harami1129: hs })
    assert_response :redirect
    assert_redirected_to h1129  # Redirected to Harami1129
    h1129.reload
    assert_nil          h1129_org.not_music
    assert_equal true,  h1129.not_music
    assert_nil  h1129.engage
    assert_equal h1129_org.ins_at, h1129.ins_at
    assert_equal exp_date, h1129.ins_release_date

    ##### ins_at will be changed

    hs['not_music'] = '0'
    hs['destroy_engage'] = '0'
    hs["ins_at(6i)"] = (hs["ins_at(6i)"].to_i + 2).to_s  # +2 sec (which is regarded as significant)
    patch harami1129_url(h1129, params: { harami1129: hs })
    assert_response :redirect
    assert_redirected_to h1129  # Redirected to Harami1129
    h1129.reload
    assert_equal false, h1129.not_music
    assert_nil  h1129.engage  # no change from the last change
    assert_not_equal h1129_org.ins_at, h1129.ins_at  # changed.
    assert_equal exp_date, h1129.ins_release_date

    ##### check checked_at #####

    assert_nil  h1129.checked_at
    hs['human_check'] = "1"
    patch harami1129_url(h1129, params: { harami1129: hs })
    assert_response :redirect
    assert_redirected_to h1129  # Redirected to Harami1129
    h1129.reload
    assert  h1129.checked_at
    assert_operator h1129.last_downloaded_at, "<", h1129.checked_at

    ##### uncheck checked_at #####

    hs['human_check'] = "0"
    hs['human_uncheck'] = "1"
    patch harami1129_url(h1129, params: { harami1129: hs })
    assert_response :redirect
    assert_redirected_to h1129  # Redirected to Harami1129
    h1129.reload
    assert  h1129.checked_at
    assert_operator h1129.checked_at, "<", h1129.orig_modified_at

    ##### destroy #####

    hs['human_uncheck'] = "0"
    assert_difference('Harami1129.count', -1) do
      delete harami1129_url(h1129)
    end
    assert_response :redirect
    assert_redirected_to harami1129s_url  # Redirected to Harami1129 index
    assert_nil Harami1129.find_by_id h1129.id
  end
end

