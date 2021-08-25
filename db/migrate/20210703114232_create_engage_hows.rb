class CreateEngageHows < ActiveRecord::Migration[6.1]
  def change
    create_table :engage_hows do |t|
      t.text :note

      t.timestamps
    end
  end
end
