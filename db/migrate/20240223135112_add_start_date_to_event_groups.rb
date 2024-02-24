class AddStartDateToEventGroups < ActiveRecord::Migration[7.0]
  def up
    add_column :event_groups, :start_date, :date, null: true, comment: "if null, start date is undefined."
    add_index  :event_groups, :start_date
    add_column :event_groups, :start_date_err, :integer, null: true, comment: "Error of start-date in day. 182 or 183 days for one with only a known year."
    add_column :event_groups, :end_date,   :date, null: true, comment: "if null, end date is undefined."
    add_index  :event_groups, :end_date
    add_column :event_groups, :end_date_err,   :integer, null: true, comment: "Error of end-date in day. 182 or 183 days for one with only a known year."

    colbases = %w(year month day)
    %w(start end).each do |col_prefix|
      old_cols = colbases.map{|ebase| col_prefix+"_"+ebase}
      if old_cols.any?{|es| EventGroup.column_names.include?(es)}
        raise "Only some but not all of #{old_cols.inspect} exist in EventGroup." if !old_cols.all?{|es| EventGroup.column_names.include?(es)}

        EventGroup.all.each do |ea_eg|
          flag_stop = false
          date_prms = colbases.map{|ebase|  # => e.g., [2021, 12, nil]
            next nil if flag_stop  # to avoid unnecessary DB accesses; e.g., if "month" is nil, no need to process "day"
            flag_stop = true if !(prm = ea_eg.send(col_prefix+"_"+ebase))
            prm
          }

          mid_time = TimeAux.converted_middle_time(*date_prms)  # This is TimeWithError, as defined in /lib/time_with_error.rb
          err_in_day = (mid_time.error && mid_time.error.in_days.to_i)  # Integer

          ea_eg.record_timestamps = false  ## to suppress updating "updated_at"
          ea_eg.update!(
            (col_prefix+"_date").to_sym     => mid_time.to_date,
            (col_prefix+"_date_err").to_sym => err_in_day,
          )
        end # EventGroup.all.each do |ea_eg|
      end   # if old_cols.any?{|es| EventGroup.column_names.include?(es)}
    end     # %w(start end).each do |col_prefix|
  end

  def down
    remove_index  :event_groups, :start_date
    remove_column :event_groups, :start_date
    remove_column :event_groups, :start_date_err
    remove_index  :event_groups, :end_date
    remove_column :event_groups, :end_date
    remove_column :event_groups, :end_date_err
  end
end
