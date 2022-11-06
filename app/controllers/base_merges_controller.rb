
# Superclass of Musics::MergesController etc
class BaseMergesController < ApplicationController
  FORM_MERGE = {
    other_music_id: 'other_music',
    other_music_title: 'other_music_title',
    to_index: 'to_index',
    lang_orig: 'lang_orig',
    lang_trans: 'lang_trans',
    engage: 'engage',
    prefecture_place: 'prefecture_place',
    genre: 'genre',
    year: 'year',
    note: 'note',
  }.with_indifferent_access

end
