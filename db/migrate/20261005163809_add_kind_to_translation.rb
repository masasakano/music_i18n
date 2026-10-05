class AddKindToTranslation < ActiveRecord::Migration[8.1]
  def change
    add_column :translations, :kind, :string, default: "alt", null: false
    add_column :translations, :start_year, :integer
    add_column :translations, :end_year, :integer
    add_column :translations, :is_true_name, :boolean, default: nil, comment: "Person's true name"
    add_column :translations, :is_for_record, :boolean, default: false, null: false, comment: "Rarely used"
    add_column :translations, :is_formal, :boolean, default: nil, comment: "Most formal for langcode"
    add_column :translations, :is_official, :boolean, default: nil, comment: "Ofiicial translation"
    add_column :translations, :is_literal, :boolean, default: false, null: false, comment: "Literan translation"
    add_column :translations, :is_internal, :boolean, default: false, null: false, comment: "Internal use only"
    add_column :translations, :memo_editor, :text

    add_index :translations, :kind
    add_index :translations, :start_year
    add_index :translations, :end_year
    add_index :translations, :is_true_name
    add_index :translations, :is_for_record
    add_index :translations, :is_formal
    add_index :translations, :is_official
    add_index :translations, :is_literal
    add_index :translations, :is_internal
    add_index :translations, :note
    add_index :translations, :memo_editor

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE translations
          SET memo_editor = note,
              note = NULL
          WHERE note IS NOT NULL AND note != '';
        SQL
      end

      dir.down do
        execute <<~SQL
          UPDATE translations
          SET note = CASE
            WHEN note IS NULL OR note = '' THEN memo_editor
            ELSE note || '

' || memo_editor
          END
          WHERE memo_editor IS NOT NULL AND memo_editor != '';
        SQL
      end
    end  # reversible do |dir|
  end  # def change
end    # class AddKindToTranslation < ActiveRecord::Migration[8.1]

