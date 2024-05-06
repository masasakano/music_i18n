class AddPublishDateToEventItems < ActiveRecord::Migration[7.0]
  def change
    add_column :event_items, :publish_date, :date, comment: "First broadcast date, esp. when the recording date is unknown"
  end
end
