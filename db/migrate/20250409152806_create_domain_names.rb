class CreateDomainNames < ActiveRecord::Migration[7.0]
  def change
    create_table :domain_names, comment: "Single domain name of all the alias domains" do |t|
      t.references :site_category, null: false, foreign_key: true
      t.float :weight, comment: "weight to sort this model index"
      t.text :note
      t.text :memo_editor, comment: "Internal-use memo for Editors"

      t.timestamps
    end
    add_index :domain_names, :weight
  end
end
