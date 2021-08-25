class CreateHarami1129s < ActiveRecord::Migration[6.0]
  def change
    create_table :harami1129s do |t|
      t.string :singer
      t.string :song
      t.date :release_date
      t.string :title
      t.string :link_root
      t.integer :link_time
      t.string :ins_singer
      t.string :ins_song
      t.date :ins_release_date
      t.string :ins_title
      t.string :ins_link_root
      t.integer :ins_link_time
      t.timestamp :ins_at
      t.text :note

      t.timestamps
    end

    add_index :harami1129s, :song
    add_index :harami1129s, :ins_song
    add_index :harami1129s, :singer
    add_index :harami1129s, :ins_singer
    add_index :harami1129s, [:link_root,     :link_time],     unique: true
    add_index :harami1129s, [:ins_link_root, :ins_link_time], unique: true
  end
end
