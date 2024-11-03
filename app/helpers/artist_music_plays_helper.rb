# coding: utf-8
module ArtistMusicPlaysHelper

  # Returns 3 sorted Arrays: db_column_names, 4-component Table head labels and lower_case symbols
  #
  # In HaramiVid-show/edit, the ArtistMusicPlays table in is sorted
  # in order of Music as appearing in HaramiVid and then Artist.
  #
  # In ArtistMusicPlays::EditMultis, from which +distinguished_artist+ should be
  # specified non-nil, the priority in the order is reversed, i.e., Artist first.
  #
  # This method returns the ordered/sorted Array needed for Table, depending on +distinguished_artist+
  #
  # The last Array is Symbols of methods to extract a Model from {ArtistMusicPlay}, e.g., +:play_role+
  #
  # @param distinguished_artist [NilClass, Artist]
  # @return [Array] db_column_names, Table-headers, Symbols-Table-data
  def get_ordered_amp_arrays(distinguished_artist=nil)
    db_columns = %w(dummy_music_id artist_id)
    th_labels4 = %i(Music Artist)
    td_attrs4  = %i(music artist)

    if distinguished_artist
      db_columns.reverse!
      th_labels4.reverse!
      td_attrs4.reverse!
    end

    db_columns += %w(play_role_id instrument_id)
    th_labels4 += %i(PlayRole Instrument_pl_short) 
    th_labels4.map!{|i| I18n.t(i)}
    td_attrs4 += [:play_role, :instrument]

    db_columns.map!{|es|
      ("dummy_music_id" == es) ? "harami_vid_music_assocs.timing" : "artist_music_plays."+es
    }

    [db_columns, th_labels4, td_attrs4]
  end

  # Returns HaramiVidMusicAssocs-joined ArtistMusicPlays for HaramiVid
  #
  # @param artist_music_plays [Relation] of {ArtistMusicPlay}-s
  # @param ordered_db_columns [Array<String>] DB-column-names to use to sort Relation. See {#get_ordered_amp_arrays}
  # @param harami_vid: [ActiveRecord] HaramiVid. If this is specified, +artist_music_plays+ is for the HaramiVid. If not it is for an EventItem (it can be for mutiple EventItem-s, if desired).
  # @return [Relation]
  def hvma_joined_artist_music_plays(rela_base, ordered_db_columns, harami_vid: nil)
   rela_base =
     if harami_vid
       rela_base.joins(event_item: :harami_vids).joins("INNER JOIN harami_vid_music_assocs ON harami_vid_music_assocs.harami_vid_id = harami_vids.id")
     else
       rela_base.joins("INNER JOIN harami_vid_event_item_assocs ON harami_vid_event_item_assocs.event_item_id = artist_music_plays.event_item_id").joins("INNER JOIN harami_vid_music_assocs ON harami_vid_music_assocs.harami_vid_id = harami_vid_event_item_assocs.harami_vid_id")
     end
   rela_base = rela_base.where('artist_music_plays.music_id = harami_vid_music_assocs.music_id')
   rela_base.order(*ordered_db_columns)
  end
end
