class CreateSexTrans < ActiveRecord::Migration[6.0]
  def change
    create_table :sex_trans do |t|
      t.string :name, null: false
      t.string :ruby
      t.string :alt_name
      t.string :langcode, null: false
      t.string :romaji
      t.string :alt_ruby
      t.string :alt_romaji
      t.boolean :is_orig
      t.integer :weight
      t.text :ref1
      t.text :ref2
      t.text :note
      t.integer :created_by
      t.integer :updated_by
      t.references :sex, null: false, foreign_key: true

      t.timestamps
    end

    add_index :sex_trans, [:name, :langcode], unique: true  # words for en-GB and en-US may be the same.
    add_index :sex_trans, [:langcode]
  end
end
