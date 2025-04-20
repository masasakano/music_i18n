class CreateUrls < ActiveRecord::Migration[7.0]
  class Translation < ActiveRecord::Base
  end
  class ModelSummary < ActiveRecord::Base
  end

  def change
    create_table :urls, comment: 'URLs maybe including query parameters' do |t|
      t.string :url, null: false, comment: 'valid URL/URI including https://'
      t.string :url_normalized, comment: 'URL part excluding https://www.' # null is allowed at the DB level but not at Rails
      t.references :domain, null: false, foreign_key: true  # error if Parent Domain is deleted.
      t.string :url_langcode, comment: '2-letter locale code'
      t.float :weight, comment: "weight to sort this model"
      t.date :published_date       # HaramiVid#published_date, but EventItem#publish_date
      t.date :last_confirmed_date
      t.references :create_user, null: true, foreign_key: {to_table: :users, on_delete: :nullify}
      t.references :update_user, null: true, foreign_key: {to_table: :users, on_delete: :nullify}
      t.text :note
      t.text :memo_editor

      t.timestamps
    end

    modelname = "Url"
    reversible do |direction|
      direction.down do
        record = ModelSummary.where(modelname: modelname).first
        record.destroy if record  # This should destroy its Translations
        Translation.where(translatable_type: modelname).delete_all
      end
    end

    add_index :urls, :url
    add_index :urls, :url_normalized
    add_index :urls, :url_langcode
    add_index :urls, [:url, :url_langcode], unique: true
    add_index :urls, :weight
    add_index :urls, :published_date
    add_index :urls, :last_confirmed_date
  end
end
