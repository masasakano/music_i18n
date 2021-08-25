class CreatePageFormats < ActiveRecord::Migration[6.1]
  def change
    create_table :page_formats, comment: 'Format of posts like StaticPage' do |t|
      t.string :mname, null: false, comment: 'unique identifier'
      t.text :description
      t.text :note

      t.timestamps
    end
    add_index :page_formats, :mname, unique: true	
  end
end
