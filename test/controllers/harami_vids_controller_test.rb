require 'test_helper'

class HaramiVidsControllerTest < ActionDispatch::IntegrationTest
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

    @validator = W3CValidators::NuValidator.new

    @def_place = places(:tocho)
    @def_update_params = {  # NOTE: Identical to @def_create_params except for those unique to create!
      "uri"=>"https://youtu.be/InitialUri", "duration"=>"56",
      "release_date(1i)"=>"2024", "release_date(2i)"=>"2", "release_date(3i)"=>"28",
      "place.prefecture_id.country_id"=>@def_place.country.id.to_s,
      "place.prefecture_id"=>@def_place.prefecture_id.to_s, "place"=>@def_place.id.to_s,
      "form_channel_owner"   =>ChannelOwner.primary.id.to_s,
      "form_channel_type"    =>ChannelType.default(:HaramiVid).id.to_s,
      "form_channel_platform"=>ChannelPlatform.default(:HaramiVid).id.to_s,
      "form_event_items" => [events(:ev_harami_lucky2023).event_items.first, Event.unknown.event_items.first].map(&:id).map(&:to_s),
      "form_new_event" => events(:ev_harami_lucky2023).id.to_s,
      "artist_name"=>"",
      "form_engage_hows"=>EngageHow.default(:HaramiVid).id.to_s,
      "form_engage_year"=>"1997",
      "form_engage_contribution"=>"0.5678",
      "artist_name_collab"=>"",
      "form_instrument" => Instrument.default(:HaramiVid).id.to_s,
      "form_play_role"  => PlayRole.default(:HaramiVid).id.to_s,
      "music_name"=>"", "music_timing"=>"1234",
      "music_genre"=>Genre.default(:HaramiVid).id.to_s, "music_year"=>"1984",
      "note"=>"",
       # "uri_playlist_en"=>"", "uri_playlist_ja"=>"",
    }.with_indifferent_access

    @def_create_params = @def_update_params.merge({
      "title"=>"Initial test-title", "langcode"=>"ja",
    }.with_indifferent_access)
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get index" do
    get harami_vids_url
    assert_response :success, "Should be open to public, but..."

    assert css_select("table.datagrid.harami_vids_grid tbody tr").any?{|esel| esel.css('td.title_en')[0].text.blank? && !esel.css('td.title_ja')[0].text.blank?}, "Some EN titles should be blank (where JA titles are NOT blank), but..."
  end

  test "should get new" do
    get new_harami_vid_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    [@trans_moderator, @moderator_ja].each do |user|
      sign_in user
      get new_harami_vid_url
      assert_response :redirect, "should be banned for #{user.display_name}, but allowed..."
      assert_redirected_to root_path
      sign_out user
    end

    sign_in @editor_harami
    get new_harami_vid_url
    assert_response :success
  end

  test "should create harami_vid" do
    assert_no_difference('HaramiVid.count') do
      post harami_vids_url, params: { harami_vid: @def_create_params }
    end
    assert_redirected_to new_user_session_path

    [@trans_moderator, @moderator_ja].each do |user|
      sign_in user
      assert_no_difference('HaramiVid.count') do
        post harami_vids_url, params: { harami_vid: @def_create_params }
      end
      assert_response :redirect, "should be banned for #{user.display_name}, but allowed..."
      assert_redirected_to root_path
      sign_out user
    end

    sign_in @editor_harami
    run_test_create_null(Channel, extra_colnames: %i(title langcode)) # defined in /test/helpers/controller_helper.rb
    ## null imput should fail.

#if false # temporary skip
if true
    assert_no_difference("HaramiVid.count") do
      post harami_vids_url, params: { harami_vid: @def_create_params.merge({title: 'some', uri: 'https://youtu.be/naiyo', form_channel_owner: ChannelOwner.order(:id).last.id+1})}
      assert_response :unprocessable_entity
    end
#end
#if false # temporary skip
#if true

    #hsnew = {title: 'a new one', uri: "https://youtu.be/mytest1", note: "newno"}
    hsnew = {note: "newno"}
    assert_no_difference("Music.count + HaramiVidMusicAssoc.count + Artist.count + Engage.count +  EventItem.count + ArtistMusicPlay.count") do
      assert_no_difference("Channel.count") do  # existing Channel is found
        assert_difference("HaramiVid.count") do
          post harami_vids_url, params: { harami_vid: @def_create_params.merge(hsnew)}
          assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
        end
      end
    end
    mdl_last = HaramiVid.last
    assert_redirected_to harami_vid_url(mdl_last)
    assert_equal "newno", mdl_last.note
    assert_equal @def_create_params[:title],  mdl_last.title
    assert_equal Channel.default(:HaramiVid), mdl_last.channel
    assert_equal Date.parse("2024-02-28"),    mdl_last.release_date

    # A new channle is temporarily created but must be rolled-back because HaramiVid was not created after all.
    hsnew = {form_channel_platform: channel_platforms(:channel_platform_facebook).id, note: "fail due to unique uri"}
    assert_no_difference("Channel.count") do
      assert_no_difference("HaramiVid.count") do
        post harami_vids_url, params: { harami_vid: @def_create_params.merge(hsnew)}
        assert_response :unprocessable_entity

        uri2test = ApplicationHelper.normalized_uri_youtube(@def_create_params[:uri], long: true, with_scheme: true, with_host: true)
        assert_includes uri2test, "https://www.youtube.com/watch?v=", 'sanity check'
        post harami_vids_url, params: { harami_vid: @def_create_params.merge(hsnew).merge({uri: uri2test})}
        assert_response :unprocessable_entity
      end
    end

    # A new Channel is successfully created.
    platform_fb = channel_platforms(:channel_platform_facebook)
    hsnew = {uri: uri="youtu.be/0030", form_channel_platform: platform_fb.id, note: "success"}
    assert_difference("Channel.count") do
      assert_difference("HaramiVid.count") do
        post harami_vids_url, params: { harami_vid: @def_create_params.merge(hsnew)}
        assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
      end
    end
    assert_equal platform_fb, Channel.last.channel_platform
    mdl_last = HaramiVid.last
    assert_equal uri, mdl_last.uri

    # new Music, no Artist
    mu_name = "My new Music 4"
    hsnew = {uri: (newuri="https://www.youtube.com/watch?v=0040"), title: (newtit="new40"), music_name: mu_name, note: (newnote=mu_name+" is added.")}
    assert_no_difference("Artist.count + Engage.count +  EventItem.count + ArtistMusicPlay.count") do
      assert_difference("Music.count + HaramiVidMusicAssoc.count", 2) do
        assert_no_difference("Channel.count") do  # existing Channel is found
          assert_difference("HaramiVid.count") do
            post harami_vids_url, params: { harami_vid: @def_create_params.merge(hsnew)}
            assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
          end
        end
      end
    end
    mdl_last = HaramiVid.last
    assert_redirected_to harami_vid_url(mdl_last)
    assert_equal "youtu.be/0040", mdl_last.uri
    assert_equal newnote, mdl_last.note
    assert_equal newtit,  mdl_last.title
    assert_equal Music.last, mdl_last.musics.first
    assert_equal mu_name,    mdl_last.musics.first.title
    assert_equal "youtu.be/0040", mdl_last.uri

    # Existing Music (with no Artist)
    old_mu = musics(:music_light)
    mu_name = old_mu.title  # existing Music
    hsnew = {uri: "https://www.youtube.com/watch?v="+(newuri="0050abcde"), title: (newtit="new50"), music_name: mu_name, note: (newnote=mu_name+" is added.")}
    assert_no_difference("Artist.count + Engage.count +  EventItem.count + ArtistMusicPlay.count") do
      assert_difference("Music.count + HaramiVidMusicAssoc.count", 1) do  # only association is added.
        assert_no_difference("Channel.count") do  # existing Channel is found
          assert_difference("HaramiVid.count") do
            post harami_vids_url, params: { harami_vid: @def_create_params.merge(hsnew)}
            assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
          end
        end
      end
    end
    mdl_last = HaramiVid.last
    assert_redirected_to harami_vid_url(mdl_last)
    assert_equal "youtu.be/"+newuri, mdl_last.uri
    assert_equal newnote, mdl_last.note
    assert_equal newtit,  mdl_last.title
    assert_equal old_mu,  mdl_last.musics.first
    assert_equal mu_name, mdl_last.musics.first.title

end
    # New Artist with Existing Music
    old_mu = musics(:music_light)
    mu_name = old_mu.title  # existing Music
    art_name = "My new Artist 6"
#if false
if true
    hsnew = {uri: "https://"+(newuri="some.com/0060?a=4&b=5"), title: (newtit="new60"), music_name: mu_name, artist_name: art_name, note: (newnote=art_name+" is added.")}
    assert_difference("Artist.count + Engage.count +  EventItem.count + ArtistMusicPlay.count", 2) do
      assert_difference("Music.count + HaramiVidMusicAssoc.count", 1) do  # only association with HaramiVid is added.
        assert_no_difference("Channel.count") do  # existing Channel is found
          assert_difference("HaramiVid.count") do
            post harami_vids_url, params: { harami_vid: @def_create_params.merge(hsnew)}
            assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
          end
        end
        # print "DEBUG:res-hv-dont: "; p HaramiVidMusicAssoc.order(created_at: :desc).limit(2)
      end
    end
    mdl_last = HaramiVid.last
    assert_redirected_to harami_vid_url(mdl_last)
    assert_equal newuri,  mdl_last.uri
    assert_equal newnote, mdl_last.note
    assert_equal newtit,  mdl_last.title
    assert_equal old_mu,  mdl_last.musics.first
    assert_equal mu_name, mdl_last.musics.first.title
    eng_last = Engage.last
    assert_equal art_name, eng_last.artist.title
    assert_equal old_mu,   eng_last.music
    assert_equal @def_update_params["form_engage_hows"].to_i,  eng_last.engage_how.id
    assert_equal @def_update_params["form_engage_year"].to_i,  eng_last.year
    assert_equal @def_update_params["form_engage_contribution"].to_f, eng_last.contribution
end

    # A collab-Artist, existing Music with existing Artist
    old_mu = musics(:music_light)
    old_art= artists(:artist_proclaimers)  # who is engaged with :music_light
    collab_art = artists(:artist_rcsuccession)  # no engagement with :music_light
    pla = places(:perth_aus)  # relevant because a new EventItem is to be created.
    name_a = collab_art.title
    assert_equal old_art, old_mu.artists.first, "check fixture"
    assert_includes old_mu.artists, old_art,    "check fixture"
    refute_includes old_mu.artists, collab_art, "check fixture"
    mu_name = old_mu.title  # existing Music
    hsnew = {uri: "https://"+(newuri="youtu.be/0070?t=5")+"&si=xyz&link=youtu.be", title: (newtit="new70"), music_name: mu_name, artist_name: old_art.title, artist_name_collab: name_a, place: pla, note: (newnote=name_a+" collaborates.")}
    hvid6_prms = @def_create_params.merge(hsnew)
    assert_no_difference("Event.count", 0) do
      assert_difference("EventItem.count + HaramiVidEventItemAssoc.count + ArtistMusicPlay.count", 2) do  # no change in EventItem (non-default (=not-unknown) existing one is used).
        assert_no_difference("Artist.count + Engage.count") do
          assert_difference("Music.count + HaramiVidMusicAssoc.count", 1) do  # only association is added.
            assert_no_difference("Channel.count") do  # existing Channel is found
              assert_difference("HaramiVid.count") do
                post harami_vids_url, params: { harami_vid: hvid6_prms }
                assert_response :redirect, "note - this has once(!) raised an error of DEBUG(harami_vids_controller.rb:associate_an_event_item) #<ActiveRecord::RecordNotFound: Couldn't find PlayRole with 'id'=996795243> and I do not know why..."  # this should be put inside assert_difference block to detect potential 422
              end
            end
          end
        end
      end
    end
    mdl_last = hvid6 = HaramiVid.last
    assert_redirected_to harami_vid_url(mdl_last)
    assert_equal newuri,  mdl_last.uri
    assert_equal newnote, mdl_last.note
    assert_equal newtit,  mdl_last.title
    assert_equal old_mu,  mdl_last.musics.first

    evit_last = EventItem.last
    assert_equal 1,         mdl_last.event_items.count
    assert_equal @def_update_params[:form_new_event], mdl_last.event_items.first.event.id.to_s
    assert_equal 2,         mdl_last.artist_music_plays.count, "#{mdl_last.artist_music_plays.inspect}"
    assert_equal ArtistMusicPlay, mdl_last.artist_music_plays.first.class
    assert_equal 1,         mdl_last.artist_collabs.count
    assert_equal collab_art,mdl_last.artist_collabs.first


    # Same collab-Artist, existing Music with existing Artist for a different HaramiVid in a different Place
    evt0 = event_groups(:evgr_single_streets).unknown_event
    pla = places(:perth_aus)
    hsnew = {uri: (newuri="youtu.be/0080"), title: (newtit="new80"), music_name: mu_name, artist_name: old_art.title,
             form_new_event: evt0.id.to_s, artist_name_collab: name_a,
             "place.prefecture_id.country_id"=>pla.country.id.to_s, "place.prefecture_id" => pla.prefecture.id.to_s,
             place: pla.id.to_s, note: ("Same artist collaborates with a specified +unknown+ event.")}
    assert_difference("Event.count + EventItem.count", 2) do
      assert_difference("ArtistMusicPlay.count", 1) do  # no change in EventItem (non-default (=not-unknown) existing one is used).
        assert_no_difference("Music.count + Artist.count + Engage.count") do
          assert_difference("HaramiVidMusicAssoc.count + HaramiVidEventItemAssoc.count", 2) do  # only association is added.
            assert_no_difference("Channel.count") do  # existing Channel is found
              assert_difference("HaramiVid.count") do
                post harami_vids_url, params: { harami_vid: @def_create_params.merge(hsnew)}
                assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
              end
            end
          end
        end
      end
    end

    mdl_last = HaramiVid.last
    evit_last = EventItem.last
    assert_equal 1,         mdl_last.event_items.count
    assert_equal evit_last, mdl_last.event_items.first
    assert_equal Event.last, evit_last.event
    assert_equal pla,       evit_last.place, "Event=#{evit_last.event.inspect}"
    assert_equal 1,         mdl_last.artist_collabs.count
    assert_equal collab_art,mdl_last.artist_collabs.first
    assert_equal collab_art,evit_last.artists.first
    assert_equal old_mu,    evit_last.musics.first

    # Update HaramiVid (hvid6) with a new collab-Artist for an existing Music
    hvid6.reload
    evt0 = event_groups(:evgr_single_streets).unknown_event
    pla = hvid6.place
    art_colla = artists(:artist_zombies)
    assert (art_colla_tit=art_colla.title_or_alt(langcode: "en", lang_fallback_option: :either, str_fallback: nil, article_to_head: true))
    hsnew = {title: nil, langcode: nil,
             event_item_ids: hvid6.event_items.ids,
             form_new_event: "",
             artist_name_collab: art_colla_tit,
             form_new_artist_collab_event_item: hvid6.event_items.first.id.to_s,
             }
    assert_difference("Event.count + EventItem.count", 0) do
      assert_difference("ArtistMusicPlay.count", 1) do  # no change in EventItem (non-default (=not-unknown) existing one is used).
        assert_no_difference("Music.count + Artist.count + Engage.count") do
          assert_difference("HaramiVidMusicAssoc.count + HaramiVidEventItemAssoc.count", 0) do  # existing EventItem is used.
            assert_no_difference("Channel.count") do  # existing Channel is found
              assert_no_difference("HaramiVid.count") do
                patch harami_vid_url(hvid6), params: { harami_vid: hvid6_prms.merge(hsnew) }
                assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
              end
            end
          end
        end
      end
    end

    hvid6.reload
    assert_includes hvid6.artist_collabs, art_colla
    
    #flash_regex_assert(%r@<a [^>]*href="/channels/\d+[^>]*>new Channel.+is created@, msg=nil, type: nil)  # defined in test_helper.rb
  end

  test "should show harami_vid" do
    get harami_vid_url(@harami_vid)
    assert_response :success
  end

  test "should fail to get edit" do
    get edit_harami_vid_url(@harami_vid)
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "should fail to update harami_vid" do
    patch harami_vid_url(@harami_vid), params: { harami_vid: { note: 'abc' } }
  #  assert_redirected_to harami_vid_url(@harami_vid)
    assert_redirected_to new_user_session_path
  end

  test "should destroy harami_vid if privileged" do
    assert_no_difference('HaramiVid.count') do
      delete harami_vid_url(@harami_vid)
      assert_response :redirect
    end
    assert_redirected_to new_user_session_path

    sign_in @editor_harami
    assert_no_difference('HaramiVid.count', "editor cannot destroy, but...") do
      assert_no_difference('HaramiVidMusicAssoc.count') do
        assert_difference('Music.count', 0) do
          assert_difference('Place.count', 0) do
            delete harami_vid_url(@harami_vid)
            my_assert_no_alert_issued(screen_test_only: true)  # defined in /test/test_helper.rb
          end
        end
      end
    end
    sign_out @editor_harami

    sign_in @moderator_harami  # Harami moderator can destroy.
    assert Ability.new(@moderator_harami).can?(:destroy, @harami_vid)
    assert_difference('HaramiVid.count', -1, "HaramiVid should decraese by 1, but...") do
      assert_difference('HaramiVidMusicAssoc.count', -1) do
        assert_difference('Music.count', 0) do
          assert_difference('Place.count', 0) do
            delete harami_vid_url(@harami_vid)
            my_assert_no_alert_issued(screen_test_only: true)  # defined in /test/test_helper.rb
          end
        end
      end
    end
  end

end

