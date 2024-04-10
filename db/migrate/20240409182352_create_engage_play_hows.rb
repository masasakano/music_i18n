class CreateEngagePlayHows < ActiveRecord::Migration[7.0]
  def change
    create_table :engage_play_hows, comment: "(Music) Instruments for EngageEventItemHow" do |t|
      t.float :weight, null: false, default: 999.0, index: true, comment: "weight for sorting for index."
      t.text :note

      t.timestamps
    end
  end
end
