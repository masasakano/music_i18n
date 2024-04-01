json.extract! event_item, :id, :machine_title, :start_time, :start_time_err, :duration_minute, :duration_minute_err, :weight, :event_ratio, :event_id, :place_id, :note, :created_at, :updated_at
json.url event_item_url(event_item, format: :json)
