class CreateAnchorings < ActiveRecord::Migration[7.0]
  def change
    create_table :anchorings, comment: "Polymorphic join talbe between Url and others" do |t|
      t.references :url, null: false, foreign_key: {on_delete: :cascade}
      t.references :anchorable, polymorphic: true, null: false
      t.text :note

      t.timestamps
    end

    add_index :anchorings, [:url_id, :anchorable_type, :anchorable_id], unique: true, name: "index_url_anchorables"
  end
end
