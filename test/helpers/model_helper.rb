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

  # Returns a String like '"My Title1"; note="Event1ForX"'
  #
  # Perhaps you may put the return inside a pair of parentheses
  def str2identify_fixture(model, title_method=:title, note_label: "note=")
    model.send(title_method).inspect + "; " + note_label + model.note.inspect
  end
end

