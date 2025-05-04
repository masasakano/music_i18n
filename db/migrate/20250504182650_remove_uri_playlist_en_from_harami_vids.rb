class RemoveUriPlaylistEnFromHaramiVids < ActiveRecord::Migration[7.0]
  def change
    remove_column :harami_vids, :uri_playlist_en, :string, comment: "URI option part for the YouTube comment of the music list in English"
    remove_column :harami_vids, :uri_playlist_ja, :string, comment: "URI option part for the YouTube comment of the music list in Japanese"
  end
end
