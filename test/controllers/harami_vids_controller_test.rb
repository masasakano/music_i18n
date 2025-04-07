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
      # "release_date(1i)"=>"2024", "release_date(2i)"=>"2", "release_date(3i)"=>"28",   ## see below
      "place.prefecture_id.country_id"=>@def_place.country.id.to_s,
      "place.prefecture_id"=>@def_place.prefecture_id.to_s, "place"=>@def_place.id.to_s,
      "form_channel_owner"   =>ChannelOwner.primary.id.to_s,
      "form_channel_type"    =>ChannelType.default(:HaramiVid).id.to_s,
      "form_channel_platform"=>ChannelPlatform.default(:HaramiVid).id.to_s,
      ### (NOT Used anymore) "form_event_items" => [events(:ev_harami_lucky2023).event_items.first, Event.unknown.event_items.first].map(&:id).map(&:to_s),
     # "event_item_ids" => [...]   # existing EventItems, mandatory for update, but should not be usually included in create unless "reference_harami_vid_kwd" is specified with GET
      "form_new_artist_collab_event_item" => HaramiVidsController::DEF_FORM_NEW_ARTIST_COLLAB_EVENT_ITEM_NEW.to_s,  # ==0; For new event.
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
      #"reference_harami_vid_kwd" => "",  # GET parameter
       # "uri_playlist_en"=>"", "uri_playlist_ja"=>"",
    }.merge(
      get_params_from_date_time(Date.new(2024, 2, 28), "release_date")  # defined in application_helper.rb
    ).with_indifferent_access

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

    assert css_select(csstxt0="table.datagrid-table tbody tr").present?
    assert css_select(csstxt0).any?{|esel| !esel.css('td[data-column="title_ja"]')[0].text.blank?}, "JA titles should not be blank in general, but..."
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
    assert_equal n_evit1, css_select('fieldset.harami_vid_event_items input[type="checkbox"]').size, "All EventItems loaded from GET reference_harami_vid_kwd params should be listed, but..."
    assert_equal n_evit1, css_select('fieldset.harami_vid_event_items input[type="checkbox"][checked="checked"]').size
    w3c_validate "HaramiVid new"  # defined in test_helper.rb (see for debugging help)

    get new_harami_vid_url, params: { "reference_harami_vid_kwd" => hv1.id.to_s }  # Invalid parameter for new
    assert_response :unprocessable_entity
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
    memoe = "memo_edit"
    hsnew = {note: "newno", memo_editor: memoe}
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
    assert_equal memoe,   mdl_last.memo_editor
    assert_equal @def_create_params[:title],  mdl_last.title
    assert_equal Channel.default(:HaramiVid), mdl_last.channel
    assert_equal Date.parse("2024-02-28"),    mdl_last.release_date

    # A new Channel is temporarily created but must be rolled-back because HaramiVid was not created after all.
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
    pla_kawaramachi = places(:kawaramachi_station)
    assert pla_unknown_kagawa.encompass_strictly?(pla_kawaramachi), 'sanity check of fixtures...'
    evt_kagawa = Event.default(:HaramiVid, place: pla_unknown_kagawa, save_event: true)
    assert_equal pla_unknown_kagawa, evt_kagawa.place, 'sanity check...'
    hsnew = {uri: uri="youtu.be/0030", form_channel_platform: platform_fb.id, note: "success",
             title: "【瓦町ピアノ】演奏", langcode: "ja",  # existing Place
             "form_new_event" => evt_kagawa.id,
             "place.prefecture_id.country_id"=>pref.country.id.to_s,
             "place.prefecture_id"=>pref.id.to_s, "place"=>pla_kawaramachi.id.to_s,
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
    assert_equal pla_kawaramachi, mdl_last.place, "should have changed, but..."
    refute mdl_last.place.unknown?

    assert_equal 1, mdl_last.event_items.size, 'sanity check'
    evit_last =     mdl_last.event_items.first
    evt_last  = evit_last.event

    assert_equal pla_unknown_kagawa, evt_kagawa.place
    refute_equal evt_kagawa,      evt_last
    assert_equal pla_kawaramachi, evt_last.place # Event#place
    assert  evt_kagawa.open_ended?, 'sanity check'
    assert  evt_last.open_ended?

    evit_pla = evit_last.place  # EventItem#place
    assert  pla_unknown_kagawa.encompass?(evit_pla)
    assert_equal pla_kawaramachi, evit_pla, "Evit#place should have been updated"

     # Start-time of EventItem should have been set with a best guess.
    assert                 mdl_last.release_date
    assert                evit_last.start_time
    assert                evit_last.start_time_err
    hvid_stime     = mdl_last.release_date.to_time(:utc) + 12.hours # midday in UTC
    evit_stime     = evit_last.start_time
    evit_stime_err = evit_last.start_time_err
    assert_operator hvid_stime,          :>, evit_stime
    assert_operator hvid_stime-8.months, :<, evit_stime
    assert_operator 6.months,            :>, evit_stime_err
    assert_operator 20.days,             :<, evit_stime_err
    assert_equal mdl_last.release_date, evit_last.publish_date
    
     # Duration of EventItem should have been set with a best guess.
    hvid_dur = @def_update_params[:duration].to_f
    assert                 mdl_last.duration
    assert_equal hvid_dur, mdl_last.duration
    assert_operator mdl_last.duration, :>, 30    # practically, the test of @def_update_params above
    assert_operator mdl_last.duration, :<, 10000
    assert  evit_last.duration_minute
    refute  evit_last.open_ended?, "The created EventItem should not be open-ended: evit_last.duration_minute = #{evit_last.duration_minute.inspect}"
    assert_operator mdl_last.duration, :<, evit_last.duration_minute.minutes.in_seconds
    assert_operator 1,                 :>, evit_last.duration_minute.minutes.in_hours
    assert_operator mdl_last.duration*0.5, :<, evit_last.duration_err_with_unit.in_seconds, "Raw=#{evit_last.duration_minute_err} converted=#{evit_last.duration_err_with_unit.inspect}"
    assert_operator 1,                     :>, evit_last.duration_err_with_unit.in_hours
    assert_operator evit_last.duration_err_with_unit, :<=, evit_last.duration_minute.minutes, "Error should be (equal to or) smaller than the actual value, but...: #{evit_last.duration_err_with_unit.inspect} !< #{evit_last.duration_minute.minutes.inspect}" ## In this case, the duration is so small (only 1 or 2 minutes), this is actually "equal", which is not a good test; to test it better, you would need a much larger duration of at least over 10 minutes, or better over 20 minutes, because the difference from the original duration in HaramiVid (if not quite the inflated value of EventItem) is 10% only and is snapped to the nearest Integeer.

    ## new Music, no Artist
    mu_name = "My new Music 4 日本の歌"
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
    assert_equal "youtu.be/0040", mdl_last.uri

    mu_last = mdl_last.musics.first
    assert_equal Music.last, mu_last
    assert_equal mu_name,    mu_last.title
    assert       mu_last.place.unknown?
    refute_equal Country.unknown, mu_last.country  # b/c the Music title contains Japanese characters; n.b., I have once tested the opposite by temporarily changing mu_name into one containing only alpha-numerics and confirmed it worked (i.e., this condition is assert==true), although it is not included in this semi-permanent test-suite.
    assert_equal Country['JPN'],  mu_last.country  # Same.

    follow_redirect!
    assert_response :success
    csstmp="section#harami_vids_show_unique_parameters dl dd.item_uri a"
    assert  css_select(csstmp)[0]
    assert_equal "https://"+mdl_last.uri, css_select(csstmp)[0]["href"]

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

    follow_redirect!
    assert_response :success
    csstmp="section#harami_vids_show_unique_parameters dl dd.item_uri a"
    assert  css_select(csstmp)[0]
    assert_equal "https://"+mdl_last.uri, css_select(csstmp)[0]["href"]
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
    hvid6.update!(release_date: hvid6.release_date+1.month)  # so that it is 2 months after EventItem StartTime
    hvid6.reload
    hsnew = {title: "A new from template", langcode: "en",
      "uri"=>"https://youtu.be/A_new_from_template", "duration"=>"780",
      # "release_date(1i)"=>hvid6.release_date.year, "release_date(2i)"=>hvid6.release_date.month, "release_date(3i)"=>hvid6.release_date.day,  ## see below
      "form_channel_owner"   =>ChannelOwner.primary.id.to_s,
      "form_channel_type"    =>ChannelType.default(:HaramiVid).id.to_s,
      "form_channel_platform"=>ChannelPlatform.default(:HaramiVid).id.to_s,
      "place.prefecture_id.country_id"=>hvid6.country.id.to_s,
      "place.prefecture_id"=>hvid6.prefecture.id.to_s, "place"=>hvid6.place.id.to_s,
      "event_item_ids" => hvid6.event_items.ids.map(&:to_s),
      "reference_harami_vid_id" => hvid6.id.to_s,
      "note"=>(newnote_recr="hvid 7 created from ref"),
    }.merge(
      get_params_from_date_time(hvid6.release_date, "release_date")  # defined in application_helper.rb
    ).with_indifferent_access
    assert_equal 1, hvid6.event_items.count, "sanity check..."
    assert  (pl6=hvid6.event_items.first.place), "sanity check..."  # It is UnknownPlace in Shimane
    refute_equal HaramiVid::DEF_PLACE, pl6
    assert HaramiVid::DEF_PLACE, "sanity-check: Place.first=#{Place.first.inspect}"  # This should never fail, but it did in some (rare) odd occasions....
    assert HaramiVid::DEF_PLACE.encompass_strictly?(pl6)
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
             "reference_harami_vid_kwd" => "",
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
    hvid7_prms = hvid7_prms_fail.merge({
             form_new_artist_collab_event_item: HaramiVidsController::DEF_FORM_NEW_ARTIST_COLLAB_EVENT_ITEM_NEW.to_s,
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
    # Tesf of adding a collab-Artist with the existing (freshly created a moment ago) EventItem - should succeed
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
        "reference_harami_vid_kwd" => "",
        form_new_artist_collab_event_item: (evit2chk=hvid6.event_items.first).id.to_s,  # hvid6's own EventItem
        form_new_event: "",
        music_name: mu_tit,
        music_timing: (mu_timing="128"),
        artist_name: art_tit_h7,
        artist_name_collab: "",
        #release_date: hvid6.release_date,
        #"note"=>(hvid6.note+"06"),
        note: (newn = hvid7.note+"04"),
      }
    ).merge(
      get_params_from_date_time(hvid6.release_date, "release_date")  # defined in application_helper.rb
    )
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

    ## check edit screen with GET params reference_harami_vid_kwd

    assert_equal 1, (n_evit5=hvid5.event_items.uniq.size), 'sanity check (but it may change in future - what matter is the relation with the one "after").'
    assert_equal 1, (n_evit6=hvid6.event_items.uniq.size), 'sanity check (but it may change in future - what matter is the relation with the one "after").'
    refute_equal hvid5.event_items.first, hvid6.event_items.first, 'sanity check - no duplication'
    get edit_harami_vid_url(hvid5), params: { "reference_harami_vid_id" => hvid6.id.to_s }  # In GET, it is at the top level and NOT under harami_vids: {}
    assert_response :success
    exp = n_evit5 + n_evit6
    assert_equal exp, css_select('fieldset.harami_vid_event_items input[type="checkbox"]').size
    assert_equal exp, css_select('fieldset.harami_vid_event_items input[type="checkbox"][checked="checked"]').size

    #####
    # Testing auto-update of EventItem Time/Duration in create EventItem
    #
    # 1. When Event is pretty old, but its start_time_err is small and duration is short

    evt_kagawa_unkpla = nil
    assert_difference("Event.count*10 + EventItem.count", 11) do  # 
      evt_kagawa_unkpla = Event.create_basic!(
        title: 'Test Event in Unknown-Place in Kagawa', langcode: "en", is_orig: true,
        place: pla_unknown_kagawa,
        event_group: EventGroup.unknown,
        start_time: (hvid6.release_date - 3.months).to_time,
        start_time_err: 1.days.in_seconds,  # 1 day
        duration_hour: 1.0,
        note: "Event 3 months before HaramiVid with +/- 1 day with 1.0 duration hour",
      )
    end

    hvid6_update_prms = hvid6_prms.merge(
      {
        "reference_harami_vid_kwd" => "",
        # form_new_artist_collab_event_item: HaramiVidsController::DEF_FORM_NEW_ARTIST_COLLAB_EVENT_ITEM_NEW.to_s,  # As in hvid6_prms.
        form_new_event: evt_kagawa_unkpla.id.to_i.to_s,
        note: (newn = hvid6.note+"08"),
        "place.prefecture_id.country_id"=>hvid6.country.id.to_s,
        "place.prefecture_id"=>hvid6.prefecture.id.to_s,
        "place"=>hvid6.place.id.to_s,
        "form_channel_owner"   =>hvid6.channel_owner.id.to_s,
        "form_channel_type"    =>hvid6.channel_type.id.to_s,
        "form_channel_platform"=>hvid6.channel_platform.id.to_s,
        "event_item_ids" => hvid6.event_items.ids.map(&:to_s),
        "artist_name"=>"",
        # "form_engage_hows"=>EngageHow.default(:HaramiVid).id.to_s,
        "form_engage_year"=>"",
        "form_engage_contribution"=>"0.56789",
        # "artist_name_collab"=>"",
        # "form_instrument" => Instrument.default(:HaramiVid).id.to_s,
        # "form_play_role"  => PlayRole.default(:HaramiVid).id.to_s,
        # "music_collab" => "",  # Music to associate (to EventItem, not HaramiVid directly) through ArtistMusicPlay
        # "music_name"=>"",      # Music to associate through HaramiVidMusicAssoc
        # "music_timing"=>"1234",
        # "music_genre"=>Genre.default(:HaramiVid).id.to_s,
        # "music_year"=>"1984",
      }
    ).merge(
      get_params_from_date_time(hvid6.release_date, "release_date")  # defined in application_helper.rb
    )
    new_def_evit = EventItem.last

    old_updated_at = hvid6.updated_at
    assert_equal    1, hvid6.event_items.distinct.count

    assert_difference("Event.count*10 + EventItem.count", 1) do  # a new EventItem (non-default one).
      #assert_difference("ArtistMusicPlay.count", 0) do  # for default Artist's Music-Event-Play
      ## This increases by two --- I haven't worked out why...
        assert_difference("Music.count + Artist.count + Engage.count", 0) do
          assert_difference("HaramiVidMusicAssoc.count*10 + HaramiVidEventItemAssoc.count", 1) do  # change in EventItemAssoc
            assert_no_difference("Channel.count") do  # existing Channel is found
              assert_no_difference("HaramiVid.count") do
                patch harami_vid_url(hvid6), params: { harami_vid: hvid6_update_prms }
                assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
                assert_empty(s=(css_select("#error_explanation_list").to_s), s)
              end
            end
          end
        end
      #end
    end

    new_evit = EventItem.last
    hvid6.reload
    assert_equal newn, hvid6.note
    assert_operator old_updated_at, :<, hvid6.updated_at
    mdl_last = hvid6

    assert_includes hvid6.event_items, new_evit
    assert_equal evt_kagawa_unkpla.place, new_evit.place
    assert_equal new_def_evit.start_time,          new_evit.start_time
    assert_equal evt_kagawa_unkpla.start_time,     new_evit.start_time
    assert_equal evt_kagawa_unkpla.start_time_err, new_evit.start_time_err
    assert_operator evt_kagawa_unkpla.duration_hour.hours, :>, new_evit.duration_minute.minutes

    #####
    # Same  (i.e., Testing auto-update of EventItem Time/Duration in create EventItem)
    #
    # 2. When Event is pretty new with a fairly large start_time_err, and its duration is short
    #    => StartTimes and their errors of Event and Event should agree

    evt_kagawa_unkpla.start_time     = hvid6.release_date.beginning_of_day - 3.days
    evt_kagawa_unkpla.start_time_err = 2.hours.in_seconds
    evt_kagawa_unkpla.save!
    old_updated_at = hvid6.updated_at

    assert_difference("Event.count*10 + EventItem.count", 1) do  # a new EventItem (non-default one).
      #assert_difference("ArtistMusicPlay.count", 0) do  # for default Artist's Music-Event-Play
        assert_difference("Music.count + Artist.count + Engage.count", 0) do
          assert_difference("HaramiVidMusicAssoc.count*10 + HaramiVidEventItemAssoc.count", 1) do  # change in EventItemAssoc
            assert_no_difference("Channel.count") do  # existing Channel is found
              assert_no_difference("HaramiVid.count") do
                patch harami_vid_url(hvid6), params: { harami_vid: hvid6_update_prms.merge({event_item_ids: hvid6.event_items.ids.map(&:to_s)}) }
                assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
                assert_empty(s=(css_select("#error_explanation_list").to_s), s)
              end
            end
          end
        end
      #end
    end

    new_evit = EventItem.last
    hvid6.reload
    #assert_equal newn, hvid6.note
    assert_equal old_updated_at, hvid6.updated_at  # HaramiVid itself does not change.
    mdl_last = hvid6

    assert_includes hvid6.event_items, new_evit
    assert_equal evt_kagawa_unkpla.place, new_evit.place
    refute_equal new_def_evit.start_time,          new_evit.start_time
    assert_equal evt_kagawa_unkpla.start_time,     new_evit.start_time
    assert_equal evt_kagawa_unkpla.start_time_err, new_evit.start_time_err
    assert_operator evt_kagawa_unkpla.duration_hour.hours, :>, new_evit.duration_minute.minutes

    #####
    # Same  (i.e., Testing auto-update of EventItem Time/Duration in create EventItem)
    #
    # 3. When Event is a month old with a smaller start_time_err than Default EventItem created from HaramiVid
    #    => StartTimes and their errors of Event and Event should agree

    evt_kagawa_unkpla.start_time     = hvid6.release_date.beginning_of_day - 40.days
    evt_kagawa_unkpla.start_time_err = 15.days.in_seconds
    evt_kagawa_unkpla.duration_hour = (hvid6.duration.seconds - 2).seconds.in_hours
    evt_kagawa_unkpla.save!
    old_updated_at = hvid6.updated_at

    assert_difference("Event.count*10 + EventItem.count", 1) do  # a new EventItem (non-default one).
      #assert_difference("ArtistMusicPlay.count", 0) do  # for default Artist's Music-Event-Play
        assert_difference("Music.count + Artist.count + Engage.count", 0) do
          assert_difference("HaramiVidMusicAssoc.count*10 + HaramiVidEventItemAssoc.count", 1) do  # change in EventItemAssoc
            assert_no_difference("Channel.count") do  # existing Channel is found
              assert_no_difference("HaramiVid.count") do
                patch harami_vid_url(hvid6), params: { harami_vid: hvid6_update_prms.merge({event_item_ids: hvid6.event_items.ids.map(&:to_s)}) }
                assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
                assert_empty(s=(css_select("#error_explanation_list").to_s), s)
              end
            end
          end
        end
      #end
    end

    new_evit = EventItem.last
    hvid6.reload
    #assert_equal newn, hvid6.note
    assert_equal old_updated_at, hvid6.updated_at  # HaramiVid itself does not change.
    mdl_last = hvid6

    assert_includes hvid6.event_items, new_evit
    assert_equal evt_kagawa_unkpla.place, new_evit.place
    refute_equal new_def_evit.start_time,          new_evit.start_time
    assert_equal evt_kagawa_unkpla.start_time,     new_evit.start_time
    assert_equal evt_kagawa_unkpla.start_time_err, new_evit.start_time_err
    assert_operator evt_kagawa_unkpla.duration_hour.hours,     :>=, new_evit.duration_minute.minutes
    assert_operator evt_kagawa_unkpla.duration_hour.hours*0.9, :<,  new_evit.duration_minute.minutes
    assert_operator evt_kagawa_unkpla.duration_hour.hours,     :>,  new_evit.duration_minute_err.seconds

    ## Testing to confirm no EventItem is created unless "new EventItem" is explicitly specified.

    newnote = "new Note no EI"
    new_prm6 = hvid6_update_prms.merge(
      {
        event_item_ids: hvid6.event_items.ids.map(&:to_s),
        form_new_artist_collab_event_item: hvid6.event_items.last.id.to_s,
        form_new_event: events(:ev_harami_lucky2023).id.to_s,  # No new EventItem should be created
        music_name: "",
        music_collab: "",
        artist_name: "",
        artist_name_collab: "",
        note: newnote,
      })

    assert_no_difference("Event.count*10 + EventItem.count") do  # a new EventItem (non-default one).
      assert_no_difference("ArtistMusicPlay.count") do  # for default Artist's Music-Event-Play
        assert_no_difference("Music.count + Artist.count + Engage.count") do
          assert_no_difference("HaramiVidMusicAssoc.count*10 + HaramiVidEventItemAssoc.count") do  # change in EventItemAssoc
            assert_no_difference("Channel.count") do  # existing Channel is found
              assert_no_difference("HaramiVid.count") do
                patch harami_vid_url(hvid6), params: { harami_vid: new_prm6 }
                assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
                assert_empty(s=(css_select("#error_explanation_list").to_s), s)
              end
            end
          end
        end
      end
    end

    hvid6.reload
    assert_equal newnote, hvid6.note  # HaramiVid is updated, but no EventItem should be created.
    new_evit2 = EventItem.last
    assert_equal new_evit2, new_evit

    ## TODO
    # Check out what happen when duplication between the existing EventItems and GET-specified reference_harami_vid_kwd 
    
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
      note: "old-new data",
      form_new_artist_collab_event_item: HaramiVidsController::DEF_FORM_NEW_ARTIST_COLLAB_EVENT_ITEM_NEW.to_s,
      form_new_event: events(:ev_evgr_mvs_unknown).id,
      music_collab: "",  # ID
      music_name: "",
      music_year: "",
      music_timing: "",
      "music_genre"=>Genre.default(:HaramiVid).id.to_s,
      artist_name: "",
      artist_name_collab: "",
      "form_instrument" => Instrument.default(:HaramiVid).id.to_s,
      "form_play_role"  => PlayRole.default(:HaramiVid).id.to_s,
      "form_engage_hows"=>"",
      "form_engage_year"=>"",
      "form_engage_contribution"=>"",
      "reference_harami_vid_kwd"=>"",  # For GET in new
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


  ##### update EventItem of Harami1129
  test "should update Harami1129.event_item" do
    h1129 = harami1129s(:harami1129_3)
    hvid  = harami_vids(:harami_vid3)
    assert (chan=hvid.channel), 'fixture sanity check'
    assert (pla=hvid.place), 'fixture sanity check'

    assert_equal hvid, h1129.harami_vid, 'fixture sanity check'
    evit  = event_items(:evit_ev_evgr_unknown)
    assert_includes hvid.event_items, evit, 'fixture sanity check (includes)'
    h1129.update!(event_item: evit)

    assert  hvid.duration, 'fixture sanity check'

    # Suppose HavamiVid's associationt to EventItem has disappeared.
    hvid.event_items = []
    assert_empty hvid.event_items
    evit_new = event_items(:evit_ev_evgr_single_streets_unknown_japan_unknown)  # this is the EventItem to replace the current one with
    hvid_ref = harami_vids(:four)  # the new EventItem was referred to from this HaramiVid (via GET in edit); this setting makes this test more realistic
    assert_equal 1, hvid_ref.musics.size
    refute_includes hvid.musics, hvid_ref.musics.first
    # Because the Music of the reference HaramiVid is not included in the HaramiVid, 
    # a new HaramiVidMusicAssoc is created.  (I think I have coded so simply because it would be
    # much easier to destroy the association than creating one, and NOT because this is
    # always desirable.)

    # Adding another EventItem to the HaramiVid should update the corresponding Harami1129#event_item
    hsin = {
      event_item_ids: [evit_new.id.to_s],  # Suppose this was given in edit via GET.
      "place.prefecture_id.country_id"=>pla.country.id.to_s,
      "place.prefecture_id"=>pla.prefecture_id.to_s,
      "place"=>pla.id.to_s,
      "form_channel_owner"   =>chan.channel_owner_id.to_s,
      "form_channel_type"    =>chan.channel_type_id.to_s,
      "form_channel_platform"=>chan.channel_platform_id.to_s,
      form_new_artist_collab_event_item: "",
      form_new_event: "",
      music_collab: "",  # ID
      music_name: "",
      music_year: "",
      music_timing: "",
      "music_genre"=>Genre.default(:HaramiVid).id.to_s,
      artist_name: "",
      artist_name_collab: "",
      "form_instrument" => Instrument.default(:HaramiVid).id.to_s,
      "form_play_role"  => PlayRole.default(:HaramiVid).id.to_s,
      "form_engage_hows"=>"",
      "form_engage_year"=>"",
      "form_engage_contribution"=>"",
      "reference_harami_vid_id"=>hvid_ref.id.to_s,  # For GET in new
      note: (newnote="Updated test 1129"),
    }.with_indifferent_access

    %i(uri duration).each do |ek|
      hsin[ek] = hvid.send(ek)
    end

    hsin.merge!(get_params_from_date_time(hvid.release_date, "release_date", 3)) # defined in application_helper.rb

    sign_in @moderator_all

    assert_difference("ArtistMusicPlay.count", 2) do  # 2 Artist's Music-Event-Play for 2 Musics (?)
      assert_difference("Music.count + Artist.count + Engage.count", 0) do
        #assert_difference("HaramiVidMusicAssoc.count*10 + HaramiVidEventItemAssoc.count", 11) do  # comments out because this might change in the future.
        assert_difference("HaramiVidEventItemAssoc.count", 1) do
          assert_difference("Event.count*11 + EventItem.count", 0) do  # 1 Event + 1 EventItem  (Event created because Place is new for the unknown Event!  If Event was not unknown, the existing one should be used in default. EventItem is an unknown one and default one)
            assert_no_difference("Channel.count") do  # existing Channel is found
              assert_no_difference("HaramiVid.count*10 + Harami1129.count") do
                patch harami_vid_url(hvid), params: { harami_vid: hsin }
                assert_response :redirect  # this should be put inside assert_difference block to detect potential 422
              end
            end
          end
        end
      end
    end

    hvid.reload
    h1129.reload
    assert_equal newnote, hvid.note
    assert_equal hvid, h1129.harami_vid, 'sanity check'
    assert_equal 1, hvid.event_items.count

    assert_equal hvid.event_items.to_a, [h1129.event_item], 'Harami1129#event_item should have been updated, but...'

    # Duration should have been set appropriately ish.
    evit = hvid.event_items.first
    assert_operator hvid.duration, :>, 150
    assert       evit.duration_minute
    assert_operator hvid.duration, :<, evit.duration_minute.minutes.in_seconds
    assert_operator 3,             :>, evit.duration_minute.minutes.in_days
    assert_operator hvid.duration*0.5, :<, evit.duration_err_with_unit.in_seconds, "Raw=#{evit.duration_minute_err} converted=#{evit.duration_err_with_unit.inspect}"
    assert_operator 3,                 :>, evit.duration_err_with_unit.in_days
    assert_operator evit.duration_err_with_unit, :<=, evit.duration_minute.minutes, "Error should be (equal to or) smaller than the actual value, but...: #{evit.duration_err_with_unit.inspect} !< #{evit.duration_minute.minutes.inspect}"
  end


  ##### show
  test "should show harami_vid" do
    assert((memoe=@harami_vid.memo_editor).strip.present?)
    get harami_vid_url(@harami_vid)
    assert_response :success
    w3c_validate "HaramiVid show"  # defined in test_helper.rb (see for debugging help)
    assert_equal 0, css_select("body dd.item_memo_editor").size, "should be Harami editor_only, but..."

    sign_in @editor_harami
    get harami_vid_url(@harami_vid)
    assert_response :success
    w3c_validate "HaramiVid show-editor"  # defined in test_helper.rb (see for debugging help)
    assert_equal 1, css_select("body dd.item_memo_editor").size
    assert_equal memoe, css_select("body dd.item_memo_editor").text.strip
    sign_out @editor_harami
  end

  test "should show MusicAssoc in harami_vid" do
    hvid3 = hvid = harami_vids(:harami_vid3)
    mu1 = hvid.musics.order(Arel.sql('CASE WHEN timing IS NULL THEN 0 ELSE 1 END, timing')).first
    hvma = hvid.harami_vid_music_assocs.where(music: mu1).first
    assert mu1, "sanity check of MusicAssoc fixtures"

    get harami_vid_url(hvid)

    csstxt_tbl = 'table#music_table_for_hrami_vid'
    assert_equal 1, css_select(csstxt_tbl).size
    csstxt_tbl_rows  = csstxt_tbl + ' tbody tr'
    assert_operator 1, :<, css_select(csstxt_tbl_rows).size
    csstxt_tbl_row1td1  = csstxt_tbl_rows + ":first-child td:first-child"
    assert_equal 1, css_select(csstxt_tbl_row1td1).size
    assert_equal "1", css_select(csstxt_tbl_row1td1).first.text.strip  # sequential number
    csstxt_tbl_row1td1_span = csstxt_tbl_row1td1 + " span"
    assert_select csstxt_tbl_row1td1_span
    tag_span = css_select(csstxt_tbl_row1td1_span).first
    assert_match(/sequen/i, tag_span["title"], "Inspect: #{tag_span.inspect}")
    refute_match(/pID/i, tag_span["title"])

#    assert_select csstxt_tbl_row1td1+" a", count: 0
#    # assert_no_select csstxt_tbl_row1td1+" a"  # this raises NoMethodError

    # Checks Other-HaramiVid table
    ms = __method__.to_s
    h1129 = mk_h1129_live_streaming(ms, do_test: true)  # defined in /test/helpers/model_helper.rb
    hvid_created = hvid = h1129.harami_vid
    assert_equal 1, hvid.event_items.count, "sanity check"
    assert hvid.events.first.default?
    hvid.events.first.reload
    assert_operator 1, :<=, hvid.events.first.harami_vids.count, "sanity check"
    assert_equal 1, hvid.events.first.harami_vids.count

    get harami_vid_url(hvid)

    css1_debug = "section#harami_vids_show_other_harami_vids"
    css1       = "section#harami_vids_show_other_harami_vids table tbody tr"
    assert_equal 1, css_select(css1+" td.item_title").size, css_select(css1_debug).to_s

    ## Added a HaramiVid for the Event
    hvid_copied1 = hvid.deepcopy(uri: hvid.uri+"ABC", translation: :default)
    assert_difference('hvid.events.first.harami_vids.count'){
      hvid_copied1.save!
    }
    hvid.events.reset

    get harami_vid_url(hvid)

    assert_equal 2, css_select(css1).size, css_select(css1_debug).to_s
    assert_equal 2, css_select(css1+" td.item_title").size, css_select(css1+" td.item_title").to_s

    ## Added many HaramiVid-s for the Event
    (2..52).each do |num|
      hvid.deepcopy(uri: hvid.uri+"ABC#{num}", translation: :default).save!
    end
    hvid.reload
    assert_equal 53, hvid.other_harami_vids_of_event(exclude_unknown: false, include_self: true).count

    get harami_vid_url(hvid)

    assert_equal 5*3+1, css_select(css1).size #, css_select(css1_debug).to_s  # 5 == config.max_harami_vids_per_event_public; "+1" is necessary as the last row is purely for a notice message of "too many rows" etc.
    assert_equal 5*3,   css_select(css1+" td.item_title").size #, css_select(css1+" td.item_title").to_s

    # Checks with Editor
    hvid = hvid3
    sign_in @editor_harami
    get harami_vid_url(hvid)
    assert_equal "1", css_select(csstxt_tbl_row1td1).first.text.strip  # sequential number
    assert_select csstxt_tbl_row1td1_span

    tag_span = css_select(csstxt_tbl_row1td1_span).first
    assert_match(/sequen/i, tag_span["title"], "Inspect: #{tag_span.inspect}")
    assert_match(/pID=#{hvma.id}/i, tag_span["title"])

    csstxt_tbl_row1tdlast_a = csstxt_tbl_rows + ":first-child td:last-child a"
    assert_select csstxt_tbl_row1tdlast_a
    assert_match(/\b#{hvma.id}\b/i, css_select(csstxt_tbl_row1tdlast_a).text)

    get harami_vid_url(hvid_created)
    assert_equal 15*3+1, css_select(css1).size #, css_select(css1_debug).to_s  # 15 == config.max_harami_vids_per_event_editor; "+1" is necessary as the last row is purely for a notice message of "too many rows" etc.
    assert_equal 15*3,   css_select(css1+" td.item_title").size #, css_select(css1+" td.item_title").to_s
    sign_out @editor_harami
  end

  test "should fail/succeed to get edit" do
    css_evits_fieldset = 'section#form_update_event_item_association_field fieldset'
    css_evits       = css_evits_fieldset + ' input[type="checkbox"]'
    css_evits_label = css_evits_fieldset + ' label'
    css_uri = 'section#sec_primary_input div.harami_vid_uri input'
    uri_hvid1 = @harami_vid.uri

    hvid2 = harami_vids(:harami_vid2)
    refute((evits1=@harami_vid.event_items).empty?, "testing fixtures")
    refute((evits2=      hvid2.event_items).empty?, "testing fixtures")
    assert_equal 1, @harami_vid.events.count, "testing fixtures"  # NOTE: If the number of associated Events (NOT EventItems) is more than 1, the following tests may need updating accordingly.
    assert_equal 1,       hvid2.events.count, "testing fixtures"

    ## By an unauthorized user
    get harami_vid_url(@harami_vid)  # Show is allowed by general users
    assert_response :success
    assert_equal evits1.size, css_select("dd.item_event ol.list_event_items li").size

    get edit_harami_vid_url(@harami_vid)
    assert_response :redirect
    assert_redirected_to new_user_session_path, "Non-authorized users should not be allowed, but..."

    ## By an editor
    sign_in @editor_harami
    get edit_harami_vid_url(@harami_vid)
    assert_response :success
    assert_equal ApplicationHelper.parsed_uri_with_or_not(uri_hvid1).to_s, css_select(css_uri)[0]["value"]  # the value in the form should be a valid URI with a scheme, regardless of how it is stored in the DB.
    assert_equal evits1.size, (css=css_select(css_evits)).size

    # provides pID for a reference HaramiVid
    get edit_harami_vid_url(@harami_vid, params: {reference_harami_vid_id: hvid2.id.to_s})
    assert_response :success
    assert_equal ApplicationHelper.parsed_uri_with_or_not(uri_hvid1).to_s, css_select(css_uri)[0]["value"]
    assert_equal evits1.size + evits2.size, (css=css_select(css_evits)).size, "CSS="+css.to_s+" / "+css_select(css_evits_label).to_s+" / "+evits1.inspect

    # provides URI for a reference (existing) HaramiVid => redirected to "edit"
    get edit_harami_vid_url(@harami_vid, params: {reference_harami_vid_kwd: hvid2.uri})
    assert_response :redirect
    assert_redirected_to edit_harami_vid_path(hvid2, params: {reference_harami_vid_id: @harami_vid.id})
    follow_redirect!
    assert_response :success
    assert_equal evits1.size + evits2.size, (css=css_select(css_evits)).size, "CSS="+css.to_s+" / "+css_select(css_evits_label).to_s+" / "+evits1.inspect
    css = sprintf('%s[value="%s"]', css_uri, ApplicationHelper.normalized_uri_youtube(hvid2.uri, with_scheme: true))
    assert_equal 1, css_select(css).size, "It should be on the edit page of hvid2 now, so the main URI on the form should be as such, but...  html="+css_select(css_uri).to_s

    # provides URI with no HaramiVids matches => redirected to "new"
    tmpuri = "https://www.example.com/aruyo"
    get edit_harami_vid_url(@harami_vid, params: {reference_harami_vid_kwd: tmpuri})
    assert_response :redirect
    assert_redirected_to new_harami_vid_path(params: {reference_harami_vid_id: @harami_vid.id, uri: tmpuri})

    follow_redirect!
    assert_response :success # "new"
    assert_equal evits1.size, (css=css_select(css_evits)).size, "CSS="+css.to_s+" / "+css_select(css_evits_label).to_s+" / "+evits1.inspect
    css = sprintf('%s[value="%s"]', css_uri, ApplicationHelper.normalized_uri_youtube(tmpuri, with_scheme: true))
    assert_equal 1, css_select(css).size, "It should be on the NEW page with a preset URI and with a reference to @harami_vid now, so the main URI on the form should be as such, but...  html="+css_select(css_uri).to_s

    # invalid ID is given as a GET parameter.
    assert_raises(ActiveRecord::RecordNotFound){
      get edit_harami_vid_url(@harami_vid, params: {reference_harami_vid_id: (HaramiVid.last.id+1).to_s})
      #assert_response :unprocessable_entity
    }

    sign_out @editor_harami  # should have been automartically signed out.

    
    [@moderator_harami, @sysadmin].each do |user|
      sign_in user
      #get edit_harami_vid_url(@harami_vid, params: {reference_harami_vid_kwd: hvid2.id})
      get edit_harami_vid_url(@harami_vid, params: {reference_harami_vid_kwd: hvid2.id.to_s})  # pID for "kwd"
      assert_response :redirect
      assert_redirected_to edit_harami_vid_path(hvid2, params: {reference_harami_vid_id: @harami_vid.id})
      follow_redirect!
      assert_response :success
      sign_out user
    end
    w3c_validate "HaramiVid edit"  # defined in test_helper.rb (see for debugging help)
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

