json.extract! channel, :id, :channel_owner_id, :channel_type_id, :channel_platform_id, :note, :created_at, :updated_at
json.url channel_url(channel, format: :json)
