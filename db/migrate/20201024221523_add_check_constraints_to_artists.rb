class AddCheckConstraintsToArtists < ActiveRecord::Migration[6.1]
  def change
    add_check_constraint :artists, "birth_year  IS NULL OR birth_year > 0", name: 'check_artists_on_birth_year'
    add_check_constraint :artists, "birth_month IS NULL OR birth_month BETWEEN 1 AND 12", name: 'check_artists_on_birth_month'
    add_check_constraint :artists, "birth_day   IS NULL OR birth_day   BETWEEN 1 AND 31", name: 'check_artists_on_birth_day'
  end

  def down
    remove_check_constraint :artists, name: 'check_artists_on_birth_year'
    remove_check_constraint :artists, name: 'check_artists_on_birth_month'
    remove_check_constraint :artists, name: 'check_artists_on_birth_day'
  end
end
