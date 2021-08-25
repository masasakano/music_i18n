class CreateTranslations < ActiveRecord::Migration[6.0]
  def change
    create_table :translations do |t|
      t.references :translatable, polymorphic: true, null: false
      t.string :langcode, null: false
      t.text :title
      t.text :alt_title
      t.text :ruby
      t.text :alt_ruby
      t.text :romaji
      t.text :alt_romaji
      t.boolean :is_orig
      t.float :weight
      t.references :create_user, foreign_key: { to_table: :users }
      t.references :update_user, foreign_key: { to_table: :users }
      t.text :note

      t.timestamps
    end

    add_index :translations, [:langcode, :title, :alt_title, :ruby, :alt_ruby, :romaji, :alt_romaji], unique: true, name: :index_translations_on_six_titles
    add_index :translations, [:create_user_id, :update_user_id]
  end
end
