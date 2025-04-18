class CreateSiteCategories < ActiveRecord::Migration[7.0]
  class Translation < ActiveRecord::Base
  end
  class ModelSummary < ActiveRecord::Base
  end

  def change
    create_table :site_categories, comment: "Site category for Uri" do |t|
      t.string :mname, null: false, comment: "Unique machine name"
      t.float :weight, comment: "weight to sort this model in index"
      t.text :summary, index: true, comment: "Short summary"
      t.text :note
      t.text :memo_editor, comment: "Internal-use memo for Editors"

      t.timestamps
    end

    modelname = "SiteCategory"
    reversible do |direction|
      direction.down do
        record = ModelSummary.where(modelname: modelname).first
        record.destroy if record  # This should destroy its Translations
        Translation.where(translatable_type: modelname).delete_all
      end
    end

    add_index :site_categories, :mname, unique: true
    add_index :site_categories, :weight
  end
end
