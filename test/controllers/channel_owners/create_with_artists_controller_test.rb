require "test_helper"

class ChannelOwners::CreateWithArtistsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  include ModuleCommon  # for definite_article_to_head(instr)

  setup do
    @artist = artists(:artist_zombies)

    @sysadmin  = users(:user_sysadmin)
    @syshelper = users(:user_syshelper)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @moderator_ja    = users(:user_moderator_general_ja)  # 
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should fail in get new" do
    # This would forcibly log out the user!
    # Hence, if this is put in the middle of the following tests (before the final one), this would mess up the subsequent rests!
    sign_in @editor_ja
    assert_raises(ActionController::ParameterMissing){
      get channel_owners_create_with_artists_new_url }
    # assert_response :unprocessable_entity
  end

  test "should get new" do
    # should not
    get channel_owners_create_with_artists_new_url, params: {artist_id: @artist.id}
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor_ja

    ## sanity checks of the current status of fixtures
    assert( (zombies_tit=@artist.title).present?, 'sanity check of fixtures')
    refute  @artist.channel_owner
    assert_nil  ChannelOwner.select_regex(:title, zombies_tit).first, 'sanity check of fixtures'

    n_trans = @artist.best_translations.size

    # should succeed
    assert_difference('Translation.count', n_trans){
      assert_difference('ChannelOwner.count'){
        get channel_owners_create_with_artists_new_url, params: {channel_owner: {artist_id: @artist.id}}
       #get channel_owners_create_with_artists_new_url( params: {channel_owner: {artist_id: @artist.id}})
        assert_response :redirect
        #refute_redirected_to new_user_session_path  # method not found...
      }
    }

    owner = ChannelOwner.last
    assert_redirected_to channel_owner_path(owner)
    assert       owner.themselves
    assert       owner.artist
    assert_equal @artist, owner.artist
    assert_equal @artist.title, owner.title
  end
end
