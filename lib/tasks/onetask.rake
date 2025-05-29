# Command-line wrapper tasks of this framework
#
# * onetask:fetch_url_h1
# * onetask:import_urls_from_note
# * onetask:export_urls_to_note
# * onetask:manage_music_country
#
namespace :onetask do
  # Task: onetask:fetch_url_h1
  #
  # This fetches and prints h1 tag of a URL
  #
  # Usage: bin/rails 'onetask:fetch_url_h1[example.com]'
  #      : bin/rails 'onetask:fetch_url_h1[example.com,all]'
  #
  desc "Fetch H1 of URL with 'fetch_url_h1[example.com]' (or H1s in HTML with additional ',all')"
  task :fetch_url_h1, [:url, :is_all] => :environment do |t, args|
    include ModuleCommon

    url = args[:url]
    is_all = (args[:is_all].present? && /no|false/i != args[:is_all])

    unless url.present?
      warn "ERROR: Missing URL argument. USAGE: bin/rails 'onetask:fetch_url_h1[example.com]'"
      exit 1
    end

    url2access = ModuleUrlUtil.url_prepended_with_scheme(url, invalid: nil)
    if url2access.blank?
      warn "ERROR: Invalid URL"
      exit 1
    end

    if is_all
      puts "Input URL: "+url
      puts "Scraping URL: "+url2access
    end

    if !is_all
      result = fetch_url_h1(url, css: nil)  # defined in module_common.rb
      if result
        puts result
        exit 0
      else
        warn "Failed connection. Use debug option: bin/rails 'onetask:fetch_url_h1[example.com,all]'"
        exit 1
      end
    end

    begin
      nodes = ModuleCommon.fetch_url_node(url, css: "h1", capture_exception: false)
    rescue => er
      warn "FATAL: Exception raised: "+compile_captured_err_msg(er)
      exit 1
    end

    if nodes.blank?
      warn "No H1 on the URL."
    else
      puts nodes.to_a.map.with_index{|etit, i| sprintf("(%d): %s", i+1, etit.inner_html.inspect)}.join("\n")
    end
    exit 0
  end

  # Task: onetask:import_url_from_note
  #
  # This imports (loads) Url-s from URL-like Strings (of Wikipedia and Harmai-Chronicle) in note
  # Which URLs this imports depend on the implementation of {Anchoring.task_find_or_create_multi_from_note}
  #
  # Usage: bin/rails 'onetask:import_urls_from_note[ClassName,pID,option]'
  #
  # Options:
  #
  # * find : Find a candidate Url-like Strings and prints them only (no guarantee if all Urls can be created)
  # * copy : Create Urls and Anchorings based on note, which unchanges.
  # * move : Create Urls and Anchorings and the Strings are removed from note.
  # * dryrun : Run "move" and DB-rollback, printing information
  #
  desc "Import Urls from note of Anchorable-class 'import_urls_from_note[Place,111,find|copy|move|dryrun]'"
  task :import_urls_from_note, [:anchorable_type, :anchorable_id, :option] => :environment do |t, args|
    begin
      anchorable = args[:anchorable_type].constantize.find(args[:anchorable_id])
    rescue
      warn "ERROR: anchorable not found: #{args[:anchorable_type]}(#{args[:anchorable_id]})\n  Usage: bin/rails 'onetask:import_urls_from_note[ClassName,pID,option]'"
      exit 1
    end

    ActiveRecord::Base.transaction(requires_new: true) do
      case args[:option]
      when "find"
        print "Note: "; p anchorable.note
        p Url.find_multi_from_note(anchorable)
      when "copy", "move", "dryrun"
        modelnames = Anchoring::MODELS_TO_COUNT_IN_MIGRATION.map(&:name)
        remove = (("copy" == args[:option]) ? false : true)
        begin
          hsstat = Anchoring.task_find_or_create_multi_from_note(args[:anchorable_type], args[:anchorable_id], remove_from_note: remove, fetch_h1: true)  # fetching H1 from remote
        rescue HaramiMusicI18n::Urls::NotAnchorableError
          warn "ERROR: the ActiveRecord class is not anchorable: #{args[:anchorable_type]}\n  Usage: bin/rails 'onetask:import_urls_from_note[ClassName,pID,option]'"
          exit 1
        end
        printf "== Increments:\n"
        ((hsstat.keys.map(&:to_s).sort == modelnames.sort) ? modelnames : hsstat.keys).each do |model|
          printf "  %-11s : %2d\n", model, hsstat[model]
        end
        if "dryrun" == args[:option]
          warn "Rollback..."
          raise ActiveRecord::Rollback, "Force rollback." 
        end
      else
        warn "Error: wrong option #{args[:option].inspect} given for [find|copy|move|dryrun]"
        exit 1
      end
    end
  end  # task :import_urls_from_note, [:anchorable_type, :anchorable_id, :option] => :environment do |t, args|


  # Task: onetask:export_url_to_note
  #
  # Reverse of task :import_urls_from_note, exporting Url-Strings to note
  #
  # Usage: bin/rails 'onetask:export_urls_to_note[ClassName,pID]'
  #
  desc "Export Urls to note of Anchorable-class 'export_urls_to_note[Place,111]'"
  task :export_urls_to_note, [:anchorable_type, :anchorable_id] => :environment do |t, args|
    begin
      ancs = Anchoring.export_urls_to_note(args[:anchorable_type], args[:anchorable_id])
    rescue HaramiMusicI18n::Urls::NotAnchorableError
      warn "ERROR: Either not an valid ActiveRecord or its class is not anchorable: #{args[:anchorable_type]}(#{args[:anchorable_id]})\n  Usage: bin/rails 'onetask:export_urls_to_note[ClassName,pID]'"
      exit 1
    end

    if ancs.empty?
      puts "No change in #{args[:anchorable_type]}(#{args[:anchorable_id]})#note"
    else
      printf("Exported %d Urls of [%s]:\n",
             ancs.size,
             ancs.map{|ea| sprintf "%s (Url=%d/Anchoring=%d)", Addressable::URI.unencode(ea.url.url), ea.url.id, ea.id}.join(", ")
            )
      printf("Resultant %s(%s)#note: %s\n",
             args[:anchorable_type], args[:anchorable_id],
             args[:anchorable_type].constantize.find(args[:anchorable_id]).note )
    end
  end

  # Task: onetask:manage_music_country
  #
  # Usage: bin/rails 'onetask:manage_music_country[show|update_all,pID|nil]'
  #
  # NOTE: As for the output keywords
  #   lang_ja: Music's original language is JA
  #   artist_jp: Music's lead Artist's Country is Japan.
  #
  desc "Show or update (all) Music#country to Japan if neccesary 'manage_music_country[show|update_all,pID|nil]'"
  task :manage_music_country, [:task, :music_id] => :environment do |t, args|
    music_id = (args[:music_id].present? ? args[:music_id] : nil)
    jp = Country.primary
    jp_place = jp.unknown_prefecture.unknown_place

    Music::CONTEXTS_TO_UPDATE_TO_JAPAN.each do |context|
      rela = Music.world_to_update_to_japan(context, musics: music_id)

      print "Music(s) to update for #{context.to_s}: "+(music_id ? "" : "\n")
      pp rela
      case args[:task].downcase
      when "show"
        # do nothing
      when "update_all"
        next if rela.update_all(place_id: jp_place.id)
        warn "ERROR: Something went wrong."
        exit 1
      else
        warn "ERROR: Invalid option given (#{args[:task]})"
        warn "  USAGE: bin/rails 'onetask:manage_music_country[show|update_all,pID|nil]'"
        exit 1
      end
    end
  end

end

