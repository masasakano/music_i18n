# coding: utf-8
require 'test_helper'

class PopulatesControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @harami1129 = harami1129s(:harami1129_ewf)
    #@editor = roles(:editor).users.first  # Harami Editor can manage.
    @moderator = roles(:moderator).users.first  # Harami Moderator can manage. (internal_insertion needs moderator!!)
  end

  test "should fail to run update" do
    patch harami1129_populate_url @harami1129
    assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
  end

  test "should update" do
    sign_in @moderator

    # sanity checks (of the fixture)
    assert_nil @harami1129.ins_title
    assert_nil @harami1129.ins_song
    assert_nil @harami1129.ins_singer
    assert_nil @harami1129.ins_link_root
    assert_nil @harami1129.ins_release_date

    assert_difference('Harami1129.count', 0) do
      patch harami1129_internal_insertions_url(@harami1129)
      assert_response :redirect
      assert_redirected_to harami1129_url @harami1129
    end

    @harami1129.reload
    assert_equal @harami1129.title.gsub(/！/, '!'), @harami1129.ins_title
    assert_equal @harami1129.song    , @harami1129.ins_song
    assert_equal @harami1129.singer  , @harami1129.ins_singer
    assert_equal @harami1129.release_date, @harami1129.ins_release_date
    assert       @harami1129.ins_link_root.include? @harami1129.link_root
    japan_unknown = places(:unknown_place_unknown_prefecture_japan)
    assert_equal 1, Event.where(place: japan_unknown).count, 'check fixtures'

    assert_difference('HaramiVid.count*10000 + HaramiVidMusicAssoc.count*1000 + Music.count*100 + Artist.count*10 + Engage.count', 11111) do
      assert_difference('Event.count*100 + EventItem.count*10 + ArtistMusicPlay.count', 11) do
        # See HaramiVid#set_with_harami1129 and especailly a comment in the mid-section.
        # The default Place is Japan for Harami1129 to set in EventItem
        # and EventItem.default for the context of Harami1129 and Place of Japan
        # is a "new" unknown in a new General Event in Japan.
        # For this reason, a new Event and EventItem are created.
        patch harami1129_populate_url(@harami1129)
        assert_response :redirect
        assert_redirected_to harami1129_url @harami1129
      end
    end

    # _weight_user_id_nil?(Translation.last)  # Tha last translation is related to Event with weight of 0, once event_item_id is introduced.

    @harami1129.reload
    assert       @harami1129.harami_vid
    assert       @harami1129.engage
    # Music place is unknown in the world
    assert_equal Place.unknown, @harami1129.engage.music.place
    assert_equal Place.unknown(country: Country.unknown), @harami1129.engage.music.place

    assert @harami1129.event_item
    assert @harami1129.harami_vid.event_items.exists?, "h1129=#{@harami1129.inspect}\n hv=#{@harami1129.harami_vid.inspect}"
    assert @harami1129.harami_vid.event_items.include?(@harami1129.event_item)

    h1129_rc = harami1129s(:harami1129_rcsuccession)
    #assert_difference('HaramiVid.count*10000 + HaramiVidMusicAssoc.count*1000 + Music.count*100 + Artist.count*10 + Engage.count', 11111) do
      assert_difference('Event.count*100 + EventItem.count*10 + ArtistMusicPlay.count', 111) do
        assert_difference('HaramiVidEventItemAssoc.count', 1) do
          patch harami1129_populate_url(h1129_rc)
          assert_response :redirect
        end
      end
    #end
    assert_redirected_to harami1129_url h1129_rc
    h1129_rc.reload
    assert h1129_rc.event_item
    assert h1129_rc.harami_vid.event_items.exists?
    assert h1129_rc.harami_vid.event_items.include?(h1129_rc.event_item)

    ### check re-insert and re-populate
    old_ins_singer = h1129_rc.ins_singer
    old_ins_song   = h1129_rc.ins_song
    old_engage_id  = h1129_rc.engage_id
    old_event_item_id = h1129_rc.event_item_id
    h1129_rc.update!(ins_singer: "", ins_song: "", engage_id: "", event_item_id: "", ins_at: h1129_rc.last_downloaded_at - 2.hours - 1.days)  # no change in harami_vid_id (b/c at the time of writing, there is no UI for it)
    assert_operator h1129_rc.last_downloaded_at, :>, h1129_rc.ins_at

    # reinsertion
    patch harami1129_internal_insertions_url(h1129_rc)
    assert_response :redirect

    # repopulate
    patch harami1129_populate_url(h1129_rc)
    assert_response :redirect

    h1129_rc.reload
    assert_equal old_ins_singer, h1129_rc.ins_singer
    assert_equal old_ins_song,   h1129_rc.ins_song
    assert_equal old_engage_id,  h1129_rc.engage_id
    assert_equal old_event_item_id, h1129_rc.event_item_id
    assert(hvid=h1129_rc.harami_vid)
    assert(evit=h1129_rc.event_item)

    # Harami1129#harami_vid is nullified (but the HaramiVid exists)
    h1129_rc.update!(harami_vid_id: nil)
    assert_nil h1129_rc.harami_vid, "sanity check"
    get harami1129_url(h1129_rc)
    assert_response :success
#puts response.body  ## DEBUG...................

    # repopulate would set the correct HaramiVid as long as the HaramiVid (with the URI) exists.
    assert_no_difference('HaramiVid.count*10000 + HaramiVidMusicAssoc.count*1000 + Music.count*100 + Artist.count*10 + Engage.count') do
      assert_difference('Event.count*100 + EventItem.count*10 + ArtistMusicPlay.count', 0) do
        assert_difference('HaramiVidEventItemAssoc.count', 0) do
          patch harami1129_populate_url(h1129_rc)
          assert_response :redirect
        end
      end
    end
    follow_redirect!
    flash_regex_assert(/\bSuccessfully populated\b/, type: :notice)  # defined in test_helper.rb
    patch harami1129_populate_url(h1129_rc)
    assert_response :redirect

    h1129_rc.reload
    assert_equal hvid, h1129_rc.harami_vid

    # Harami1129#harami_vid is nullified (the HaramiVid has been destroyed).
    h1129_rc.update!(harami_vid_id: nil)
    hvid.destroy!
    assert_nil h1129_rc.harami_vid, "sanity check"
    get harami1129_url(h1129_rc)
    assert_response :success

    # repopulate would not change HaramiVid (to prevent an accidental update of HaramiVid in re-downloading Harami1129 after HaramiVid has been deliberately nullified perhaps because the remote record is wrong)
    assert_no_difference('HaramiVid.count*10000 + HaramiVidMusicAssoc.count*1000 + Music.count*100 + Artist.count*10 + Engage.count') do
      assert_difference('Event.count*100 + EventItem.count*10 + ArtistMusicPlay.count', 0) do
        assert_difference('HaramiVidEventItemAssoc.count', 0) do
          patch harami1129_populate_url(h1129_rc)
          assert_response :redirect
        end
      end
    end
    follow_redirect!
    flash_regex_assert(/\bno associated HaramiVids?\b/, type: :alert)  # defined in test_helper.rb

    h1129_rc.reload
    assert_nil  h1129_rc.harami_vid

    # repopulate with "recreate_harami_vid" option re-creates HaramiVid
    assert_difference('HaramiVid.count*10000 + HaramiVidMusicAssoc.count*1000 + Music.count*100 + Artist.count*10 + Engage.count', 11000) do
      assert_difference('Event.count*100 + EventItem.count*10 + ArtistMusicPlay.count', 0) do
        assert_difference('HaramiVidEventItemAssoc.count', 1) do
          patch harami1129_populate_url(h1129_rc, params: { harami1129: {recreate_harami_vid: "1"} })
          assert_response :redirect
    follow_redirect!
    flash_regex_assert(/\bSuccessfully populated\b/)  # defined in test_helper.rb
    flash_regex_assert(/\bSuccessfully populated\b/, type: :notice)  # defined in test_helper.rb
        end
      end
    end

    h1129_rc.reload
    assert (hvid2=h1129_rc.harami_vid)
    assert_equal h1129_rc.ins_link_root, hvid2.uri
    assert_equal h1129_rc.event_item,    hvid2.event_items.first
    assert_equal h1129_rc.ins_title,     hvid2.title
    assert_equal 1,                      hvid2.musics.size
    assert_equal h1129_rc.ins_song,      hvid2.musics.first.title
    assert_equal h1129_rc.ins_link_time.to_i, hvid2.harami_vid_music_assocs.first.timing
  end

  test "should update with a new Harami1129 with a Japanese singer from internal_insertion to populate" do
    sign_in @moderator

    sample =
      case Harami1129s::DownloadHarami1129::HARAMI1129_HTML_FMT.strip
      when "2022"
        '"嵐","Happiness","2020/1/2","Link→【嵐メドレー】神曲7曲繋げて弾いたらファンの方が…!!【都庁ピアノ】(0:3:3～) https://youtu.be/EjG9phmijIg?t=183s"'
      else
        '"嵐","Happiness","2020/1/2","追記だよ","【嵐メドレー】神曲7曲繋げて弾いたらファンの方が…!!【都庁ピアノ】(0:3:3～) https://youtu.be/EjG9phmijIg?t=183s"'
      end

    html_in = Harami1129s::DownloadHarami1129.generate_sample_html_table(sample)
    h1129 = nil
    assert_difference('Harami1129.count', 1) do
      ret = Harami1129s::DownloadHarami1129.download_put_harami1129s(html_str: html_in)
      assert_equal 1, ret.harami1129s.size
      h1129 = ret.harami1129s.first
    end

    assert_equal "嵐",        h1129.singer
    assert_equal "Happiness", h1129.song
    assert_equal 2,           h1129.release_date.day
    assert_equal 183,         h1129.link_time
    assert_equal 'EjG9phmijIg', h1129.link_root
    assert_equal '【嵐メドレー】神曲7曲繋げて弾いたらファンの方が…!!【都庁ピアノ】', h1129.title  # NOTE: "(0:3:3～)" is automatically removed.

    ## Internal insertion

    assert_difference('Harami1129.count', 0) do
      patch harami1129_internal_insertions_url(h1129)
      assert_response :redirect
      assert_redirected_to harami1129_url h1129
    end

    h1129.reload
    assert_equal h1129.title   , h1129.ins_title
    assert_equal h1129.song    , h1129.ins_song
    assert_equal h1129.singer  , h1129.ins_singer
    assert_equal h1129.release_date, h1129.ins_release_date
    assert       h1129.ins_link_root.include? h1129.link_root

    ## populate

    assert_difference('HaramiVid.count*10000 + HaramiVidMusicAssoc.count*1000 + Music.count*100 + Artist.count*10 + Engage.count', 11111) do
      patch harami1129_populate_url(h1129)
      assert_response :redirect
      assert_redirected_to harami1129_url h1129
    end

    h1129.reload
    assert       h1129.harami_vid
    assert       h1129.engage
    assert_equal h1129.ins_title, h1129.harami_vid.title
    assert_equal h1129.ins_link_root, h1129.harami_vid.uri
    assert_equal 1, h1129.harami_vid.harami_vid_music_assocs.count
    assert_equal h1129.ins_link_time, h1129.harami_vid.harami_vid_music_assocs.first.timing

    music  = h1129.engage.music
    artist = h1129.engage.artist
    assert_equal 1, artist.engages.count
    engage = artist.engages.first

    # place is Japan (because of the Japanese name of the singer)
    assert  music.place.covered_by? Country['JPN']
    assert_equal music.place, artist.place

    assert_equal engage_hows(:engage_how_singer_original), engage.engage_how

    assert_equal 'en', music.orig_langcode
    assert_equal 'ja', artist.orig_langcode
  end

  # If this was placed in helper.rb, the error message does not show even which file calls it!
  #
  # @param translation [Translation]
  # @return [Boolean] true if all are nil
  def _weight_user_id_nil?(translation)
    assert_nil  translation.create_user
    assert_nil  translation.update_user
    assert_equal Float::INFINITY, translation.weight
  end
end

