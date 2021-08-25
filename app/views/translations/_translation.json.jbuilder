json.extract! translation, :id, :translatable_id, :translatable_type, :langcode, :title, :alt_title, :ruby, :alt_ruby, :romaji, :alt_romaji, :is_orig, :weight, :create_user_id, :update_user_id, :note, :created_at, :updated_at
json.url translation_url(translation, format: :json)
