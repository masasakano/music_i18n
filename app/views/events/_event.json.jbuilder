json.extract! event, :id, :start_time, :start_time_err, :duration_hour, :weight, :event_group_id, :place_id, :note, :created_at, :updated_at
json.url event_url(event, format: :json)
