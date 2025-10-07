require 'test_helper'

class TranslationsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @translation_ja = translations(:sextrans0ja)
    @translation_en = translations(:sextrans0en)
    @admin = users(:user_sysadmin)
    @translator = users(:user_translator)
    @trans_moderator = users(:user_moderator_translation)
    @general_moderator = users(:user_moderator)  # moderator/general_ja, who is not qualified to manimuplate this model though can read
    @sex = Sex.second
    @music = Music.second
    @artist = artists(:artist_ai)
    @tra_mu_ja      = translations(:music_kampai_ja1)
    @tra_mu         = translations(:music_kampai_en4)  # created/updated by @translator
    @tra_mu_by_mod  = translations(:music_kampai_en3)  # created by @translator, updated by user_moderator_translation
    @tra_mu_upd_mod = translations(:music_kampai_en2)  # created/updated by user_moderator_translation
    @tra_mu_en_orig = translations(:music_light_en) # English is_orig=true of Music
  end

  teardown do
    Rails.cache.clear
  end

  test "should fail to get index" do
    get translations_url
    assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "should get index" do
    user_moderator = users(:user_moderator)
if false
    get '/users/sign_in'
    sign_in users(:user_moderator)  # Harami moderator
    #post user_session_url

    ## If you want to test that things are working correctly, uncomment this below:
    #follow_redirect!
    #assert_response :success

    get translations_url
    assert_redirected_to root_url

    sign_in @translator
    get translations_url
    assert_response :success
else
    ### This practically tests assert_controller_index_fail_succeed in test_helper.rb
    assert_controller_index_fail_succeed(translations_url, user_fail: nil, user_succeed: nil)  # defined in test_helper.rb
    assert_controller_index_fail_succeed(translations_url, user_fail: user_moderator, user_succeed: @translator)  # defined in test_helper.rb
    sign_out @translator
    assert_controller_index_fail_succeed(Translation,      user_fail: user_moderator, user_succeed: @translator)  # defined in test_helper.rb
    sign_out @translator
    assert_controller_index_fail_succeed(Translation.second, user_fail: users(:user_no_role), user_succeed: @translator)  # defined in test_helper.rb
end
  end

  test "should fail get new" do
    get new_translation_url
    assert_redirected_to new_user_session_path
  end

  test "translator should get new" do
    [@translator, @general_moderator].each do |euser|
      sign_in euser
      get new_translation_url
      assert_response :redirect
      assert_redirected_to root_path
      sign_out euser
    end

    sign_in @trans_moderator
    get new_translation_url
    assert_response :success
  end

if false
  test "should fail to create translation" do
    assert_difference('Translation.count', 0) do
      post translations_url, params: { translation: { alt_title: 'abcde', is_orig: false, langcode: 'en', translatable_type: @sex.class.name, translatable_id: @sex.id, } }
    end
    assert_redirected_to new_user_session_path
  end

  test "translator should create translation" do
    sign_in @translator
    assert_difference('Translation.count', 0) do
      post translations_url, params: { translation: { alt_title: 'abcde', is_orig: false, langcode: 'en', translatable_type: @sex.class.name, translatable_id: @sex.id, } }
    end
    assert_redirected_to root_url

    # 1st creation
    assert_difference('Translation.count', 1) do
      post translations_url, params: { translation: { alt_title: 'abcde', is_orig: false, langcode: 'en', translatable_type: @music.class.name, translatable_id: @music.id, } }
    end
    tra = Translation.order(:created_at).last  # Translation.last sorts in order of primary ID, which may not work well with fixtures!
    assert_redirected_to translation_url(tra)

    assert_equal @translator, tra.create_user, "(For some reason tra.create_user may return nil very oocasionally) tra=#{tra.inspect}"
    assert_equal @translator, tra.update_user
    assert_equal @translator.roles.first.weight, tra.weight

    # 2nd creation by Moderator-Translator
    sign_out @translator
    @trans_moderator = users(:user_moderator_translation)
    sign_in @trans_moderator
    assert_difference('Translation.count', 1) do
      post translations_url, params: { translation: { alt_title: 'abcd2', is_orig: false, langcode: 'en', translatable_type: @music.class.name, translatable_id: @music.id, } }
    end
    tra2 = Translation.order(:created_at).last
    assert_redirected_to translation_url(tra2)

    assert_equal @trans_moderator, tra2.create_user
    assert_equal @trans_moderator, tra2.update_user
    assert_equal @trans_moderator.roles.first.weight, tra2.weight

    # 3nd creation by another Translator at the same rank
    sign_out @trans_moderator
    @translator2 = users(:user_translator2)
    sign_in @translator2
    assert_difference('Translation.count', 1) do
      post translations_url, params: { translation: { alt_title: 'abcd3', is_orig: false, langcode: 'en', translatable_type: @music.class.name, translatable_id: @music.id, } }
    end
    tra3 = Translation.order(:created_at).last
    assert_redirected_to translation_url(tra3)

    assert_equal @translator2, tra3.create_user
    assert_equal @translator2, tra3.update_user
    assert_operator tra3.weight, '<', tra.weight
    assert_operator tra2.weight, '<', tra3.weight, 'weight should be larger than that by a moderator, but?'

    # 4th creation by the 1st Translator
    sign_out @translator2
    sign_in @translator
    tra3.update!(weight: @trans_moderator.roles.first.weight + 1)
    tra3.reload

    assert_difference('Translation.count', 1, 'failed: response='+@response.body) do
      post translations_url, params: { translation: { alt_title: 'abcd4', is_orig: false, langcode: 'en', translatable_type: @music.class.name, translatable_id: @music.id, } }
    end
    tra4 = Translation.order(:created_at).last
    assert_redirected_to translation_url(tra4)

    assert_equal @translator, tra4.create_user
    assert_equal @translator, tra4.update_user
    assert_operator tra4.weight, '<', tra3.weight
    assert_operator tra2.weight, '<', tra4.weight, 'weight should be larger than that by a moderator, but?'
    assert_operator tra2.weight+1, '>', tra4.weight, 'weight should be a float, but?'

    # 5th creation attempt with an identical translation should fail.
    assert_difference('Translation.count', 0, 'failed: response='+@response.body) do
      post translations_url, params: { translation: { alt_title: 'abcd4', is_orig: false, langcode: 'en', translatable_type: @music.class.name, translatable_id: @music.id, } }
    end
    assert_response :unprocessable_content
    assert_includes css_select('div#error_explanation ul li').map(&:text).join(" "), 'must be unique'
      #<h2>2 errors prohibited this translation from being saved:</h2>
      #  <li>Title has already been taken
      #  <li>Combination of (title, alt_title) must be unique: [nil, &quot;abcd4&quot;]</li>
  end

  test "should fail to show translation" do
    get translation_url(@translation_ja)
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "translator should show translation" do
    sign_in @translator
    get translation_url(@translation_ja)
    assert_response :success

    get translation_url(translations(:artist_psy_kr))
    assert_response :success
  end

  test "should fail to get edit" do
    get edit_translation_url(@translation_ja)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    get edit_translation_url(@tra_mu_en_orig)
    assert_redirected_to new_user_session_path
  end

  test "translator should edit translation only if it belongs to them" do
    sign_in @translator
    get edit_translation_url(@translation_ja)
    assert_redirected_to root_url

    get edit_translation_url(@tra_mu_by_mod)
    assert_redirected_to root_url

    get edit_translation_url(@tra_mu_ja)
    assert_response :success, 'JA Music Translation should be editable by Translator, but?'

    get edit_translation_url(@tra_mu_en_orig)
    assert @tra_mu_en_orig.is_orig, 'Sanity check of fixture'
    assert_response :success, 'original-EN Music title should be editable by translator-editor, but?'

    get edit_translation_url(@tra_mu)
    assert_response :success
    sign_out(@translator)

    sign_in(@general_moderator)
    get edit_translation_url(@tra_mu_en_orig)
    assert_response :success, 'original-EN Music title should be editable by evey general-editor, but?'

    play_role_unk = PlayRole.unknown?
    play_role_unk.update!(create_user_id: @general_moderator, update_user_id: @general_moderator)
    get edit_translation_url(play_role_unk)
    assert_response :unprocessable_content, 'Should fail due to unknown PlayRole'
    sign_out(@general_moderator)

    sign_in @admin
    get edit_translation_url(play_role_unk)
    assert_response :success
  end

  test "should fail to update translation" do
    patch translation_url(@translation_ja), params: { translation: { alt_title: 'abcde', is_orig: false, langcode: 'en', translatable_type: @sex.class.name, translatable_id: @sex.id, } }
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "translator should update translation only if it belongs to them" do
    sign_in @translator
    patch translation_url(@translation_ja), params: { translation: { alt_title: 'abcde', is_orig: false, langcode: 'en', translatable_type: @sex.class.name, translatable_id: @sex.id, } }
    assert_redirected_to root_url

    parent = @tra_mu_by_mod.translatable
    patch translation_url(@tra_mu_by_mod), params: { translation: { alt_title: 'abcde', is_orig: false, langcode: 'en', translatable_type: parent.class.name, translatable_id: parent.id, } }
    assert_redirected_to root_url

    assert_equal parent, @tra_mu.translatable, 'Sanity check of fixture failed...'
    parent = @tra_mu.translatable
    patch translation_url(@tra_mu), params: { translation: { title: @tra_mu_by_mod.title, is_orig: false, langcode: 'en', translatable_type: parent.class.name, translatable_id: parent.id, } }
    assert_response :unprocessable_content, 'Should fail due to unique constraint, but?'

    patch translation_url(@tra_mu), params: { translation: { alt_title: 'abcde', is_orig: false, langcode: 'en', translatable_type: parent.class.name, translatable_id: parent.id, } }
    assert_redirected_to translation_url(@tra_mu)
  end

  test "should fail to destroy translation" do
    assert_difference('Translation.count', 0) do
      delete translation_url(@translation_ja)
    end
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "translator should destroy translation only if it belongs to them" do
    sign_in @translator
    assert_difference('Translation.count', 0) do
      delete translation_url(@translation_ja)
    end
    assert_redirected_to root_url

    assert_difference('Translation.count', 0) do
      delete translation_url(@tra_mu_by_mod)
    end
    assert_redirected_to root_url

    assert_difference('Translation.count', -1) do
      delete translation_url(@tra_mu)
    end
    assert_redirected_to translations_url
  end
end # if false
end

