# coding: utf-8
module HaramiVids::AddMissingMusicToEvitsHelper
  # All Musics that appears in HaramiVidMusicAssoc but not in ArtistMusicPlay
  #
  # If artist is specified, there will be (potentially) more missing Musics,
  # because Musics played by other collab Artists only are also regarded missing.
  #
  # @example
  #    missing_musics_from_evits(hvid: @harami_vid)
  #      # => All Musics included in HaramiVid that no one plays (i.e., inconsistency)
  #    missing_musics_from_evits(hvid: @harami_vid, artist: Artist.default(:HaramiVid))
  #      # => All Musics included in HaramiVid that Default Artist does not play (i.e., no ArtistMusicPlay)
  #
  # @return [Array<Music>]
  def missing_musics_from_evits(harami_vid: @harami_vid, artist: nil)
    exclusions = harami_vid.music_plays
    if artist
      exclusions = exclusions.where("artist_music_plays.artist_id = ?", artist.id)
    end
    return (harami_vid.musics - exclusions).uniq  # distinct would raise PG::InvalidColumnReference (see models/harami_vid.rb)
  end

  # Sets @harami_vid.missing_musics_in_evits for the sake of form (for the default values)
  #
  def set_missing_music_ids(all_missings=nil, harami_vid: @harami_vid)
    utterly_missings = missing_musics_from_evits(harami_vid: harami_vid)  # missing Musics for not only Default Artist but all collaborating Artists
    # all_missings ||= missing_musics_from_evits(artist: Artist.default(:HaramiVid))
    # @harami_vid.missing_music_ids = all_missings.find_all{|emus| utterly_missings.include?(emus)}.map(&:id)

    harami_vid.missing_music_ids = utterly_missings.map(&:id)
  end

  # Returns an Array of [Music-Title, Music-pID] for form
  def collection_missing_musics(all_missings=nil)
    all_missings ||= missing_musics_from_evits(artist: Artist.default(:HaramiVid))
    all_missings.map{|emus| [emus.title_or_alt(lang_fallback_option: :either, article_to_head: true), emus.id]} 
  end
end
