
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


  # Task: onetime:import_urls_from_artist_wiki
  #
  # Importing (up to 2) from Artist#wiki_(ja|en)
  #
  # Usage: bin/rails 'onetime:import_urls_from_artist_wiki[ArtistID]'
  #
  desc "Import Urls from artist#wiki_* 'import_urls_from_artist_wiki[111]'"
  task :import_urls_from_artist_wiki, [:anchorable_id, :option] => :environment do |t, args|
    begin
      artist = Artist.find args[:anchorable_id]
    rescue
      warn "ERROR: Wrong Artist ID: (#{args[:anchorable_id]})\n  Usage: bin/rails 'onetime:import_urls_from_artist_wiki[ArtistID]'"
      exit 1
    end

    module OneTimeRake
      class Artist < ActiveRecord::Base
      end
    end

    artist_in_db =  OneTimeRake::Artist.find args[:anchorable_id]  # gets the wiki_ja value etc from the DB table :artists regardless of the current definition of the top-level model Artist
    if !artist_in_db.respond_to?(:wiki_ja)
      warn "ERROR: Artist#wiki_ja|en undefined. Stopped."
      exit 1
    end

    exitstatus = 0
    n_imported = 0
    n_found = 0
    %w(en ja).each do |locale|
      urlstr = urlstr_orig = artist_in_db.send("wiki_"+locale)
      next if urlstr.blank?
      n_found += 1

      catch(:lcode_loop){
        anc = nil
        ActiveRecord::Base.transaction(requires_new: true) do      
          url = Url.find_or_create_url_from_wikipedia_str(urlstr, url_langcode: locale, anchorable: artist, encode: true, fetch_h1: false)  # no fetch_h1 implemented anyway.
          artist.anchorings.find_by(url_id: url.id) && throw(:lcode_loop, :all_found)  # Already set up

          anc = Anchoring.new(anchorable_type: "Artist", anchorable_id: artist.id).tap(&:set_was_created_true).tap(&:set_domain_found_true)  # Wikipedia Domain should be present.
          anc.url = url
          anc.set_url_found_if_true(url.was_found?)

          if url.errors.any?
            anc.transfer_errors_from(url, prefix: "[Url] ", mappings: {url_langcode: :url_langcode, site_category: :site_category, note: :base})  # defined in ModuleCommon
          else
            anc.save
          end
        end

        if anc.errors.any?
          warn sprintf("ERROR: Artist(%s): URL[%s]( %s ) or its Anchoring failed to be created: %s\n", artist.id, locale, urlstr_orig, anc.errors.full_messages.join(" "))
          exitstatus = 1
        else
          n_imported += 1
          printf("Artist(%s): URL[%s]( %s ) created (pID=%d) with Anchoring (pID=%d)\n", artist.id, locale, urlstr_orig, anc.url.id, anc.id)
        end
      }
    end # %w(en ja).each do |locale|

    printf("Artist(%s): %d/%d anchors created/found.\n", artist.id, n_imported, n_found)
    exit exitstatus
  end

  # Task: onetime:export_urls_to_artist_wiki
  #
  # Reverse of task :import_urls_from_artist_wiki, exporting Urls to Artist#wiki_*
  #
  # Usage: bin/rails 'onetime:export_urls_to_artist_wiki[ArtistID]'
  #
  desc "Export Urls to Artist#wiki_(ja|en) 'export_urls_to_artist_wiki[111]'"
  task :export_urls_to_artist_wiki, [:anchorable_id] => :environment do |t, args|
    module OneTimeRake
      class Artist < ActiveRecord::Base
      end
    end
    begin
      #artist = Artist.find args[:anchorable_id]
      artist = OneTimeRake::Artist.find args[:anchorable_id]
    rescue
      warn "ERROR: Wrong Artist ID: (#{args[:anchorable_id]})\n  Usage: bin/rails 'onetime:export_urls_to_artist_wiki[ArtistID]'"
      exit 1
    end

    if !artist.respond_to?(:wiki_ja)
      warn "ERROR: Artist#wiki_ja|en undefined. Stopped."
      exit 1
    end

    exitstatus = 0
    %w(en ja).each do |locale|
      attr_wiki = "wiki_"+locale
      urlstr = urlstr_orig = artist.send(attr_wiki)
      next if urlstr.present?

      ActiveRecord::Base.transaction(requires_new: true) do      
        Anchoring.where(anchorable_type: "Artist", anchorable_id: args[:anchorable_id]).each do |anc|
          next if anc.url.url.blank?  # should never happen
          next if !((dest_lc=anc.url.url_langcode) && dest_lc.strip == locale)
          next if anc.url.site_category.mname != "wikipedia"
          if artist.update(attr_wiki => anc.url.url)
            printf("URL( %s ) added to %s of Artist(%d) from Url(pID=%d)\n", anc.url.url, attr_wiki, artist.id, anc.url.id)
          else
            exitstatus = 1
            warn sprintf("ERROR: URL( %s ) failed to be set to %s of Artist(%d) from Url(pID=%d)\n", anc.url.url, attr_wiki, artist.id, anc.url.id)
          end
          break
        end
      end
    end
    exit exitstatus
  end

end

