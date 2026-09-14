namespace :translations do
  desc "Clean up duplicate is_orig=true records across BaseWithTranslation translatable models"
  task :cleanup_duplicate_originals, [:dryrun] => :environment do |_t, args|
    # Check task argument or ENV variable (e.g., DRY_RUN=true or [true]):
    #   bin/rails "translations:cleanup_duplicate_originals[true]"
    # OR
    #   DRY_RUN=true bin/rails translations:cleanup_duplicate_originals
    dry_run = args[:dryrun].to_s.downcase == "true" || ENV["DRY_RUN"].to_s.downcase == "true"

    puts "=== Processing Translations #{'[DRY RUN MODE]' if dry_run} ==="

    Rails.application.eager_load!
    translatable_tables = BaseWithTranslation.descendants.map{_1.name.underscore.pluralize}.sort.map(&:to_sym)
    # NOTE: the following prints all BaseWithTranslation with erroneous Translation combinations, including those having mixed Translations of is_orig=nil and Boolean
    #   BaseWithTranslation.descendants.each{|em| puts "== Checking #{em.name}"; em.all.each{|er| ar=er.translations.pluck(:is_orig); p(er) if ar.compact.present? && (ar.count(true) != 1)}}' | egrep -v '== ' | wc


    n_changed = 0
    n_unresolved = 0
    translatable_tables.each do |table_name|
      model_class = table_name.to_s.singularize.camelize.constantize
      puts "Processing #{model_class.name}..."

      duplicate_parent_ids = Translation
        .where(translatable_type: model_class.name, is_orig: true)
        .group(:translatable_id)
        .having("COUNT(*) > 1")
        .pluck(:translatable_id)

      duplicate_parent_ids.each do |parent_id|
        parent = model_class.find_by(id: parent_id)
        next unless parent

        orig_translations = parent.translations.where(is_orig: true).to_a
        unique_langcodes = orig_translations.map(&:langcode).uniq

        if unique_langcodes.size == 1
          # Case 1: All child Translations of is_orig=true having the same langcode — now identifies winner by lowest weight
          n_changed += 1
          winner = orig_translations.min_by { |t| t.weight || Float::INFINITY }
          # loser_ids = orig_translations.map(&:id) - [winner.id]  # This is insufficient in the case if a Translation has is_orig=true and one of the others in a different langcode has is_orig=nil
          loser_ids = parent.translations.map(&:id) - [winner.id]

          msg = "#{model_class.name} ##{parent.id}: Kept Translation ##{winner.id} (langcode: #{winner.langcode}, weight: #{winner.weight}). Reset #{loser_ids.size} duplicate ID(s): #{loser_ids.inspect}."
          if dry_run
            puts "  [DRY RUN - WOULD FIX] "+msg
          else
            # Change to is_orig=false except for one
            Translation.where(id: loser_ids).update_all(is_orig: false)
            puts "  [FIXED] "+msg
          end
        else
          # Case 2: Different langcodes — print warning without modifying DB
          n_unresolved += 1
          puts "  [WARNING] Conflicting original langcodes (#{unique_langcodes.join(', ')}) found for: "+parent.inspect
        end
      end
    end

    puts "=== Task complete affecting #{n_changed} BaseWithTranslation but #{n_unresolved} unresolved #{'(Dryrun: No changes were made )' if dry_run}==="
  end
end
