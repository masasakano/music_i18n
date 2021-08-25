class AddPageFormatToStaticPages < ActiveRecord::Migration[6.1]
  def change
    remove_column :static_pages, :format_content, :string
    add_reference :static_pages, :page_format, null: false, foreign_key: {on_delete: :restrict}
  end
end
