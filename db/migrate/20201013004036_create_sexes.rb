class CreateSexes < ActiveRecord::Migration[6.0]
  def change
    create_table :sexes do |t|
      t.integer :iso5218, null: false
      t.text :note

      t.timestamps
    end

    add_index :sexes, [:iso5218], unique: true
  end
end
