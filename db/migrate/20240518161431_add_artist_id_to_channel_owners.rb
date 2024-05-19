class AddArtistIdToChannelOwners < ActiveRecord::Migration[7.0]
  def change
    add_reference :channel_owners, :artist, null: true, foreign_key: true
  end
end
