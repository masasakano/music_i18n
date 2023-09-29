class CreateModelSummaries < ActiveRecord::Migration[7.0]
  def change
    create_table :model_summaries do |t|
      t.string :modelname, null: false
      t.text :note

      t.timestamps
    end
    add_index :model_summaries, :modelname, unique: true
  end
end
