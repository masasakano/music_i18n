class AddNotMusicToHarami1129 < ActiveRecord::Migration[6.0]
  def change
    add_column :harami1129s, :not_music, :boolean, comment: 'TRUE if not for music but announcement etc'
  end
end
