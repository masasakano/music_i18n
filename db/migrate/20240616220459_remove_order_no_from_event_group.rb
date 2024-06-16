class RemoveOrderNoFromEventGroup < ActiveRecord::Migration[7.0]
  def change
    remove_column :event_groups, :order_no, :integer
  end
end
