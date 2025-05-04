class RemoveWikiJaFromArtists < ActiveRecord::Migration[7.0]
  def change
    remove_column :artists, :wiki_en, :text
    remove_column :artists, :wiki_ja, :text
  end
end
