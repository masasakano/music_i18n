# coding: utf-8
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

    @def_place = places(:tocho)
    @def_update_params = {  # NOTE: Identical to @def_create_params except for those unique to create!
      "uri"=>"https://youtu.be/InitialUri", "duration"=>"56",
      "release_date(1i)"=>"2024", "release_date(2i)"=>"2", "release_date(3i)"=>"28",
      "place.prefecture_id.country_id"=>@def_place.country.id.to_s,
      "place.prefecture_id"=>@def_place.prefecture_id.to_s, "place"=>@def_place.id.to_s,
      "form_channel_owner"   =>ChannelOwner.primary.id.to_s,
      "form_channel_type"    =>ChannelType.default(:HaramiVid).id.to_s,
      "form_channel_platform"=>ChannelPlatform.default(:HaramiVid).id.to_s,
      ### (NOT Used anymore) "form_event_items" => [events(:ev_harami_lucky2023).event_items.first, Event.unknown.event_items.first].map(&:id).map(&:to_s),
     # "event_item_ids" => [...]   # existing EventItems, mandatory for update, but should not be usually included in create unless "reference_harami_vid_id" is specified with GET
      "form_new_event" => events(:ev_harami_lucky2023).id.to_s,  # A new EventItem should be created
      "artist_name"=>"",
      "form_engage_hows"=>EngageHow.default(:HaramiVid).id.to_s,
      "form_engage_year"=>"1997",
      "form_engage_contribution"=>"0.5678",
      "artist_name_collab"=>"",
      "form_instrument" => Instrument.default(:HaramiVid).id.to_s,
      "form_play_role"  => PlayRole.default(:HaramiVid).id.to_s,
      "music_collab" => "",  # Music to associate (to EventItem, not HaramiVid directly) through ArtistMusicPlay
      "music_name"=>"",      # Music to associate through HaramiVidMusicAssoc
      "music_timing"=>"1234",
      "music_genre"=>Genre.default(:HaramiVid).id.to_s,
      "music_year"=>"1984",
      "note"=>"",
      #"reference_harami_vid_id" => "",  # GET parameter
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
    if is_env_set_positive?('TEST_STRICT')  # defined in application_helper.rb
      w3c_validate "HaramiVid index"  # defined in test_helper.rb (see for debugging help)
    end  # only if TEST_STRICT, because of invalid HTML for datagrid filter for Range
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
    sign_out @editor_harami

    sign_in @moderator_harami

    hv1 = harami_vids(:one)
    assert_equal 1, (n_evit1=hv1.event_items.uniq.size), 'sanity check (but it may change in future - what matter is the relation with the one "after").'
    get new_harami_vid_url, params: { "reference_harami_vid_id" => hv1.id.to_s }  # In GET, it is at the top level and NOT under harami_vids: {}
    assert_response :success
    assert_equal n_evit1, css_select('fieldset.harami_vid_event_items input[type="checkbox"]').size, "All EventItems loaded from GET reference_harami_vid_id params should be listed, but..."
    assert_equal n_evit1, css_select('fieldset.harami_vid_event_items input[type="checkbox"][checked="checked"]').size
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
    assert_difference("EventItem.count + ArtistMusicPlay.count") do
      assert_no_difference("Music.count + HaramiVidMusicAssoc.count + Artist.count + Engage.count") do
        assert_no_difference("Channel.count") do  # existing Channel is found
          assert_difference("HaramiVid.count + HaramiVidEventItemAssoc.count", 2) do
            post harami_vids_url, params: { harami_vid: @def_create_params.merge(hsnew)}
            assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
          end
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

    # A new Channel is successfully created. Unknown Place (in an existing Prefecture) should be overwritten with a non-unknown, encompassed Place.
    platform_fb = channel_platforms(:channel_platform_facebook)
    pref = prefectures(:kagawa)
    pla_unknown_kagawa = Place.unknown(prefecture: pref)
    pla_kagawa = places(:kawaramachi_station)
    assert pla_unknown_kagawa.encompass_strictly?(pla_kagawa), 'sanity check of fixtures...'
    evt_kagawa = Event.default(:HaramiVid, place: pla_unknown_kagawa, save_event: true)
    assert_equal pla_unknown_kagawa, evt_kagawa.place, 'sanity check...'
    hsnew = {uri: uri="youtu.be/0030", form_channel_platform: platform_fb.id, note: "success",
             title: "【瓦町ピアノ】演奏", langcode: "ja",  # existing Place
             "form_new_event" => evt_kagawa.id,
             "place.prefecture_id.country_id"=>pref.country.id.to_s,
             "place.prefecture_id"=>pref.id.to_s, "place"=>pla_kagawa.id.to_s,
            }
    assert_difference("Event.count*100 + EventItem.count*10 + ArtistMusicPlay.count", 110) do  # New unknown Event for the exact Place is created.
      assert_difference("Channel.count") do
        assert_difference("HaramiVid.count + HaramiVidEventItemAssoc.count", 2) do
          post harami_vids_url, params: { harami_vid: @def_create_params.merge(hsnew)}
          assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
        end
      end
    end
    assert_equal platform_fb, Channel.last.channel_platform
    mdl_last = HaramiVid.last
    assert_equal uri, mdl_last.uri
    assert_equal pla_kagawa, mdl_last.place, "should have changed, but..."
    refute mdl_last.place.unknown?

    # new Music, no Artist
    mu_name = "My new Music 4"
    hsnew = {uri: (newuri="https://www.youtube.com/watch?v=0040"), title: (newtit="new40"), music_name: mu_name, note: (newnote=mu_name+" is added.")}
    assert_difference("EventItem.count*10 + ArtistMusicPlay.count", 11) do  # EventItem(1) + ArtistMusicPlay(HARAMIchan)
      assert_no_difference("Artist.count + Engage.count") do
        assert_difference("Music.count + HaramiVidMusicAssoc.count", 2) do
          assert_no_difference("Channel.count") do  # existing Channel is found
            assert_difference("HaramiVid.count + HaramiVidEventItemAssoc.count", 2) do
              post harami_vids_url, params: { harami_vid: @def_create_params.merge(hsnew)}
              assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
            end
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
    assert_difference("EventItem.count*10 + ArtistMusicPlay.count", 11) do  # EventItem(1) + ArtistMusicPlay(HARAMIchan)
      assert_no_difference("Artist.count + Engage.count") do
        assert_difference("Music.count + HaramiVidMusicAssoc.count", 1) do  # only association is added.
          assert_no_difference("Channel.count") do  # existing Channel is found
            assert_difference("HaramiVid.count + HaramiVidEventItemAssoc.count", 2) do
              post harami_vids_url, params: { harami_vid: @def_create_params.merge(hsnew)}
              assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
            end
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
    assert_difference("EventItem.count*10 + ArtistMusicPlay.count", 11) do  # EventItem(1) + ArtistMusicPlay(HARAMIchan)
      assert_difference("Artist.count*10 + Engage.count", 11) do
        assert_difference("Music.count + HaramiVidMusicAssoc.count", 1) do  # only association with HaramiVid is added.
          assert_no_difference("Channel.count") do  # existing Channel is found
            assert_difference("HaramiVid.count + HaramiVidEventItemAssoc.count", 2) do
              post harami_vids_url, params: { harami_vid: @def_create_params.merge(hsnew)}
              assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
            end
          end
          # print "DEBUG:res-hv-dont: "; p HaramiVidMusicAssoc.order(created_at: :desc).limit(2)
        end
      end
    end
    mdl_last = hvid5 = HaramiVid.last
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
    hsnew = {uri: "https://"+(newuri="youtu.be/0070?t=5")+"&si=xyz&link=youtu.be",
             title: (newtit="new70"),
             music_name: old_mu.title, music_collab: old_mu.id.to_s,  # Because this is for create, the UI does not provide the form for collab-Artist (or its Music "music_collab") anymore... But Controllers still accept it for now.
             artist_name: old_art.title, artist_name_collab: name_a,
             place: pla, note: (newnote=name_a+" collaborates (hvid6).")}
    hvid6_prms = @def_create_params.merge(hsnew)
    evt = Event.find(hvid6_prms["form_new_event"])
    #assert_equal 5, evt.event_items.count, "sanity check"
    assert_equal 1, evt.event_items.first.artist_music_plays.where(artist_id: collab_art.id).count, "sanity check; there is already 1"
    assert_no_difference("Event.count", 0) do
      assert_difference("EventItem.count + ArtistMusicPlay.count", 3) do  # no change in EventItem (non-default (=not-unknown) existing one is used).
        assert_no_difference("Artist.count + Engage.count") do
          assert_difference("Music.count + HaramiVidMusicAssoc.count", 1) do  # only association is added.
            assert_no_difference("Channel.count") do  # existing Channel is found
              assert_difference("HaramiVid.count + HaramiVidEventItemAssoc.count", 2) do
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
    assert_equal 2,         mdl_last.artist_music_plays.count, "#{mdl_last.artist_music_plays.inspect}"  # 2 (=new RC-Succession+HARAMIchan)
    assert_equal ArtistMusicPlay, mdl_last.artist_music_plays.first.class
    assert_equal 2,         mdl_last.artist_collabs.count
    assert_equal 1,         mdl_last.artist_collabs.where.not("artists.id" => Artist.default(:HaramiVid).id).count
    assert_equal collab_art,mdl_last.artist_collabs.first

    assert_equal 1, hvid6.event_items.count, "sanity check..."
    assert_equal 1, hvid6.event_items.first.musics.distinct.count, "sanity check..."  # "first" is ok b/c there is only one EventItem
    assert_equal(*([hvid6.musics, hvid6.event_items.first.musics].map{|emo| emo.order(:id).uniq.map{|i| i.note}}+["sanity check..."]))

    # Same collab-Artist, existing Music with existing Artist for a different HaramiVid in a different Place
    evt0 = event_groups(:evgr_single_streets).unknown_event
    pla = places(:perth_aus)
    hsnew = {uri: (newuri="youtu.be/0080"), title: (newtit="new80"), music_name: mu_name, artist_name: old_art.title,
             form_new_event: evt0.id.to_s, artist_name_collab: name_a, music_collab: old_mu.id.to_s,  # same as above. Forms for specifying collaboration is not provided on create...
             "place.prefecture_id.country_id"=>pla.country.id.to_s, "place.prefecture_id" => pla.prefecture.id.to_s,
             place: pla.id.to_s, note: ("Same artist collaborates with a specified +unknown+ event.")}
    assert_difference("Event.count*10 + EventItem.count", 11) do
      assert_difference("ArtistMusicPlay.count", 2) do  # no change in EventItem (non-default (=not-unknown) existing one is used).
        assert_no_difference("Music.count + Artist.count + Engage.count") do
          assert_difference("HaramiVidMusicAssoc.count + HaramiVidEventItemAssoc.count", 2) do  # only association is added.
            assert_no_difference("Channel.count") do  # existing Channel is found
              assert_difference("HaramiVid.count + HaramiVidEventItemAssoc.count", 2) do
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
    assert_equal 2,         mdl_last.artist_collabs.count
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
             music_name: "",
             music_collab: old_mu.id.to_s,
             artist_name_collab: art_colla_tit,
             form_new_artist_collab_event_item: hvid6.event_items.first.id.to_s,
             duration: "01:03",
             note: hvid6.note,
             }
    assert_equal 1, hvid6.event_items.count, "sanity check..."
    assert_equal 1, hvid6.event_items.first.musics.distinct.count, "sanity check..."  # b/c there is only one EventItem
    assert_equal(*([hvid6.musics, hvid6.event_items.first.musics].map{|emo| emo.order(:id).uniq.map{|i| i.note}}+["sanity check..."]))
    assert_difference("Event.count + EventItem.count", 0) do  # no change in EventItem (non-default (=not-unknown) existing one is used).
      assert_difference("ArtistMusicPlay.count", 1) do
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
    assert_equal art_colla, ArtistMusicPlay.last.artist
    assert_equal 3, (i=hvid6.artist_music_plays.count), "sanity check..."
    assert_equal i, hvid6.event_items.first.artist_music_plays.count, "sanity check..."
    assert_equal 63, hvid6.duration

    ## Update HaramiVid (hvid6) with a new Music and existing Artist
    hvid6.reload
    evt0 = event_groups(:evgr_single_streets).unknown_event
    pla = hvid6.place
    art_add = artists(:artist_zombies)
    assert (art_add_tit=art_add.title_or_alt(langcode: "en", lang_fallback_option: :either, str_fallback: nil, article_to_head: true))
    hsnew = {title: nil, langcode: nil,
             event_item_ids: hvid6.event_items.ids,
             form_new_event: "",
             artist_name: art_add_tit,
             artist_name_collab: "",
             form_new_artist_collab_event_item: (evit2chk=hvid6.event_items.first).id.to_s,
             duration: "01:03",
             music_name: (mu_tit="Five Hundred"),
             music_year: "2004",
             music_timing: "01:12",  # 72 sec
             note: hvid6.note,
             }
    assert_equal 1, hvid6.event_items.count, "sanity check..."
    assert_equal 1, hvid6.event_items.first.musics.distinct.count, "sanity check..."  # b/c there is only one EventItem
    assert_equal 1, evit2chk.musics.size
    assert_equal(*([hvid6.musics, hvid6.event_items.first.musics].map{|emo| emo.order(:id).uniq.map{|i| i.note}}+["sanity check..."]))

    assert_difference("Event.count + EventItem.count", 0) do  # no change in EventItem (non-default (=not-unknown) existing one is used).
      assert_difference("ArtistMusicPlay.count", 1) do
        assert_difference("Music.count + Artist.count + Engage.count", 2) do
          assert_difference("HaramiVidMusicAssoc.count + HaramiVidEventItemAssoc.count", 1) do  # existing EventItem is used.
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
    assert_includes hvid6.artists, art_add
    assert_equal mu_tit,  Music.last.title
    assert_equal art_add, Engage.last.artist
    assert_equal 72,      HaramiVidMusicAssoc.last.timing
    assert_equal Music.last,                     ArtistMusicPlay.last.music
    assert_equal Artist.default(:HaramiVid),     ArtistMusicPlay.last.artist
    assert_equal Instrument.default(:HaramiVid), ArtistMusicPlay.last.instrument
    assert_equal 63, hvid6.duration

    ## Create HaramiVid based on hvid6 (reference_harami_vid_id)
    hsnew = {title: "A new from template", langcode: "en",
      "uri"=>"https://youtu.be/A_new_from_template", "duration"=>"780",
      "release_date(1i)"=>hvid6.release_date.year, "release_date(2i)"=>hvid6.release_date.month, "release_date(3i)"=>hvid6.release_date.day,
      "form_channel_owner"   =>ChannelOwner.primary.id.to_s,
      "form_channel_type"    =>ChannelType.default(:HaramiVid).id.to_s,
      "form_channel_platform"=>ChannelPlatform.default(:HaramiVid).id.to_s,
      "place.prefecture_id.country_id"=>hvid6.country.id.to_s,
      "place.prefecture_id"=>hvid6.prefecture.id.to_s, "place"=>hvid6.place.id.to_s,
      "event_item_ids" => hvid6.event_items.ids.map(&:to_s),
      "reference_harami_vid_id" => hvid6.id.to_s,
      "note"=>(newnote_recr="hvid 7 created from ref"),
    }.with_indifferent_access
    assert_equal 1, hvid6.event_items.count, "sanity check..."
    assert_equal 4, hvid6.artist_music_plays.count, "sanity check..."
    assert_equal 2, hvid6.musics.count, "sanity check..."

    assert_difference("Event.count + EventItem.count", 0) do
      assert_difference("ArtistMusicPlay.count", 0) do  # no change in EventItem (non-default (=not-unknown) existing one is used).
        assert_no_difference("Music.count + Artist.count + Engage.count") do
          assert_difference("HaramiVidMusicAssoc.count*10 + HaramiVidEventItemAssoc.count", 21) do  # existing EventItem is used.
            assert_no_difference("Channel.count") do  # existing Channel is found
              assert_difference("HaramiVid.count", 1) do
                post harami_vids_url, params: { harami_vid: hsnew }  # Keys for many parameters do not exist here.
                assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
              end
            end
          end
        end
      end
    end

    mdl_last = hvid7 = HaramiVid.last
    assert_equal hvid6.event_items.order(:id), mdl_last.event_items.order(:id)
    assert_equal hvid6.release_date, mdl_last.release_date
    assert_equal hvid6.musics.uniq.size, mdl_last.musics.uniq.size
    ary = [hvid6, mdl_last].map{|mo| mo.musics.uniq.sort{|a,b| a.id <=> b.id}}  # "order" does not work well...
    assert_equal(*ary)
    ary = [hvid6, mdl_last].map{|mo| mo.harami_vid_music_assocs.order(:updated_at).last.timing}
    refute_equal(*ary)
    assert_equal hvid6.musics.count, mdl_last.harami_vid_music_assocs.count  # = 2
    assert_nil mdl_last.harami_vid_music_assocs.order(:updated_at).last.timing
    assert_equal newnote_recr, mdl_last.note


    ## Edit HaramiVid that has common EventItems with hvid6
    ## specifing a new Music AND new Artist
    hvid7.reload
    old_updated_at = hvid7.updated_at
    evt0 = event_groups(:evgr_single_streets).unknown_event
    pla = hvid7.place
    art_add = artists(:artist_zombies)
    assert (art_add_tit=art_add.title_or_alt(langcode: "en", lang_fallback_option: :either, str_fallback: nil, article_to_head: true))
    hsnew = {title: nil, langcode: nil,
             uri: hvid7.uri, duration: hvid7.duration,
             "release_date(1i)"=>hvid7.release_date.year, "release_date(2i)"=>hvid7.release_date.month, "release_date(3i)"=>hvid7.release_date.day,
             "form_channel_owner"   =>hvid7.channel_owner.id.to_s,
             "form_channel_type"    =>hvid7.channel_type.id.to_s,
             "form_channel_platform"=>hvid7.channel_platform.id.to_s,
             "place.prefecture_id.country_id"=>hvid7.country.id.to_s,
             "place.prefecture_id"=>hvid7.prefecture.id.to_s, "place"=>hvid7.place.id.to_s,
             "event_item_ids" => hvid7.event_items.ids.map(&:to_s),
             "reference_harami_vid_id" => "",
             "note"=>(hvid7.note+"02"),
             form_new_artist_collab_event_item: (evit2chk=hvid7.event_items.first).id.to_s,
             form_new_event: "",
             music_name: (mu_tit="Six Thousand"),
             music_year: "2004",
             music_timing: "10:12",  # 612 sec
             artist_name: (art_tit_h7=art_tit="Mr New"),
             artist_sex: Sex[0],  # male
             #"form_engage_hows"=>EngageHow.default(:HaramiVid).id.to_s,
             form_engage_year: "2008",
             #"form_engage_contribution"=>"0.5678",
             artist_name_collab: "",
             #"form_instrument" => Instrument.default(:HaramiVid).id.to_s,
             #"form_play_role"  => PlayRole.default(:HaramiVid).id.to_s,
             note: (newn = hvid7.note+"02"),
             }
    hvid7_prms_fail = hvid6_prms.merge(hsnew)
    assert_equal hvid6.event_items.ids.sort, hvid7.event_items.ids.sort, "sanity check..."
    assert_equal 1, hvid7.event_items.count, "sanity check..."
    assert_equal 2, hvid7.event_items.first.musics.distinct.count, "sanity check..."
    assert_equal 2, evit2chk.musics.size
    assert_equal(*([hvid7.musics, hvid7.event_items.first.musics].map{|emo| emo.order(:id).uniq.map{|i| i.note}}+["sanity check..."]))

    ## should fail because hvid6, which shares the specified EventItem, does not have the new Music!  ####
    patch harami_vid_url(hvid7), params: { harami_vid: hvid7_prms_fail }
    assert_response :unprocessable_entity

    ## should succeed now
    hvid7_prms = hvid7_prms_fail.merge({form_new_artist_collab_event_item: "0",
                               form_new_event: evit2chk.event.id.to_s,})

    assert_difference("Event.count + EventItem.count", 1) do  # an EventItem is created
      assert_difference("ArtistMusicPlay.count", 1) do  # for default Artist's Music-Event-Play
        assert_difference("Music.count + Artist.count + Engage.count", 3) do
          assert_difference("HaramiVidMusicAssoc.count*10 + HaramiVidEventItemAssoc.count", 11) do  # new ones are created
            assert_no_difference("Channel.count") do  # existing Channel is found
              assert_no_difference("HaramiVid.count") do
                patch harami_vid_url(hvid7), params: { harami_vid: hvid7_prms }
                assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
                assert_empty(s=(css_select("#error_explanation_list").to_s), s)
              end
            end
          end
        end
      end
    end

    hvid6.reload
    hvid7.reload
    assert_operator old_updated_at, :<, hvid7.updated_at
    mdl_last = hvid7
    mus_hvid7 = hvid7.musics.sort{ |a,b| a.updated_at<=>b.updated_at}.last  # newly created Music
    art_hvid7 = hvid7.artists.sort{|a,b| a.updated_at<=>b.updated_at}.last  # newly created Artist
    assert_equal newn, hvid7.note
    assert_equal    3, hvid7.musics.size
    #assert_equal mu_tit, hvid7.musics.order("musics.updated_at").last.title, "Musics=#{hvid7.musics.to_a}"  # this does not work for some reason...
    assert_equal mu_tit,  mus_hvid7.title
    assert_equal art_tit, art_hvid7.title
    assert_equal Sex[0],  art_hvid7.sex
    assert_equal       1, mus_hvid7.engages.size
    assert_equal       1, art_hvid7.engages.size
    assert_equal mus_hvid7.engages.first, art_hvid7.engages.first
    assert_equal    2008, art_hvid7.engages.first.year
    assert_equal  612, hvid7.harami_vid_music_assocs.order(:updated_at).last.timing
    assert_equal    2, hvid7.event_items.first.musics.distinct.count  # the EventItem still has 2 Musics

    assert_equal    2, hvid7.event_items.count, 'sanity check'  # this was tested above in asseret_difference
    evit7 = EventItem.last
    assert_equal hvid6.event_items.first, hvid7.event_items.order(:id).first, 'sanity check'
    assert_equal hvid6.release_date, hvid7.release_date
    assert_equal hvid6.musics.uniq.size+1, hvid7.musics.uniq.size
    #ary = [hvid7, hvid6].map{|mo| mo.musics.uniq.sort{|a,b| a.id <=> b.id}}  # "order" does not work well...
    #assert_equal(*ary)
    #ary = [hvid7, hvid6].map{|mo| mo.harami_vid_music_assocs.order(:updated_at).last.timing}
    #refute_equal(*ary)

    ######
    # You should not be able to add a Collab-Artist, either, with an EventItem, which is associted with another Hvid that does not have this Music.
    refute hvid6.musics.include?(mus_hvid7), 'sanity check'
    hvid7_prms_collab_fail = hvid7_prms_fail.merge({
        "event_item_ids" => hvid7.event_items.ids.map(&:to_s),
        #form_new_artist_collab_event_item: (evit2chk=hvid7.event_items.first).id.to_s,  # Identical to the one before. This was and is the reason of failure; hvid6 has this EventItem, yet hvid6 does not have the Music below (mu_tit) with which a Collab-Artist is attempted to be added.
        form_new_event: "",
        music_collab: mus_hvid7.id.to_s,  # existing Music
        artist_name: "",
        artist_name_collab: artists(:artist2).title,
      })

    assert_no_difference("Event.count + EventItem.count") do
      patch harami_vid_url(hvid7), params: { harami_vid: hvid7_prms_collab_fail }
      assert_response :unprocessable_entity, 'should raise an error because hvid6 that shares the specified EvnetItem for new-collab is not associated with the music, but...'
    end


    ######
    # Tesf of adding a collab-Artist with the existing, but freshly created, EventItem - should succeed
    hvid7_prms_add_collab_art = hvid7_prms_fail.merge({
        "event_item_ids" => hvid7.event_items.ids.map(&:to_s),
        form_new_artist_collab_event_item: evit7.id.to_s,  # Key
        form_new_event: "",
        music_collab: mus_hvid7.id.to_s,  # existing Music
        artist_name: "",
        artist_name_collab: (art2=artists(:artist2)).title,
      })

    assert_no_difference("Event.count + EventItem.count") do
      assert_difference("ArtistMusicPlay.count", 1) do  # new collab-Artist
        assert_no_difference("Music.count + Artist.count + Engage.count") do
          assert_no_difference("HaramiVidMusicAssoc.count*10 + HaramiVidEventItemAssoc.count") do
            assert_no_difference("Channel.count") do  # existing Channel is found
              assert_no_difference("HaramiVid.count") do
                patch harami_vid_url(hvid7), params: { harami_vid: hvid7_prms_add_collab_art }
                assert_empty(s=(css_select("#error_explanation_list").to_s), s)
                assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
              end
            end
          end
        end
      end
    end

    hvid7.reload
    amp7 = ArtistMusicPlay.last
    assert_equal art2,  amp7.artist
    assert_equal mus_hvid7, amp7.music
    assert_equal evit7, amp7.event_item
    assert_includes hvid7.artist_collabs, art2

    ######
    # update hvid6 with an existing EventItem (of hvid7) with a Music that hvid7 has.
    #  => should succeed
    #     Because hvid7 has the same Music, even though its ArtistMusicPlay referring to the Music refers to a different EventItem
    # Before:
    #   HaramiVidMusicAssoc 1*2 (hvid6+7, Music1)  : "Five Hundred" (and another one)
    #   HaramiVidMusicAssoc 2   (hvid7,   Music2)  : "Six Thousand"
    #   EventItem 1 (=> both hvid6, hvid7)
    #     ArtistMusicPlay-Default-1: (Music1, EventItem1)  : "Five Hundred"
    #   EventItem 2 (=> hvid7)
    #     ArtistMusicPlay-Default-2: (Music2, EventItem2)  : "Six Thousand"
    # After:
    #   HaramiVidMusicAssoc 1*2 (hvid6+7, Music1)  :
    #   HaramiVidMusicAssoc 2*2 (hvid6+7, Music2)  : <= added! (with "hvid6" one)
    #   EventItem 1 (=> both hvid6, hvid7)
    #     ArtistMusicPlay-Default-1: (Music1, EventItem1)  :
    #     ArtistMusicPlay-Default-2: (Music2, EventItem1)  : <= added!
    #   EventItem 2 (=> hvid7)
    #     ArtistMusicPlay-Default-2: (Music2, EventItem2)  :
    #
    # Basically, the default Artist has now two ArtistMusicPlay-s for Music-2 through EventItem-s 1&2.
    # It is usually unnecessary, but it does not do harm.
    # An alternative way to add the Music to hvid6 is to do while
    # creating another EventItem.
    #
    # Ideally, if UI provides the form fields of timing for all the HaramiVids
    # with an EventItem (or provides an option to add the Music to all HaramiVids
    # even with null timings), that would do the job. Future work!
    hvid6_update_prms = hvid6_prms.merge(
      {
        "event_item_ids" => hvid6.event_items.ids.map(&:to_s),
        "reference_harami_vid_id" => "",
        "note"=>(hvid6.note+"06"),
        form_new_artist_collab_event_item: (evit2chk=hvid6.event_items.first).id.to_s,  # hvid6's own EventItem
        form_new_event: "",
        music_name: mu_tit,
        music_timing: (mu_timing="128"),
        artist_name: art_tit_h7,
        artist_name_collab: "",
        note: (newn = hvid7.note+"04"),})
    old_updated_at = hvid6.updated_at
    assert_equal    1, hvid6.event_items.distinct.count
    assert_equal    2, hvid6.musics.size
    assert_equal    2, hvid6.event_items.first.musics.distinct.count  # to check

    assert_difference("Event.count + EventItem.count", 0) do  # no change in EventItem (non-default (=not-unknown) existing one is used).
      assert_difference("ArtistMusicPlay.count", 1) do  # for default Artist's Music-Event-Play
        assert_difference("Music.count + Artist.count + Engage.count", 0) do
          assert_difference("HaramiVidMusicAssoc.count*10 + HaramiVidEventItemAssoc.count", 10) do  # no change in EventItemAssoc as an existing one is used.
            assert_no_difference("Channel.count") do  # existing Channel is found
              assert_no_difference("HaramiVid.count") do
                patch harami_vid_url(hvid6), params: { harami_vid: hvid6_update_prms }
                assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
                assert_empty(s=(css_select("#error_explanation_list").to_s), s)
              end
            end
          end
        end
      end
    end

    hvid6.reload
    hvid7.reload
    assert_equal newn, hvid6.note
    assert_operator old_updated_at, :<, hvid6.updated_at
    mdl_last = hvid6
    mus_hvid6 = hvid6.musics.sort{ |a,b| a.updated_at<=>b.updated_at}.last  # newly created Music
    art_hvid6 = hvid6.artists.sort{|a,b| a.updated_at<=>b.updated_at}.last  # newly created Artist
    assert_equal mus_hvid7, mus_hvid6
    assert_equal    3, hvid6.musics.size
    #assert_equal mu_tit, hvid6.musics.order("musics.updated_at").last.title, "Musics=#{hvid6.musics.to_a}"  # this does not work for some reason...
    assert_equal mu_tit,  mus_hvid6.title
    assert_equal art_tit, art_hvid6.title
    assert_equal Sex[0],  art_hvid6.sex
    assert_equal       1, mus_hvid6.engages.size
    assert_equal       1, art_hvid6.engages.size
    assert_equal mus_hvid6.engages.first, art_hvid6.engages.first
    assert_equal    2008, art_hvid6.engages.first.year
    assert_equal mu_timing.to_i, hvid6.harami_vid_music_assocs.order(:updated_at).last.timing
    assert_equal    1, hvid6.event_items.distinct.count  # this was tested above in asseret_difference
    assert_equal    3, hvid6.event_items.first.musics.distinct.count

    refute_equal hvid6.event_items.last, hvid7.event_items.order(:id).last
    assert_equal hvid6.release_date,     hvid7.release_date
    assert_equal hvid6.musics.uniq.size, hvid7.musics.uniq.size
    ary = [hvid7, hvid6].map{|mo| mo.musics.uniq.sort{|a,b| a.id <=> b.id}}  # "order" does not work well...
    assert_equal(*ary)

    refute_includes hvid6.artist_collabs, art2  # which hvid7 includes.

    ## check edit screen with GET params reference_harami_vid_id

    assert_equal 1, (n_evit5=hvid5.event_items.uniq.size), 'sanity check (but it may change in future - what matter is the relation with the one "after").'
    assert_equal 1, (n_evit6=hvid6.event_items.uniq.size), 'sanity check (but it may change in future - what matter is the relation with the one "after").'
    refute_equal hvid5.event_items.first, hvid6.event_items.first, 'sanity check - no duplication'
    get edit_harami_vid_url(hvid5), params: { "reference_harami_vid_id" => hvid6.id.to_s }  # In GET, it is at the top level and NOT under harami_vids: {}
    assert_response :success
    exp = n_evit5 + n_evit6
    assert_equal exp, css_select('fieldset.harami_vid_event_items input[type="checkbox"]').size
    assert_equal exp, css_select('fieldset.harami_vid_event_items input[type="checkbox"][checked="checked"]').size

    ## TODO
    # Check out what happen when duplication between the existing EventItems and GET-specified reference_harami_vid_id 
    
    #flash_regex_assert(%r@<a [^>]*href="/channels/\d+[^>]*>new Channel.+is created@, msg=nil, type: nil)  # defined in test_helper.rb
  end # test "should create harami_vid" do


  #########################
  ## update handling of old-school data
  test "should update old-school data ok" do
    hvid = harami_vids(:harami_vid5)
    refute  hvid.event_items.exists?, 'test fixtures'  # no EventItem defiend(!)
    refute  hvid.artist_music_plays.exists?, 'test fixtures'
    refute  hvid.channel, 'test fixtures'

    assert_equal 0, hvid.musics.size, 'test fixtures'
    refute_equal Music.first, Music.last
    hvid.musics << Music.first
    hvid.musics << Music.last
    hvid.musics.reset
    assert_equal 2, hvid.musics.size, 'sanity check'

    hsin = {
      # title: nil, langcode: nil, # form should not be given in UI (b/c exclusively for create).
      # event_item_ids:            # form should not be given in UI (b/c no existing EventItem-s for this HaramiVid).
      uri: "https://example.com/aruyo",
      duration: "",
      "release_date(1i)"=>"2024", "release_date(2i)"=>"2", "release_date(3i)"=>"28",
      "place.prefecture_id.country_id"=>@def_place.country.id.to_s,
      "place.prefecture_id"=>@def_place.prefecture_id.to_s,
      "place"=>@def_place.id.to_s,
      "form_channel_owner"   =>ChannelOwner.primary.id.to_s,
      "form_channel_type"    =>ChannelType.default(:HaramiVid).id.to_s,
      "form_channel_platform"=>ChannelPlatform.default(:HaramiVid).id.to_s,
      place: @def_place.id.to_s,
      note: "old-new data",
      form_new_artist_collab_event_item: HaramiVidsController::DEF_FORM_NEW_ARTIST_COLLAB_EVENT_ITEM_NEW.to_s,
      form_new_event: events(:ev_evgr_mvs_unknown).id,
      music_name: "",
      music_year: "",
      music_timing: "",
      "music_genre"=>Genre.default(:HaramiVid).id.to_s, "music_year"=>"1984",
      artist_name: "",
      artist_name_collab: "",
      "form_instrument" => Instrument.default(:HaramiVid).id.to_s,
      "form_play_role"  => PlayRole.default(:HaramiVid).id.to_s,
      "form_engage_hows"=>"",
      "form_engage_year"=>"",
      "form_engage_contribution"=>"",
      "reference_harami_vid_id"=>"",  # For GET in new
    }.with_indifferent_access


    sign_in @moderator_all

    assert_difference("ArtistMusicPlay.count", 2) do  # 2 Artist's Music-Event-Play for 2 Musics
      assert_difference("Music.count + Artist.count + Engage.count", 0) do
        assert_difference("HaramiVidMusicAssoc.count*10 + HaramiVidEventItemAssoc.count", 1) do
          assert_difference("Event.count*11 + EventItem.count", 12) do  # 1 Event + 1 EventItem  (Event created because Place is new for the unknown Event!  If Event was not unknown, the existing one should be used in default. EventItem is an unknown one and default one)
            assert_no_difference("Channel.count") do  # existing Channel is found
              assert_no_difference("HaramiVid.count") do
                patch harami_vid_url(hvid), params: { harami_vid: hsin }
                assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
              end
            end
          end
        end
      end
    end

    hvid.reload
    assert  hvid.channel, 'should have been set up, but...'
    assert_equal 1, hvid.event_items.count
    assert_equal 2, hvid.artist_music_plays.count  # default Artist's AMP
  end


  ##### show
  test "should show harami_vid" do
    get harami_vid_url(@harami_vid)
    assert_response :success
  end

  test "should fail/succeed to get edit" do
    get edit_harami_vid_url(@harami_vid)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor_harami
    get edit_harami_vid_url(@harami_vid, params: {reference_harami_vid_id: harami_vids(:harami_vid2).id})
    assert_response :success

    # invalid ID is given as a GET parameter.
    assert_raises(ActiveRecord::RecordNotFound){
      get edit_harami_vid_url(@harami_vid, params: {reference_harami_vid_id: HaramiVid.last.id+1})
      #assert_response :unprocessable_entity
    }
    sign_out @editor_harami

    
    [@moderator_harami, @sysadmin].each do |user|
      sign_in user
      get edit_harami_vid_url(@harami_vid, params: {reference_harami_vid_id: harami_vids(:harami_vid2).id})
      assert_response :success
      sign_out user
    end
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

