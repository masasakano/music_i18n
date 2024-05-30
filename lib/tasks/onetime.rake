
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

  # run: bin/rails onetime:assign_event_item_to_live_streaming_harami_vids
  #
  # In default: processes all HaramiVid-s in DB.
  # for DEBUG: Specify Environmental variable DEBUG_RAILS_ONETIME_IDS="1404,822,1002" for IDs of HaramiVid to process
  desc "Assign Events to live-streaming HaramiVids."
  task assign_event_item_to_live_streaming_harami_vids: :environment do |task_name|
    evgr = EventGroup.find_by_mname(:live_streamings)
    abort('FATAL: Strangely, EventGroup[:live_streamings] is not found.') if !evgr

    evits = []
    ActiveRecord::Base.transaction(requires_new: true) do
      rela =
        if (is_debug=ENV["DEBUG_RAILS_ONETIME_IDS"].present?)
          ids = ENV["DEBUG_RAILS_ONETIME_IDS"].split(/\s*,\s*/).map{|i| i.to_i}
          HaramiVid.where(id: ids)
        else
          HaramiVid.all
        end
      rela.each do |hvid|
        puts "(DEBUG) INFO: running HaramiVid(ID=#{hvid.id}) title=#{hvid.title}" if is_debug
        evits << hvid.set_event_item_if_live_streaming(create_amps: true)
        puts "(DEBUG) INFO: returned: #{evits.last.inspect}" if is_debug
        if (evit=evits.last)
          msg = sprintf "(%s:%s): Added EventItem (ID=%d) to HaramiVid (%d).", File.basename(__FILE__), task_name, evit.id, hvid.id
          puts msg
          Rails.logger.info msg  # This may record nothing in the logfile...
        end
      end
    end

    msg = sprintf "(%s:%s): Added an EventItem to %d HaramiVid entries (out of %d).", File.basename(__FILE__), task_name, evits.compact.size, evits.size
    puts msg
    Rails.logger.info "NOTE: "+msg  # This may record nothing in the logfile...
  end
end

