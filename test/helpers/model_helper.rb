# coding: utf-8
#require "test_helper"

class ActiveSupport::TestCase

  # Tests the consistency in {Music}-related associations for a HaramiVid
  #
  # @param hvid [HaramiVid]
  def assert_consistent_music_assocs_for_harami_vid(hvid)
    bind = caller_locations(1,1)[0]  # Ruby 2.0+
    caller_info = sprintf "%s:%d", bind.absolute_path.sub(%r@.*(/test/)@, '\1'), bind.lineno
    # NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"

    onwer_artist = hvid.channel_owner.artist if hvid.channel && hvid.channel_owner.themselves

    ((mu4assoc=hvid.musics) + (mu4evit=hvid.music_plays)).sort.uniq.each do |emu|
      next @allowed[:harami_vid_music_assoc_musics].include?(emu)
      msg1 = "(#{caller_info}) In HaramiVid (note=#{str2identify_fixture(hvid)}), "
      msg2 = "Music (#{str2identify_fixture(emu)})"
      msg3 = " is in "
      evits = hvid.event_items.pluck(:machine_title)
      assert_includes mu4assoc, emu, msg1+msg2+msg3+"ArtistMusicPlay (HaramiVidEventItemAssoc) but not in HaramiVidMusicAssoc."
      assert_includes mu4evit,  emu, msg1+msg2+msg3+"HaramiVidMusicAssoc but not in ArtistMusicPlay (through HaramiVidEventItemAssoc for EventItems(machine_title)=#{evits.pluck(:machine_title).inspect})."
      amps = hvid.artist_music_plays.where("artist_music_plays.music_id" => emu.id)
      evits = hvid.event_items
      msg4 = "there should be an ArtistMusicPlay for " 
      msg = msg1 + msg4 + "the default Artist "+msg2
      assert amps.any?{|amp| evits.include?(amp.event_item) && amp.artist == @def_artist}, msg
      if onwer_artist
        msg = msg1 + msg4 + "a ChnnelOwner=Artist (#{str2identify_fixture(onwer_artist, note_label: 'Artist.note')}) for "+msg2
        assert(amps.any?{|amp| evits.include?(amp.event_item) && amp.artist == onwer_artist}, msg)
      end
    end
  end

  # Tests the consistency in {Music}-related associations for a HaramiVid
  #
  # @param hvid [HaramiVid]
  def assert_consistent_event_item_harami_vid_1129(h1129, hvid: nil, evit_ids: nil)
    bind = caller_locations(1,1)[0]  # Ruby 2.0+
    caller_info = sprintf "%s:%d", bind.absolute_path.sub(%r@.*(/test/)@, '\1'), bind.lineno
    # NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"

    hvid ||= h1129.harami_vid
    return if !hvid || !(h1129_evit=h1129.event_item)
    evit_ids ||= hvid.event_items.ids
    assert_includes evit_ids, h1129_evit.id, "(#{caller_info}) EventItem (#{str2identify_fixture(h1129_evit, :machine_title)}) of Harami1129 (#{str2identify_fixture(h1129)}) is inconsistent with those of HaraimVid (#{str2identify_fixture(hvid)})"
  end

  # Returns a Harami1129 of a live-streaming with a singer and song and associated HaramiVid and Event
  #
  # @example
  #    h1129 = mk_h1129_live_streaming(__method__.to_s, do_test: true)  # defined in /test/helpers/model_helper.rb
  #    hvid = h1129.harami_vid
  #
  # @param nameroot [String] Root of the names of Singer (Artist), Song (Music), HaramiVid-title, etc.
  # @return [Harami1129]
  def mk_h1129_live_streaming(nameroot="mk_hvid_live_streaming", do_test: false)
    ms = __method__.to_s
    hscorrect = {title: "【生配信】東京リベンジャーズ特集 (nameroot(in #{__method__})=#{nameroot.inspect})", singer: nameroot+"a", song: nameroot+"m", release_date: (rdate=Date.today-2.days), link_root: "youtu.be/"+nameroot, link_time: 778, id_remote: _get_unique_id_remote, last_downloaded_at: DateTime.now}  # defined in test_helper.rb
    h1129 = Harami1129.create_manual!(**hscorrect)
    assert h1129.valid?     if do_test # Should never fail, but playing safe
    assert h1129.created_at if do_test

    str_equation = 'HaramiVid.count*10000 + Artist.count*1000 + Music.count*100 + Engage.count*10'
    str_eq2      = 'HaramiVidEventItemAssoc.count*1000+Event.count*100 + EventItem.count*10 + ArtistMusicPlay.count'

    ## before internal_insertion
    pstat = h1129.populate_status(use_cache: true)
    assert_equal :no_insert, pstat.status(:ins_title) if do_test
    assert_equal "\u274c",   pstat.marker(:ins_title) if do_test
    assert_nil h1129.reload.harami_vid if do_test

    ## run internal_insertion
    if do_test
      str_equation = 'HaramiVid.count*10000 + Artist.count*1000 + Music.count*100 + Engage.count*10'
      assert_difference(str_equation, 11110) do
        h1129.insert_populate
      end
    else
        h1129.insert_populate
    end

    h1129.reload
    assert_operator(h1129.created_at, :<, h1129.harami_vid.created_at, "sanity check. HaramiVid is newly created from h1129.") if do_test
    assert h1129.event_item if do_test

    h1129
  end

  # Returns a String like '"My Title1"; note="Event1ForX"'
  #
  # Perhaps you may put the return inside a pair of parentheses
  def str2identify_fixture(model, title_method=:title, note_label: "note=")
    model.send(title_method).inspect + "; " + note_label + model.note.inspect
  end
end

