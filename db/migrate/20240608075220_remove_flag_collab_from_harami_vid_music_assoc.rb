class RemoveFlagCollabFromHaramiVidMusicAssoc < ActiveRecord::Migration[7.0]
  def change
    remove_column :harami_vid_music_assocs, :flag_collab, :boolean
  end
end
