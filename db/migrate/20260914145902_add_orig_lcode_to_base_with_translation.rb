# Adds `orig_locale` columns to all children of BaseWithTranslation
class AddOrigLcodeToBaseWithTranslation < ActiveRecord::Migration[8.1]
  # % bin/rails r 'Rails.application.eager_load! ; p BaseWithTranslation.descendants.map{_1.name.underscore.pluralize}.sort.map(&:to_sym)'
  TRANSLATABLE_TABLES = [:artists, :channel_owners, :channel_platforms, :channel_types, :channels, :countries, :domain_titles, :engage_hows, :event_groups, :events, :genres, :harami_vids, :instruments, :model_summaries, :musics, :places, :play_roles, :prefectures, :sexes, :site_categories, :urls].freeze

  # Hash of {countries: "Country"} etc.
  TARGET_MODELS = TRANSLATABLE_TABLES.index_with do |table|
    table.to_s.singularize.camelize
  end.freeze

  def up
    # 1. Add `orig_locale` columns
    TARGET_MODELS.each_key do |table|
      add_column table, :orig_locale, :string, limit: 2, comment: "locale of original title"
    end

    # 2. Guard Clause: Check for duplicate `is_orig = true`
    duplicates = exec_query(<<-SQL.squish)
      SELECT translatable_type, translatable_id, COUNT(*) AS orig_count
      FROM translations
      WHERE is_orig = TRUE
      GROUP BY translatable_type, translatable_id
      HAVING COUNT(*) > 1
    SQL

    if duplicates.any?
      details = duplicates.map do |row|
        "  - #{row['translatable_type']} ##{row['translatable_id']} title=#{row['title'].inspect} (#{row['orig_count']} originals)"
      end.join("\n")

      raise StandardError, "\n[Migration Aborted] Multiple translations marked with `is_orig=true`:\n#{details}"
    end

    # 3. Backfill `orig_locale`
    TARGET_MODELS.each do |table, type_name|
      execute <<~SQL.squish
        UPDATE #{table}
        SET orig_locale = (
          SELECT langcode
          FROM translations
          WHERE translatable_type = '#{type_name}'
            AND translatable_id = #{table}.id
            AND is_orig = TRUE
          LIMIT 1
        )
        WHERE EXISTS (
          SELECT 1
          FROM translations
          WHERE translatable_type = '#{type_name}'
            AND translatable_id = #{table}.id
            AND is_orig = TRUE
        )
      SQL
    end
  end

  ## Nothing to do. Make sure that the next migration does the reverse.
  def down
    TARGET_MODELS.each_key do |table|
      remove_column table, :orig_locale, :string
    end
  end
end
