class RenameColumnPublishedDateToReleaseDateInHaramiVids < ActiveRecord::Migration[6.1]
  def change
     rename_column :harami_vids, :published_date, :release_date
  end
end
