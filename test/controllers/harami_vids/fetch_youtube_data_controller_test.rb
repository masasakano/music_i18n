require "test_helper"

# == NOTE
#
# * ENV["YOUTUBE_API_KEY"] is essential.
# * ENV["UPDATE_YOUTUBE_MARSHAL"] : set this if you want to update the marshal-led Youtube data.
#
class FetchYoutubeDataControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @harami_vid = harami_vids(:harami_vid1)
    @sysadmin  = users(:user_sysadmin)
    @syshelper = users(:user_syshelper)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @moderator_ja    = users(:user_moderator_general_ja)  # 
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor

    @def_update_params = {  # NOTE: Identical to @def_create_params except for those unique to create!
      "uri_youtube"=>"https://www.youtube.com/watch?v=hV_L7BkwioY", # HARAMIchan Zenzenzense
      "use_cache_test" => true,
    }.with_indifferent_access

    @def_create_params = @def_update_params.merge({
    }.with_indifferent_access)
    @h1129 = harami1129s(:harami1129_zenzenzense1)
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should create" do
    hsin = {}.merge(@def_create_params.merge).with_indifferent_access  # "use_cache_test" => true

    ## sign_in mandatory
    post harami_vids_fetch_youtube_data_path, params: { harami_vid: { fetch_youtube_data: hsin } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    ## trans_moderator is not qualified
    sign_in  @trans_moderator
    post harami_vids_fetch_youtube_data_path, params: { harami_vid: { fetch_youtube_data: hsin } }
    assert_response :redirect, "should be banned for #{@trans_moderator.display_name}, but allowed..."
    assert_redirected_to root_path
    sign_out @trans_moderator

    ## Editor harami is qualified
    sign_in @editor_harami

    assert_difference("Music.count*1000 + Artist.count*100 + Engage.count*10 + HaramiVidMusicAssoc.count", 1111) do
      assert_difference("ArtistMusicPlay.count*1000 + Event.count*100 + EventItem.count*10", 1110) do
        assert_difference("HaramiVidEventItemAssoc.count*10 + HaramiVid.count*1", 11) do
          assert_difference("Translation.count", 2) do  # English Translation added.
            assert_no_difference("Channel.count") do
              post harami_vids_fetch_youtube_data_path, params: { harami_vid: { fetch_youtube_data: hsin } }
              assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
              hvid = HaramiVid.last
              assert_redirected_to hvid
            end
          end
        end
      end
    end

    hvid = HaramiVid.last

    assert_equal @h1129.uri,    hvid.uri, "sanity check..."
    assert_equal @h1129.song,   hvid.musics.first.title
    assert_equal @h1129.singer, hvid.artists.first.title
    assert_equal @h1129.title,  hvid.title
    assert_equal channels(:channel_haramichan_youtube_main), hvid.channel
    assert_equal Event.default, hvid.event_items.first.channel

    assert ENV["YOUTUBE_API_KEY"].present?, "Environmental variable YOUTUBE_API_KEY is not set, which is essential for this test."
    sign_out @editor_harami
  end

  test "should update" do
    # See /test/models/harami1129_test.rb
    @h1129.insert_populate

    assert @h1129.ins_song.present?
    hvid = @h1129.harami_vid
    assert hvid

    hvid.update!(note: "Test-note" + (hvid.note || ""))
    note_be4 = hvid.note

    mus = hvid.musics.first
    art = hvid.artists.first
    evit = hvid.event_items.first
    assert evit
    amps  = evit.artist_music_plays
    amp   = amps.first

    # sanity checks
    assert_equal 1, amps.size
    assert mus
    assert art
    assert hvid.uri.present?
    hvid.reload
    assert_equal 1, hvid.translations.size
    tra_be4 = hvid.translations.first
    assert_equal "ja", tra_be4.langcode
    assert_nil hvid.duration

    channel_be4      = hvid.channel
    release_date_be4 = hvid.release_date
    assert channel_be4
    assert release_date_be4

    hsin = {}.merge(@def_update_params.merge).with_indifferent_access  # "use_cache_test" => true

    ## sign_in mandatory
    patch harami_vids_fetch_youtube_datum_path(hvid), params: { harami_vid: { fetch_youtube_datum: hsin } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    ## trans_moderator is not qualified
    sign_in  @trans_moderator
    patch harami_vids_fetch_youtube_datum_path(hvid), params: { harami_vid: { fetch_youtube_datum: hsin } }
    assert_response :redirect, "should be banned for #{@trans_moderator.display_name}, but allowed..."
    assert_redirected_to root_path
    sign_out @trans_moderator

    ## Editor harami is qualified
    # Same Japanese Translation, but English Translation is added.
    sign_in @editor_harami

    assert_no_difference("ArtistMusicPlay.count + Music.count + Artist.count + Engage.count + HaramiVidMusicAssoc.count + HaramiVidEventItemAssoc.count + Event.count + EventItem.count + Channel.count + HaramiVid.count") do
      assert_difference("Translation.count") do  # English Translation added.
        patch harami_vids_fetch_youtube_datum_path(hvid), params: { harami_vid: { fetch_youtube_datum: hsin } }
        assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
        assert_redirected_to hvid
      end
    end

    hvid.reload
    assert_equal note_be4, hvid.note
    assert_equal channel_be4,      hvid.channel
    assert_equal release_date_be4, hvid.release_date

    assert hvid.duration.present?
    assert_operator 0, :<, hvid.duration, "Positive duration should have been set, but..."

    tras = hvid.translations
    assert_equal %w(en ja), tras.pluck(:langcode).flatten.sort
    refute_equal(*tras.pluck(:title))

    tra_en = tras.find_by(langcode: "en")
    assert_equal @editor_harami, tra_en.create_user


    ## 2nd and 3rd runs
    # This time, only Youtube-ID of Channel should be updated after it is deliberately unset.
    chan = hvid.channel
    %w(id_at_platform id_human_at_platform).each do |att|
      chan.update!(att => nil)
      assert_nil chan.send(att)
      prev_updated_time = chan.updated_at
  
      assert_no_difference("ArtistMusicPlay.count + Music.count + Artist.count + Engage.count + HaramiVidMusicAssoc.count + HaramiVidEventItemAssoc.count + Event.count + EventItem.count + Channel.count + HaramiVid.count") do
        assert_no_difference("Translation.count") do  # English Translation added.
          patch harami_vids_fetch_youtube_datum_path(hvid), params: { harami_vid: { fetch_youtube_datum: hsin } }
          assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
          assert_redirected_to hvid
        end
      end
  
      chan.reload
      assert_operator prev_updated_time, :<, chan.updated_at
      assert chan.send(att)
      assert_operator 3, :<=, chan.send(att).size, "#{att} should have been set, but..."
    end

    sign_out @editor_harami
  end
end
