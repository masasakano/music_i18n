class CreateStaticPages < ActiveRecord::Migration[6.1]
  def change
    create_table :static_pages, comment: 'Static HTML Pages' do |t|
      t.string :langcode, null: false
      t.string :mname,    null: false, comment: 'machine name'
      t.string :title,    null: false
      t.string :format_content
      t.text :summary
      t.text :content
      t.text :note, comment: "Remark for editors"

      t.timestamps
    end

    add_index :static_pages, [:langcode, :mname], unique: true	
    add_index :static_pages, [:langcode, :title], unique: true	
  end
end
