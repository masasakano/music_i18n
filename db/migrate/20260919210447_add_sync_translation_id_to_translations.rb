class AddSyncTranslationIdToTranslations < ActiveRecord::Migration[8.1]
  # This migration adds the optional (=nullable) self-reference as :sync_translation_id
  # to Translation table, which is mostly nil but significant 
  #
  # Before this migration, it is recommended to run the following to ensure
  # that there would be no group of Translations with only is_orig=false
  # or with multiple is_orig=true .
  #
  #   bin/rails "translations:set_missing_is_orig_true_in_translations[true]"
  #   bin/rails "translations:set_missing_is_orig_true_in_translations"
  #   bin/rails "translations:cleanup_duplicate_originals[true]"
  #   bin/rails "translations:cleanup_duplicate_originals"
  #
  # In the above scripts, the latter is more important because duplicated is_orig=true
  # can confuse the following DB handling.
  #
  # In the migration, :sync_translation_id is set with Translation-s of
  # ChannelOwner with +themselves: true+ at its parent Artist's pID.
  #
  # Here is the SQL code (very close to that for UPDATE) to check (verify)
  # what the SQL UPDATE in the following migration does:
  #
  #    WITH target_matches AS (
  #      SELECT
  #        cot.id AS channel_owner_translation_id,
  #        cot.translatable_id AS channel_owner_id,
  #        co.artist_id,
  #        cot.langcode,
  #        artist_trans.langcode AS ar_lc,
  #        artist_trans.id AS new_sync_translation_id,
  #        cot.title AS co_title,
  #        artist_trans.title AS art_title
  #      FROM translations AS cot
  #      JOIN channel_owners AS co
  #        ON cot.translatable_type = 'ChannelOwner'
  #       AND cot.translatable_id = co.id
  #      JOIN (
  #        SELECT DISTINCT ON (translatable_id, langcode) id, translatable_id, langcode, title
  #        FROM translations
  #        WHERE translatable_type = 'Artist'
  #        ORDER BY translatable_id, langcode, weight ASC NULLS LAST, id ASC
  #      ) AS artist_trans
  #        ON artist_trans.translatable_id = co.artist_id
  #       AND artist_trans.langcode = cot.langcode
  #      WHERE co.themselves = TRUE
  #        AND co.artist_id IS NOT NULL
  #    )
  #    SELECT * FROM target_matches;  
  #
  # Once you have run "cleanup_duplicate_originals" and checked the output of
  # the SQL above, you are good to go:
  #
  #    bin/rails db:migrate
  #
  def change
    add_reference :translations,
                  :sync_translation,
                  foreign_key: { to_table: :translations, on_delete: :cascade },
                  index: { unique: true },  # Unique constraint at DB-level
                  null: true

    reversible do |dir|
      dir.up do
        # Backfill sync_translation_id for ChannelOwners where themselves = true
        # Matches each ChannelOwner translation with the Artist translation of same langcode & lowest weight
        execute <<~SQL
          WITH target_matches AS (
            SELECT
              cot.id AS channel_owner_translation_id,
              artist_trans.id AS new_sync_translation_id
            FROM translations AS cot
            JOIN channel_owners AS co
              ON cot.translatable_type = 'ChannelOwner'
             AND cot.translatable_id = co.id
            JOIN (
              SELECT DISTINCT ON (translatable_id, langcode) id, translatable_id, langcode
              FROM translations
              WHERE translatable_type = 'Artist'
              ORDER BY translatable_id, langcode, weight ASC NULLS LAST, id ASC
            ) AS artist_trans
              ON artist_trans.translatable_id = co.artist_id
             AND artist_trans.langcode = cot.langcode
            WHERE co.themselves = TRUE
              AND co.artist_id IS NOT NULL
          )
          UPDATE translations
          SET sync_translation_id = target_matches.new_sync_translation_id
          FROM target_matches
          WHERE translations.id = target_matches.channel_owner_translation_id;
        SQL

      end #     dir.up do
    end   #   reversible do |dir|
  end     # def change
end
