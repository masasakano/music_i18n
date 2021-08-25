class AddIndexToTranslations < ActiveRecord::Migration[6.0]
  # def change
  #   # Modify the index from 7 columns to 9 columns.
  #   remove_index :translations, [:langcode, :title, :alt_title, :ruby, :alt_ruby, :romaji, :alt_romaji], unique: true, name: :index_translations_on_six_titles
  #   add_index    :translations, [:translatable_id, :translatable_type, :langcode, :title, :alt_title, :ruby, :alt_ruby, :romaji, :alt_romaji], unique: true, name: :index_translations_on_9_cols
  # end

  def up
    # Modify the index from 7 columns to 9 columns, .
    remove_index :translations, name: 'index_translations_on_six_titles' #, [:langcode, :title, :alt_title, :ruby, :alt_ruby, :romaji, :alt_romaji], unique: true
    add_index    :translations, [:translatable_id, :translatable_type, :langcode, :title, :alt_title, :ruby, :alt_ruby, :romaji, :alt_romaji], unique: true, name: :index_translations_on_9_cols
  end

  def down
    remove_index :translations, name: 'index_translations_on_9_cols' #, [:translatable_type, :langcode, :title, :alt_title, :ruby, :alt_ruby, :romaji, :alt_romaji], unique: true
    add_index    :translations, [:langcode, :title, :alt_title, :ruby, :alt_ruby, :romaji, :alt_romaji], unique: true, name: :index_translations_on_six_titles
  end
end
