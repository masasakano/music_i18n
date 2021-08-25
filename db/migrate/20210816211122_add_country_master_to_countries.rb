class AddCountryMasterToCountries < ActiveRecord::Migration[6.1]
  def change
    add_reference :countries, :country_master, foreign_key: {on_delete: :restrict} # allows null
  end
end
