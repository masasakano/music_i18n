class CreateSiteCategories < ActiveRecord::Migration[7.0]
  def change
    create_table :site_categories, comment: "Site category for Uri" do |t|
      t.string :mname, null: false, comment: "Unique machine name"
      t.float :weight
      t.text :summary, index: true, comment: "Short summary"
      t.text :note
      t.text :memo_editor, comment: "Internal-use memo for Editors"

      t.timestamps
    end
    add_index :site_categories, :mname, unique: true
    add_index :site_categories, :weight
  end
end
