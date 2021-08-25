class CreateHaramiVidMusicAssocs < ActiveRecord::Migration[6.0]
  def change
    create_table :harami_vid_music_assocs do |t|
      t.references :harami_vid, null: false, foreign_key: {on_delete: :cascade}
      t.references :music,      null: false, foreign_key: {on_delete: :cascade}
      t.integer :timing,      comment: 'Startint time in second'
      t.float :completeness,  comment: 'The ratio of the completeness in duration of the played music'
      t.boolean :flag_collab, comment: 'False if it is not a solo playing'
      t.text :note

      t.timestamps
    end

    add_index :harami_vid_music_assocs, [:harami_vid_id, :music_id], unique: true, name: 'index_unique_harami_vid_music'
  end
end
