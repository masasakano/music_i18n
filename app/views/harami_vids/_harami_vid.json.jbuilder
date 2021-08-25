json.extract! harami_vid, :id, :release_date, :duration, :uri, :place_id, :flag_by_harami, :uri_playlist_ja, :uri_playlist_en, :note, :created_at, :updated_at
json.url harami_vid_url(harami_vid, format: :json)
