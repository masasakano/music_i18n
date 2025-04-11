class CreateDomains < ActiveRecord::Migration[7.0]
  def change
    create_table :domains, comment: "Domain or any subdomain" do |t|
      t.string :domain, comment: "Domain or any subdomain such as abc.def.com"
      t.references :domain_title, null: false, foreign_key: {on_delete: :cascade}
      t.float :weight, comment: "weight to sort this model within DomainTitle"
      t.text :note

      t.timestamps
    end
    add_index :domains, :domain, unique: true
  end
end
