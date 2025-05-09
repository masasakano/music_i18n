# coding: utf-8
module HaramiVids::AddMissingMusicToEvitsHelper
  # Returns an Array of [Music-Title, Music-pID] for form
  # 
  # @param all_missings [Music::ActiveRecord_Relation]
  # @return [Array] [Music-Title, Music-pID] for form for missing Musics from ArtistMusicPlay-s
  def collection_missing_musics(all_missings=nil)
    all_missings ||= ((tmp=@harami_vid.missing_music_ids).present? ? tmp : @harami_vid.missing_musics_from_amps(artist: Artist.default(:HaramiVid))).map{|i| HaramiVid.find(i)}  # This statement is not tested.  This is put here to help a developer work out what this method is doing behind the hood...  Here, Artist is specified to get the collection-Array to return, which is conservative because the list may contain more missing records than otherwise)
    all_missings.map{|emus| [emus.title_or_alt(lang_fallback_option: :either, article_to_head: true), emus.id]} 
  end
end
