class RemoveUniqueIndexFromEngages < ActiveRecord::Migration[6.1]
  def up
    remove_index :engages, name: 'index_engages_on_music_id_and_artist_id'  # Remove: unique: true
    add_index    :engages, [:music_id, :artist_id], name: 'index_engages_on_music_id_and_artist_id'
  end

  def down
    remove_index :engages, name: 'index_engages_on_music_id_and_artist_id'
    add_index    :engages, [:music_id, :artist_id], unique: true, name: 'index_engages_on_music_id_and_artist_id'
  end
end
