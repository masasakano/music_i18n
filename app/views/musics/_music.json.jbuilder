json.extract! music, :id, :year, :place_id, :genre_id, :note, :created_at, :updated_at
json.url music_url(music, format: :json)
