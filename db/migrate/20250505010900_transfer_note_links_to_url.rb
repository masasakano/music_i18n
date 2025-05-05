class TransferNoteLinksToUrl < ActiveRecord::Migration[7.0]
  ## NOTE ###########
  #
  # This migratio handles existing data on DB tables of (some) BaseWithTranslation
  # that are anchorable, Anchoring, and Url.  Specifically, this *moves* the
  # Chronicle/Wiki-like URLs to Urls from BaseWithTranslation#note to Url,
  # maybe creating Urls and Anchoring-s.
  #
  # You may set ENV['FORCE_RUN_MIGRATION_TRANSFER_NOTELINKS'] = "1"
  # if you encounter a problem and want to skip this migration.
  #
  # Skipping would not be critical for the integration of the data at all,
  # but you may lose some data about links (anchors).
  #
  # Note this migration does depend on the seeding introduced in commit 9db008f

  #
  ## For polynomic relations, these do not work well because anchorable_type would point to their full-path Class names...
  module OneTimeRake
    #class Artist < ActiveRecord::Base
    #  has_many :anchorings, as: :anchorable, dependent: :destroy
    #  has_many :urls, through: :anchorings
    #end
    #class Music < ActiveRecord::Base
    #  has_many :anchorings, as: :anchorable, dependent: :destroy
    #  has_many :urls, through: :anchorings
    #end
    #class Event < ActiveRecord::Base
    #  has_many :anchorings, as: :anchorable, dependent: :destroy
    #  has_many :urls, through: :anchorings
    #end
    #class HaramiVid < ActiveRecord::Base
    #  has_many :anchorings, as: :anchorable, dependent: :destroy
    #  has_many :urls, through: :anchorings
    #end
    #class Place < ActiveRecord::Base
    #  has_many :anchorings, as: :anchorable, dependent: :destroy
    #  has_many :urls, through: :anchorings
    #end
    #class SiteCategory < ActiveRecord::Base
    #  has_many :domain_titles
    #  has_many :domains, through: :domain_titles
    #  has_many :urls,    through: :domains
    #end
    #class DomainTitle < ActiveRecord::Base
    #  belongs_to :site_category
    #  has_many :domains, dependent: :destroy  # cascade in DB. But this should be checked in Rails controller level!
    #  has_many :urls, through: :domains       # This prohibits cascade destroys - you must destroy all Urls first.
    #end
    #class Domain < ActiveRecord::Base
    #  belongs_to :domain_title
    #  has_many :urls,    dependent: :restrict_with_exception  # Exception in DB, too.
    #  has_one :site_category, through: :domain_title
    #end
    #class Url < ActiveRecord::Base
    #  has_many :anchorings, dependent: :destroy
    #  belongs_to :domain
    #  has_one :domain_title, through: :domain
    #  has_one :site_category, through: :domain_title
    #end
    #class Anchoring < ActiveRecord::Base
    #  belongs_to :url
    #  belongs_to :anchorable, polymorphic: true
    #end
DRYRUN = false   #############################  false for the actual run; for test runs, specify [find|copy|move|dryrun]
                 # NOTE: this should be set false first ON THE NOMINAL UP MIGRATION
                 #  and NOT rollback "down" migration first!  The rollback migraion
                 #  would export tons of Urls to note.  Although the exported URL-strings
                 #  in note should be erased in the next nominal migration, it is not ideal.
  end

  # Move String-URLs from BaseWithTranslation#note to Url
  #
  # based on Rake task
  #   onetask:import_urls_from_note in /lib/tasks/onetask.rake
  def up
    _check_runnable!(__method__)

    n_anchorings_grand_total = 0
    ActiveRecord::Base.transaction(requires_new: true) do
      [Artist, Music, Event, HaramiVid, Place].each do |model|
##(Artist Music ).each do |model|  ########################################## for testing #############
        if !model.has_attribute? :note
          warn "WARNING: model #{model.name} has no #note column. Strange. Skips."
          next
        end

        n_anchorings_per_model = 0
        model.all.each do |anchorable| 
          next if anchorable.note.blank?

          # code below imported from onetask:import_urls_from_note in /lib/tasks/onetask.rake
          ActiveRecord::Base.transaction(requires_new: true) do
            case OneTimeRake::DRYRUN
            when "find"
              print "Note: "; p anchorable.note
              p Url.find_multi_from_note(anchorable)
            when "copy", "move", "dryrun", false, nil
              # modelnames = Anchoring::MODELS_TO_COUNT_IN_MIGRATION.map(&:name)
              modelnames = %w(Translation DomainTitle Domain Url Anchoring)
              remove = (("copy" == OneTimeRake::DRYRUN) ? false : true)
              begin
                hsstat = Anchoring.task_find_or_create_multi_from_note(anchorable, verbose: false, remove_from_note: remove, fetch_h1: true)  # fetching H1 from remote
              rescue HaramiMusicI18n::Urls::NotAnchorableError
                warn "ERROR: the ActiveRecord class seems not anchorable. Strange: #{anchorable.inspect}"
                raise ActiveRecord::Rollback, "Force rollback." 
              rescue  => err
                warn "ERROR: unexpected error happened... Strange: Error=#{err.inspect} / #{anchorable.inspect}"
                raise ActiveRecord::Rollback, "Force rollback." 
              end
              n_tot = 0
              retstr = "Increments: "
              ((hsstat.keys.map(&:to_s).sort == modelnames.sort) ? modelnames : hsstat.keys).each do |model|
                retstr << sprintf(" %s(+%d)", model, hsstat[model])
                n_tot += (hsstat[model] ? hsstat[model].to_i : 0)
              end
              retstr << sprintf(" / Total=%d\n", n_tot)
              puts retstr if n_tot > 0  # print only if significant.
              n_anchorings_per_model += hsstat["Anchoring"]

            else
              warn "Error: wrong option #{OneTimeRake::DRYRUN.inspect} given for [find|copy|move|dryrun]"
              exit 1
            end # case OneTimeRake::DRYRUN
          end # ActiveRecord::Base.transaction(requires_new: true) do
        end   # model.all.each do |anchorable| 
        printf "== Stats: (%d) Anchorings have been created.\n", n_anchorings_per_model
        n_anchorings_grand_total += n_anchorings_per_model

      end # [Artist, Music, Event, HaramiVid, Place].each do |model|
      printf "====== Stats: Grand total (%d) Anchorings have been created.\n", n_anchorings_grand_total

      if OneTimeRake::DRYRUN
        warn "Rollback... (because of OneTimeRake::DRYRUN)"
        raise ActiveRecord::Rollback, "Force rollback." 
      end
    end  # ActiveRecord::Base.transaction(requires_new: true) do

  end

  # Copy Url to BaseWithTranslation#note Strings.
  # based on Rake task:  
  #   onetask:export_urls_to_note in /lib/tasks/onetask.rake
  def down
    _check_runnable!(__method__)

    n_anchorings_grand_total = 0
    ActiveRecord::Base.transaction(requires_new: true) do
      Anchoring.all.each do |anchoring|
        next if !anchoring.id || !Anchoring.exists?(anchoring.id)  # already destroyed.

        anchorable = anchoring.anchorable
        ancs = Anchoring.export_urls_to_note(anchorable)

        print "#{anchoring.anchorable_type}(#{anchoring.anchorable_id})#note : "
        if ancs.empty?
          puts "No change."
        else
          printf("Exported %d Urls of [%s]:",
                 ancs.size,
                 ancs.map{|ea| sprintf "%s (Url=%d/Anchoring=%d)", Addressable::URI.unencode(ea.url.url), ea.url.id, ea.id}.join(", ")
                )
          puts sprintf("Resultant %s(%s)#note: %s",
                 anchoring.anchorable_type, anchoring.anchorable_id,
                 anchorable.note )
        end
        n_anchorings_grand_total += ancs.size
      end # Anchoring.all.each do |anchoring|

      printf "====== Stats: Grand total (%d) Anchorings have been imported to note.\n", n_anchorings_grand_total

      if OneTimeRake::DRYRUN
        warn "Rollback... (because of OneTimeRake::DRYRUN)"
        raise ActiveRecord::Rollback, "Force rollback." 
      end
    end # ActiveRecord::Base.transaction(requires_new: true) do
  end  # def down


  # @return [Boolean]
  def _check_runnable!(parent_method)
    is_runnable =
      if :up == parent_method && !(defined? Anchoring) || !Anchoring.respond_to?(:task_find_or_create_multi_from_note)
        warn "ERROR: Anchoring.task_find_or_create_multi_from_note is undefined, which is indispensable. Skip."
        false
      elsif :down == parent_method && !(defined? Anchoring) || !Anchoring.respond_to?(:export_urls_to_note)
        warn "ERROR: Anchoring.export_urls_to_note is undefined, which is indispensable. Skip."
        false
      elsif !defined? Music
        warn "ERROR: Model Music is not defined. Without it, this migration may not run well. Skip."
        false
      elsif !Artist.has_attribute?(:note)
        warn "ERROR: Seems DB does not have :note column. Strange... Skip."
        false
      else
        true
      end

    return true if is_runnable || %w(1 true TRUE).include?(ENV['FORCE_RUN_MIGRATION_TRANSFER_WIKILINKS'])

    raise "Seems strange. If you are sure to run this migration, set the environmental variable ENV['FORCE_RUN_MIGRATION_TRANSFER_WIKILINKS']=1 and rerun."
  end

end
