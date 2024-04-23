class CreateChannels < ActiveRecord::Migration[7.0]
  def change
    create_table :channels do |t|
      t.references :channel_owner, null: false, foreign_key: true
      t.references :channel_type, null: false, foreign_key: true
      t.references :channel_platform, null: false, foreign_key: true
      t.text :note

      t.timestamps
    end
  end
end
