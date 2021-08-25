class Add4uniqueIndexToEngages < ActiveRecord::Migration[6.1]
  def change
    add_index  :engages, [:artist_id, :music_id, :engage_how_id, :year], unique: true, name: 'index_engages_on_4_combinations'
  end
end
