class CreateHaramiVids < ActiveRecord::Migration[6.0]
  def change
    create_table :harami_vids do |t|
      t.date :published_date, comment: 'Published date of the video'
      t.float :duration,      comment: 'Total duration in seconds'
      t.text :uri,            comment: '(YouTube) URI of the video'
      t.references :place, null: true, foreign_key: true, comment: 'The main place where the video was set in'
      t.boolean :flag_by_harami, comment: 'True if published/owned by Harami'
      t.string :uri_playlist_ja, comment: 'URI option part for the YouTube comment of the music list in Japanese'
      t.string :uri_playlist_en, comment: 'URI option part for the YouTube comment of the music list in English'
      t.text :note

      t.timestamps
    end

    add_index :harami_vids, :uri, unique: true #, on_delete: :restrict  # Default
    add_index :harami_vids, :published_date
  end
end
