class CreateDomainTitles < ActiveRecord::Migration[7.0]
  class Translation < ActiveRecord::Base
  end
  class ModelSummary < ActiveRecord::Base
  end

  def change
    create_table :domain_titles, comment: "Domain title of a set of domains including aliases" do |t|
      t.references :site_category, null: false, foreign_key: true
      t.float :weight, comment: "weight to sort this model index"
      t.text :note
      t.text :memo_editor, comment: "Internal-use memo for Editors"

      t.timestamps
    end
    add_index :domain_titles, :weight

    modelname = "DomainTitle"
    reversible do |direction|
      direction.down do
        record = ModelSummary.where(modelname: modelname).first
        record.destroy if record  # This should destroy its Translations
        Translation.where(translatable_type: modelname).delete_all
      end
    end
  end
end
