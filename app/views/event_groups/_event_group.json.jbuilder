json.extract! event_group, :id, :order_no, :from_year, :from_month, :from_day, :to_year, :to_month, :to_day, :place_id, :note, :created_at, :updated_at
json.url event_group_url(event_group, format: :json)
