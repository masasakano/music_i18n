class TransferWikilinksToUrl < ActiveRecord::Migration[7.0]
  ## NOTE ###########
  #
  # This migratio handles existing data on DB tables of Artist, Anchoring, and Url.
  # You may set ENV['FORCE_RUN_MIGRATION_TRANSFER_WIKILINKS'] = "1"
  # if you encounter a problem and want to skip this migration.
  #
  # Skipping would not be critical for the integration of the data at all,
  # but you may lose some data about Wikipedia links.
  #
  # Note this migration does depend on the seeding introduced in commit 9db008f

  module OneTimeRake
    class Artist < ActiveRecord::Base
    end
  end

  # Copy Artist#wiki_ja|en to Url
  def up
    _check_runnable!

    hsret = {n_imported: 0,
             n_found: 0}

    OneTimeRake::Artist.all.each do |artist|
      begin
        ar = import_urls_from_artist_wiki(artist)
        hsret[:n_imported] += ar[0]
        hsret[:n_found]    += ar[1]
      end
    end

    printf("======= Statistics\n")
    printf(" Number of examined Artists: %d\n", OneTimeRake::Artist.all.count)
    printf(" Number of wiki_ja|en found: %d\n", hsret[:n_found])
    printf(" Number  Anchorings created: %d\n", hsret[:n_imported])
  end

  # Copy Anchoring for wikipedia to Artist#wiki_ja|en
  #
  # This does not depend on Artist, so this should run whatever the Artist model situation is.
  # However, thid does assume the relations between models Anchoring and Url and SiteCategory.
  # It is well possible to redefine them here, I do not bother...
  def down
    OneTimeRake::Artist.all.each do |artist|
      begin
        export_urls_to_artist_wiki(artist)
      end
    end
  end

  private

  # @return [Boolean]
  def _check_runnable!
    is_runnable =
      if !defined? Artist
        warn "ERROR: Model Artist is not defined. Without it, this migration may not run well. Skip."
        false
      elsif !OneTimeRake::Artist.has_attribute?(:wiki_ja)
        warn "ERROR: Seems DB does not have :wiki_ja column. Strange... Skip."
        false
      else
        true
      end

    return true if is_runnable || %w(1 true TRUE).include?(ENV['FORCE_RUN_MIGRATION_TRANSFER_WIKILINKS'])

    raise "Seems strange. If you are sure to run this migration, set the environmental variable ENV['FORCE_RUN_MIGRATION_TRANSFER_WIKILINKS']=1 and rerun."
  end

  # This is based on the Rake task of the same name in /lib/tasks/onetime.rake
  #
  # @return [Array] [n_imported, n_found] not conting Url-increase but Anchoring-increase only
  def import_urls_from_artist_wiki(anchorable)
    artist = Artist.find anchorable.id
    artist_in_db = anchorable  # gets the wiki_ja value etc from the DB table :artists regardless of the current definition of the top-level model Artist

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
        else
          n_imported += 1
          printf("Artist(%s): URL[%s]( %s ) created (pID=%d) with Anchoring (pID=%d)\n", artist.id, locale, urlstr_orig, anc.url.id, anc.id)
        end
      }
    end # %w(en ja).each do |locale|

    printf("__Artist(%s): %d/%d anchors created/found.\n", artist.id, n_imported, n_found)  if n_found > 0
    [n_imported, n_found]
  end  # def import_urls_from_artist_wiki(anchorable)


  # This is based on the Rake task of the same name in /lib/tasks/onetime.rake
  #
  # @return [void]
  def export_urls_to_artist_wiki(artist)
    %w(en ja).each do |locale|
      attr_wiki = "wiki_"+locale
      urlstr = urlstr_orig = artist.send(attr_wiki)
      next if urlstr.present?

      ActiveRecord::Base.transaction(requires_new: true) do      
        Anchoring.where(anchorable_type: "Artist", anchorable_id: artist.id).each do |anc|
          next if anc.url.url.blank?  # should never happen
          next if !((dest_lc=anc.url.url_langcode) && dest_lc.strip == locale)
          next if anc.url.site_category.mname != "wikipedia"
          if artist.update(attr_wiki => anc.url.url)
            printf("Artist(%d)/%s: URL( %s ) added from Url(pID=%d)\n", artist.id, attr_wiki, anc.url.url, anc.url.id)
          else
            warn sprintf("ERROR: URL( %s ) failed to be set to %s of Artist(%d) from Url(pID=%d)\n", anc.url.url, attr_wiki, artist.id, anc.url.id)
          end
          break
        end
      end
    end
  end # def export_urls_to_artist_wiki()

end
