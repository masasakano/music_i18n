# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2024_02_19_205056) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "artists", force: :cascade do |t|
    t.bigint "sex_id", null: false
    t.bigint "place_id", null: false
    t.integer "birth_year"
    t.integer "birth_month"
    t.integer "birth_day"
    t.text "wiki_ja"
    t.text "wiki_en"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["birth_year", "birth_month", "birth_day"], name: "index_artists_birthdate"
    t.index ["place_id"], name: "index_artists_on_place_id"
    t.index ["sex_id"], name: "index_artists_on_sex_id"
    t.check_constraint "birth_day IS NULL OR birth_day >= 1 AND birth_day <= 31", name: "check_artists_on_birth_day"
    t.check_constraint "birth_month IS NULL OR birth_month >= 1 AND birth_month <= 12", name: "check_artists_on_birth_month"
    t.check_constraint "birth_year IS NULL OR birth_year > 0", name: "check_artists_on_birth_year"
  end

  create_table "countries", force: :cascade do |t|
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "iso3166_a2_code", comment: "ISO-3166-1 Alpha 2 code, JIS X 0304"
    t.string "iso3166_a3_code", comment: "ISO-3166-1 Alpha 3 code, JIS X 0304"
    t.integer "iso3166_n3_code", comment: "ISO-3166-1 Numeric code, JIS X 0304"
    t.boolean "independent", comment: "Independent in ISO-3166-1"
    t.text "territory", comment: "Territory name in ISO-3166-1"
    t.date "start_date"
    t.date "end_date"
    t.text "iso3166_remark", comment: "Remarks in ISO-3166-1, 2, 3"
    t.text "orig_note", comment: "Remarks by HirMtsd"
    t.bigint "country_master_id"
    t.index ["country_master_id"], name: "index_countries_on_country_master_id"
    t.index ["iso3166_a2_code"], name: "index_countries_on_iso3166_a2_code", unique: true
    t.index ["iso3166_a3_code"], name: "index_countries_on_iso3166_a3_code", unique: true
    t.index ["iso3166_n3_code"], name: "index_countries_on_iso3166_n3_code", unique: true
  end

  create_table "country_masters", comment: "Country code in JIS X 0304:2011 and ISO 3166-1:2013", force: :cascade do |t|
    t.string "iso3166_a2_code", comment: "ISO 3166-1 alpha-2, JIS X 0304"
    t.string "iso3166_a3_code", comment: "ISO 3166-1 alpha-3, JIS X 0304"
    t.integer "iso3166_n3_code", comment: "ISO 3166-1 numeric-3, JIS X 0304"
    t.string "name_ja_full"
    t.string "name_ja_short"
    t.string "name_en_full"
    t.string "name_en_short"
    t.string "name_fr_full"
    t.string "name_fr_short"
    t.boolean "independent", comment: "Flag in ISO-3166"
    t.json "territory", comment: "Territory names in ISO-3166-1 in Array"
    t.json "iso3166_remark", comment: "Remarks in ISO-3166-1, 2, 3 in Hash"
    t.text "orig_note", comment: "Remarks by HirMtsd"
    t.date "start_date"
    t.date "end_date"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["iso3166_a2_code"], name: "index_country_masters_on_iso3166_a2_code", unique: true
    t.index ["iso3166_a3_code"], name: "index_country_masters_on_iso3166_a3_code", unique: true
    t.index ["iso3166_n3_code"], name: "index_country_masters_on_iso3166_n3_code", unique: true
  end

  create_table "engage_hows", force: :cascade do |t|
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "weight", default: 999.0
  end

  create_table "engages", force: :cascade do |t|
    t.bigint "music_id", null: false
    t.bigint "artist_id", null: false
    t.float "contribution"
    t.integer "year"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "engage_how_id", null: false
    t.index ["artist_id", "music_id", "engage_how_id", "year"], name: "index_engages_on_4_combinations", unique: true
    t.index ["artist_id"], name: "index_engages_on_artist_id"
    t.index ["engage_how_id"], name: "index_engages_on_engage_how_id"
    t.index ["music_id", "artist_id"], name: "index_engages_on_music_id_and_artist_id"
    t.index ["music_id"], name: "index_engages_on_music_id"
    t.check_constraint "year IS NULL OR year > 0", name: "check_engages_on_year"
  end

  create_table "event_groups", comment: "Event Group, mutually exclusive, typically lasting less than a year", force: :cascade do |t|
    t.integer "order_no", comment: "Serial number for a series of Event Group, e.g., 5(-th)"
    t.integer "start_year"
    t.integer "start_month"
    t.integer "start_day"
    t.integer "end_year"
    t.integer "end_month"
    t.integer "end_day"
    t.bigint "place_id"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_no"], name: "index_event_groups_on_order_no"
    t.index ["place_id"], name: "index_event_groups_on_place_id"
    t.index ["start_day"], name: "index_event_groups_on_start_day"
    t.index ["start_month"], name: "index_event_groups_on_start_month"
    t.index ["start_year"], name: "index_event_groups_on_start_year"
  end

  create_table "genres", force: :cascade do |t|
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "weight", comment: "Smaller means higher in priority."
  end

  create_table "harami1129_reviews", comment: "Harami1129 for which Artist or Music is updated", force: :cascade do |t|
    t.bigint "harami1129_id", comment: "One of Harami1129 this change is applicable to; nullable"
    t.string "harami1129_col_name", null: false, comment: "Either ins_singer or ins_song"
    t.string "harami1129_col_val", comment: "String Value of column harami1129_col_name"
    t.bigint "engage_id", null: false, comment: "Updated Engage"
    t.boolean "checked", default: false, comment: "This record of Harami1129 is manually checked"
    t.bigint "user_id", comment: "Last User that created or updated, or nil"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["engage_id"], name: "index_harami1129_reviews_on_engage_id"
    t.index ["harami1129_col_val"], name: "index_harami1129_reviews_on_harami1129_col_val"
    t.index ["harami1129_id", "harami1129_col_name"], name: "index_harami1129_reviews_unique01", unique: true
    t.index ["harami1129_id"], name: "index_harami1129_reviews_on_harami1129_id"
    t.index ["user_id"], name: "index_harami1129_reviews_on_user_id"
  end

  create_table "harami1129s", force: :cascade do |t|
    t.string "singer"
    t.string "song"
    t.date "release_date"
    t.string "title"
    t.string "link_root"
    t.integer "link_time"
    t.string "ins_singer"
    t.string "ins_song"
    t.date "ins_release_date"
    t.string "ins_title"
    t.string "ins_link_root"
    t.integer "ins_link_time"
    t.datetime "ins_at", precision: nil
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "id_remote", comment: "Row number of the table on the remote URI"
    t.datetime "last_downloaded_at", precision: nil, comment: "Last-checked/downloaded timestamp"
    t.boolean "not_music", comment: "TRUE if not for music but announcement etc"
    t.bigint "harami_vid_id"
    t.bigint "engage_id"
    t.datetime "orig_modified_at", precision: nil, comment: "Any downloaded column modified at"
    t.datetime "checked_at", precision: nil, comment: "Insertion validity manually confirmed at"
    t.index ["checked_at"], name: "index_harami1129s_on_checked_at"
    t.index ["engage_id"], name: "index_harami1129s_on_engage_id"
    t.index ["harami_vid_id"], name: "index_harami1129s_on_harami_vid_id"
    t.index ["id_remote", "last_downloaded_at"], name: "index_harami1129s_on_id_remote_and_last_downloaded_at", unique: true
    t.index ["id_remote"], name: "index_harami1129s_on_id_remote"
    t.index ["ins_link_root", "ins_link_time"], name: "index_harami1129s_on_ins_link_root_and_ins_link_time", unique: true
    t.index ["ins_singer"], name: "index_harami1129s_on_ins_singer"
    t.index ["ins_song"], name: "index_harami1129s_on_ins_song"
    t.index ["link_root", "link_time"], name: "index_harami1129s_on_link_root_and_link_time", unique: true
    t.index ["orig_modified_at"], name: "index_harami1129s_on_orig_modified_at"
    t.index ["singer"], name: "index_harami1129s_on_singer"
    t.index ["song"], name: "index_harami1129s_on_song"
    t.check_constraint "id_remote IS NULL OR id_remote > 0", name: "check_positive_id_remote_on_harami1129s"
  end

  create_table "harami_vid_music_assocs", force: :cascade do |t|
    t.bigint "harami_vid_id", null: false
    t.bigint "music_id", null: false
    t.integer "timing", comment: "Startint time in second"
    t.float "completeness", comment: "The ratio of the completeness in duration of the played music"
    t.boolean "flag_collab", comment: "False if it is not a solo playing"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["harami_vid_id", "music_id"], name: "index_unique_harami_vid_music", unique: true
    t.index ["harami_vid_id"], name: "index_harami_vid_music_assocs_on_harami_vid_id"
    t.index ["music_id"], name: "index_harami_vid_music_assocs_on_music_id"
  end

  create_table "harami_vids", force: :cascade do |t|
    t.date "release_date", comment: "Published date of the video"
    t.float "duration", comment: "Total duration in seconds"
    t.text "uri", comment: "(YouTube) URI of the video"
    t.bigint "place_id", comment: "The main place where the video was set in"
    t.boolean "flag_by_harami", comment: "True if published/owned by Harami"
    t.string "uri_playlist_ja", comment: "URI option part for the YouTube comment of the music list in Japanese"
    t.string "uri_playlist_en", comment: "URI option part for the YouTube comment of the music list in English"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["place_id"], name: "index_harami_vids_on_place_id"
    t.index ["release_date"], name: "index_harami_vids_on_release_date"
    t.index ["uri"], name: "index_harami_vids_on_uri", unique: true
  end

  create_table "model_summaries", force: :cascade do |t|
    t.string "modelname", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["modelname"], name: "index_model_summaries_on_modelname", unique: true
  end

  create_table "musics", force: :cascade do |t|
    t.integer "year"
    t.bigint "place_id", null: false
    t.bigint "genre_id", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["genre_id"], name: "index_musics_on_genre_id"
    t.index ["place_id"], name: "index_musics_on_place_id"
    t.check_constraint "year IS NULL OR year > 0", name: "check_musics_on_year"
  end

  create_table "page_formats", comment: "Format of posts like StaticPage", force: :cascade do |t|
    t.string "mname", null: false, comment: "unique identifier"
    t.text "description"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mname"], name: "index_page_formats_on_mname", unique: true
  end

  create_table "places", force: :cascade do |t|
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "prefecture_id", null: false
    t.index ["prefecture_id"], name: "index_places_on_prefecture_id"
  end

  create_table "prefectures", force: :cascade do |t|
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "country_id", null: false
    t.integer "iso3166_loc_code", comment: "ISO 3166-2:JP (etc) code (JIS X 0401:1973)"
    t.date "start_date"
    t.date "end_date"
    t.text "orig_note", comment: "Remarks by HirMtsd"
    t.index ["country_id"], name: "index_prefectures_on_country_id"
    t.index ["iso3166_loc_code"], name: "index_prefectures_on_iso3166_loc_code", unique: true
  end

  create_table "redirect_rules", id: :serial, force: :cascade do |t|
    t.string "source", null: false, comment: "Matched against the request path"
    t.boolean "source_is_regex", default: false, null: false, comment: "Is the source a regular expression or not"
    t.boolean "source_is_case_sensitive", default: false, null: false, comment: "Is the source regex cas sensitive or not"
    t.string "destination", null: false
    t.boolean "active", default: false, comment: "Should this rule be applied or not"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["active"], name: "index_redirect_rules_on_active"
    t.index ["source"], name: "index_redirect_rules_on_source"
    t.index ["source_is_case_sensitive"], name: "index_redirect_rules_on_source_is_case_sensitive"
    t.index ["source_is_regex"], name: "index_redirect_rules_on_source_is_regex"
  end

  create_table "request_environment_rules", id: :serial, force: :cascade do |t|
    t.integer "redirect_rule_id", null: false
    t.string "environment_key_name", null: false, comment: "Name of the enviornment key (e.g. \"QUERY_STRING\", \"HTTP_HOST\")"
    t.string "environment_value", null: false, comment: "What to match the value of the specified environment attribute against"
    t.boolean "environment_value_is_regex", default: false, null: false, comment: "Is the value match a regex or not"
    t.boolean "environment_value_is_case_sensitive", default: true, null: false, comment: "is the value regex case sensitive or not"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["redirect_rule_id"], name: "index_request_environment_rules_on_redirect_rule_id"
  end

  create_table "role_categories", force: :cascade do |t|
    t.string "mname", null: false
    t.text "note"
    t.bigint "superior_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mname"], name: "index_role_categories_on_mname", unique: true
    t.index ["superior_id"], name: "index_role_categories_on_superior_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "role_category_id", null: false
    t.float "weight"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "uname", comment: "Unique role name"
    t.index ["name", "role_category_id"], name: "index_roles_on_name_and_role_category_id", unique: true
    t.index ["name"], name: "index_roles_on_name"
    t.index ["role_category_id"], name: "index_roles_on_role_category_id"
    t.index ["uname"], name: "index_roles_on_uname", unique: true
    t.index ["weight", "role_category_id"], name: "index_roles_on_weight_and_role_category_id", unique: true
  end

  create_table "sexes", force: :cascade do |t|
    t.integer "iso5218", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["iso5218"], name: "index_sexes_on_iso5218", unique: true
  end

  create_table "static_pages", comment: "Static HTML Pages", force: :cascade do |t|
    t.string "langcode", null: false
    t.string "mname", null: false, comment: "machine name"
    t.string "title", null: false
    t.text "summary"
    t.text "content"
    t.text "note", comment: "Remark for editors"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "page_format_id", null: false
    t.index ["langcode", "mname"], name: "index_static_pages_on_langcode_and_mname", unique: true
    t.index ["langcode", "title"], name: "index_static_pages_on_langcode_and_title", unique: true
    t.index ["page_format_id"], name: "index_static_pages_on_page_format_id"
  end

  create_table "translations", force: :cascade do |t|
    t.string "translatable_type", null: false
    t.bigint "translatable_id", null: false
    t.string "langcode", null: false
    t.text "title"
    t.text "alt_title"
    t.text "ruby"
    t.text "alt_ruby"
    t.text "romaji"
    t.text "alt_romaji"
    t.boolean "is_orig"
    t.float "weight"
    t.bigint "create_user_id"
    t.bigint "update_user_id"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["create_user_id", "update_user_id"], name: "index_translations_on_create_user_id_and_update_user_id"
    t.index ["create_user_id"], name: "index_translations_on_create_user_id"
    t.index ["translatable_id", "translatable_type", "langcode", "title", "alt_title", "ruby", "alt_ruby", "romaji", "alt_romaji"], name: "index_translations_on_9_cols", unique: true
    t.index ["translatable_type", "translatable_id"], name: "index_translations_on_translatable_type_and_translatable_id"
    t.index ["update_user_id"], name: "index_translations_on_update_user_id"
  end

  create_table "user_role_assocs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "role_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["role_id"], name: "index_user_role_assocs_on_role_id"
    t.index ["user_id", "role_id"], name: "index_user_role_assocs_on_user_id_and_role_id", unique: true
    t.index ["user_id"], name: "index_user_role_assocs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at", precision: nil
    t.datetime "confirmation_sent_at", precision: nil
    t.string "unconfirmed_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "display_name", default: "", null: false
    t.string "ext_account_name"
    t.string "uid"
    t.string "provider"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.string "item_type"
    t.string "{:null=>false}"
    t.bigint "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object"
    t.datetime "created_at", precision: nil
    t.text "object_changes"
    t.text "commit_message", comment: "user-added meta data"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "artists", "places"
  add_foreign_key "artists", "sexes"
  add_foreign_key "countries", "country_masters", on_delete: :restrict
  add_foreign_key "engages", "artists", on_delete: :cascade
  add_foreign_key "engages", "engage_hows", on_delete: :restrict
  add_foreign_key "engages", "musics", on_delete: :cascade
  add_foreign_key "event_groups", "places", on_delete: :nullify
  add_foreign_key "harami1129_reviews", "engages", on_delete: :cascade
  add_foreign_key "harami1129_reviews", "harami1129s", on_delete: :nullify
  add_foreign_key "harami1129_reviews", "users", on_delete: :nullify
  add_foreign_key "harami1129s", "engages", on_delete: :restrict
  add_foreign_key "harami1129s", "harami_vids"
  add_foreign_key "harami_vid_music_assocs", "harami_vids", on_delete: :cascade
  add_foreign_key "harami_vid_music_assocs", "musics", on_delete: :cascade
  add_foreign_key "harami_vids", "places"
  add_foreign_key "musics", "genres"
  add_foreign_key "musics", "places"
  add_foreign_key "places", "prefectures", on_delete: :cascade
  add_foreign_key "prefectures", "countries", on_delete: :cascade
  add_foreign_key "roles", "role_categories", on_delete: :cascade
  add_foreign_key "static_pages", "page_formats", on_delete: :restrict
  add_foreign_key "translations", "users", column: "create_user_id"
  add_foreign_key "translations", "users", column: "update_user_id"
  add_foreign_key "user_role_assocs", "roles", on_delete: :cascade
  add_foreign_key "user_role_assocs", "users", on_delete: :cascade
end
