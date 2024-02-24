class RemoveStartYearFromEventGroups < ActiveRecord::Migration[7.0]
  def up
    remove_column :event_groups, :start_year
    remove_column :event_groups, :start_month
    remove_column :event_groups, :start_day
    remove_column :event_groups, :end_year
    remove_column :event_groups, :end_month
    remove_column :event_groups, :end_day
  end

  def down
    add_column :event_groups, :start_year,  :integer, null: true
    add_column :event_groups, :start_month, :integer, null: true
    add_column :event_groups, :start_day,   :integer, null: true
    add_column :event_groups, :end_year,    :integer, null: true
    add_column :event_groups, :end_month,   :integer, null: true
    add_column :event_groups, :end_day,     :integer, null: true
    add_index :event_groups, :start_year
    add_index :event_groups, :start_month
    add_index :event_groups, :start_day
    # NOTE: end_year etc are not index-ed.

    # Copy data back from (start|end)_date (in rollback)
    EventGroup.all.each do |ea_eg|
      %w(start end).each do |col_prefix|
        err = ea_eg.send(col_prefix+"_date_err")
        err &&= err.day
        artime = TimeAux.adjusted_time_array(ea_eg.send(col_prefix+"_date"), err: err)  # Date, ActiveSupport::Duration (for error of Date) or nil

        ea_eg.record_timestamps = false  ## to suppress updating "updated_at"
        ea_eg.update!(
          (col_prefix+"_year").to_sym  => artime[0],
          (col_prefix+"_month").to_sym => artime[1],
          (col_prefix+"_day").to_sym   => artime[2],
        )
      end # %w(start end).each do |col_prefix|
    end   # EventGroup.all.each do |ea_eg|
  end
end
