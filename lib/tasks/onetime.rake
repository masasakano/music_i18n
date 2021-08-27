
namespace :onetime do
  # run: bin/rails onetime:reset_weight_trans_unknown
  desc "Change weight of Translation-s for Model.unknown to 0."
  task reset_weight_trans_unknown: :environment do
    Rails.application.eager_load!
    BaseWithTranslation.descendants.each do |model|
      next if !model.respond_to? :unknown
      constname = 'Unknown'+model.name
      trans_unknowns = model.const_get constname
      args = trans_unknowns.map{|ek, ev| sprintf("(langcode = '%s' AND title = '%s')", ek, ev)}

      trans = Translation.where(translatable_type: model.name).where(args.join(" OR ")).where.not(weight: 0)
      n_entries = trans.count
      next if n_entries < 1
      trans.update_all(weight: 0)
      printf "%s: Updated to weight=0 for %d entries of %s.\n", File.basename(__FILE__), n_entries, model.name
    end
  end
end

