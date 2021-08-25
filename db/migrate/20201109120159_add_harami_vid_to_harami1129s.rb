class AddHaramiVidToHarami1129s < ActiveRecord::Migration[6.0]
  def change
    add_reference :harami1129s, :harami_vid, null: true, foreign_key: true, on_delete: :nullify
  end
end
