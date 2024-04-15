class CreateArtistMusicPlays < ActiveRecord::Migration[7.0]
  def change
    create_table :artist_music_plays, comment: "EventItem-Artist-Music-PlayRole-Instrument association" do |t|
      t.references :event_item, null: false, foreign_key: {on_delete: :cascade}
      t.references :artist, null: false, foreign_key: {on_delete: :cascade}
      t.references :music, null: false, foreign_key: {on_delete: :cascade}
      t.references :play_role, null: false, foreign_key: {on_delete: :cascade}
      t.references :instrument, null: false, foreign_key: {on_delete: :cascade}
      t.float :cover_ratio, comment: "How much ratio of Music is played"
      t.float :contribution_artist, comment: "Contribution of the Artist to Music"
      t.text :note

      t.timestamps
    end

    add_index :artist_music_plays, [:event_item_id, :artist_id, :music_id, :play_role_id, :instrument_id], unique: true, name: "index_artist_music_plays_5unique"
  end
end
