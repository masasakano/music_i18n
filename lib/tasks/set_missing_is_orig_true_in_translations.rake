namespace :translations do
  desc "Set is_orig=true based on language priority [ja, en, fr] when non-nil is_orig child translations exist without one is_orig=true"
  task :set_missing_is_orig_true_in_translations, [:dryrun] => :environment do |_t, args|
    # Check task argument or ENV variable (e.g., DRY_RUN=true or [true]):
    #   bin/rails "translations:set_missing_is_orig_true_in_translations[true]"
    # OR
    #   DRY_RUN=true bin/rails translations:set_missing_is_orig_true_in_translations
    dry_run = args[:dryrun].to_s.downcase == "true" || ENV["DRY_RUN"].to_s.downcase == "true"

    puts "=== Processing Missing Original Translations #{'[DRY RUN MODE]' if dry_run} ==="

    Rails.application.eager_load!
    translatable_tables = BaseWithTranslation.descendants.map{_1.name.underscore.pluralize}.sort.map(&:to_sym)
    # see cleanup_translations.rake

    priority_langs = ["ja", "en", "fr"].freeze

    n_changed = 0
    translatable_tables.each do |table_name|
      model_class = table_name.to_s.singularize.camelize.constantize
      puts "Processing #{model_class.name}..."

      # Parents with at least one non-nil is_orig child translation
      parents_with_non_nil = Translation
        .where(translatable_type: model_class.name)
        .where.not(is_orig: nil)
        .pluck(:translatable_id)
        .uniq

      # Parents with at least one is_orig = true child translation
      parents_with_true = Translation
        .where(translatable_type: model_class.name, is_orig: true)
        .pluck(:translatable_id)
        .uniq

      # Target parent IDs: Has non-nil is_orig children, but ZERO is_orig=true children
      target_parent_ids = parents_with_non_nil - parents_with_true

      target_parent_ids.each do |parent_id|
        parent = model_class.find_by(id: parent_id)
        next unless parent

        child_translations = parent.translations.to_a

        # Find winner based on priority language order and lowest weight
        winner = nil
        do_neutralize = false
        first_child = child_translations.select { |t| t.langcode == "en" }.first
        case [model_class, first_child&.title]
        when [Prefecture, "UnknownPrefecture"], [Place, "UnknownPlace"]
          do_neutralize = true
          winner = true
        else
          priority_langs.each do |lang|
            candidates = child_translations.select { |t| t.langcode == lang }
            if candidates.any?
              # Pick lowest weight (treat nil weight as Float::INFINITY)
              winner = candidates.min_by { |t| t.weight || Float::INFINITY }
              break
            end
          end
        end

        # Handles case where no translation matches ["ja", "en", "fr"]
        if winner.nil?
          available_langs = child_translations.map(&:langcode).uniq.join(", ")
          puts "  [WARNING] No translation matching #{priority_langs} found for #{model_class.name} ##{parent.id} (Available: [#{available_langs}]). Skipping."
          next
        end

        n_changed += 1
        loser_ids = child_translations.map(&:id)
        loser_ids = loser_ids - [winner.id] if !do_neutralize 

        msg = "#{model_class.name} ##{parent.id}: " +
          if do_neutralize
            "Set all #{loser_ids.size} associated Translations to is_orig=nil for 'Unknown#{model_class.name}'."
          else
            "Set Translation ##{winner.id} (langcode: '#{winner.langcode}', weight: #{winner.weight}, title=#{winner.title.inspect}) to is_orig=true. Set #{loser_ids.size} other(s) to is_orig=false."
          end

        if dry_run
          puts "  [DRY RUN - WOULD FIX] "+msg
        else
          if do_neutralize
            Translation.where(id: loser_ids).update_all(is_orig: nil)
          else
            # Update DB directly bypassing validations
            Translation.where(id: winner.id).update_all(is_orig: true)
            Translation.where(id: loser_ids).update_all(is_orig: false) if loser_ids.any?
          end

          puts "  [FIXED] "+msg
        end
      end
    end

    puts "=== Task complete affecting #{n_changed} BaseWithTranslation #{'(Dryrun: No changes were made) ' if dry_run}==="
  end
end
