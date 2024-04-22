json.extract! channel_owner, :id, :themselves, :note, :created_at, :updated_at
json.url channel_owner_url(channel_owner, format: :json)
