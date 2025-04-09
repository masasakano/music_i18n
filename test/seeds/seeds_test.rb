# coding: utf-8

require 'test_helper'
#require Rails.root.to_s+'/app/helpers/application_helper'

class SeedsSeedsTest < ActiveSupport::TestCase
  #setup do
  #end

  # The current models (at the time of writing) are:
  #
  # Rails.application.eager_load! 
  # ActiveRecord::Base.descendants.select{|i| !i.abstract_class? && !i.name.include?('::') && i.table_name == i.name.underscore.pluralize}.sort{|a,b| a.name <=> b.name}.map(&:name)
  #   # =>
  # ["Artist",
  #  "Country",
  #  "CountryMaster",
  #  "Channel",
  #  "ChannelArtistAssoc",
  #  "ChannelOwner",
  #  "ChannelPlatform",
  #  "ChannelType",
  #  "Engage",
  #  "PlayRole",
  #  "EngageHow",
  #  "Event",
  #  "EventGroup",
  #  "EventItem",
  #  "Genre",
  #  "Harami1129",
  #  "Harami1129Review",
  #  "HaramiVid",
  #  "HaramiVidMusicAssoc",
  #  "ModelSummary",
  #  "Music",
  #  "PageFormat",
  #  "Place",
  #  "Prefecture",
  #  "RedirectRule",
  #  "RequestEnvironmentRule",
  #  "Role",
  #  "RoleCategory",
  #  "Sex",
  #  "StaticPage",
  #  "Translation",
  #  "User",
  #  "UserRoleAssoc"]
  #
  test "run seeds" do
    return if !is_env_set_positive?("DO_TEST_SEEDS")  # defined in application_helper.rb 
    require(Rails.root.to_s+"/db/seeds.rb")

    ### This probably would be the case if STDOUT/STDERR is temporarily suppressed.
    #if !is_env_set_positive?("PARALLEL_WORKERS")
    #  warn "WARNING: recommended to set environmental PARALLEL_WORKERS=1 to run tests of seeding: #{__FILE__}"
    #end

    refute_equal 0, EventItem.count, "EventItems should exist in seeds, but..."
    assert EventItem.any?{|i| i.unknown?}
    superuser = User.roots.first
    begin
      ApplicationRecord.allow_destroy_all = true  # required to allow destroying EventGroup-s etc!!
      ## TODO:
      # This had better be run after the 1st trial, i.e., three steps of (1) seeding while fixtures are there,
      # (2) seeding after reset DB, (3) repeated seeding, should be best.  At the moment,
      # such procedures fail because RoleCategory-Role rely on explicit pIDs(!).
      #
      # It seems EventItems can be destroy_all-ed regardless of ApplicationRecord.allow_destroy_all. Strange! Check it out.
      # Maybe destroy_all attempts to destroy everything WITHOUT rollback even if one of the destroy-attempts failed?

      [StaticPage, ArtistMusicPlay, PlayRole, Instrument, HaramiVidMusicAssoc, ModelSummary, PageFormat,
       Harami1129, Harami1129Review, HaramiVid, Engage, EngageHow,
       EventItem, Event, EventGroup,
       #ChannelArtistAssoc,
       Channel, ChannelPlatform, ChannelType, ChannelOwner,
       Artist, Music, Genre, 
       Place, Prefecture, Country, CountryMaster,
       SiteCategory,
       UserRoleAssoc, User, Role, RoleCategory,
       Sex, Translation].each do |klass|
         if User != klass
           klass.destroy_all
           next
         end
         User.where.not(id: superuser).destroy_all
      end
    ensure
      ApplicationRecord.allow_destroy_all = false
    end

    assert_equal 0, EventItem.count, "All EventItems should have been destroyed, but..."
    assert_equal 0, Event.count, "All Events should have been destroyed, but..."
    assert_equal 0, EventGroup.count, "All EventGroups should have been destroyed, but..."
    assert_equal 0, [EventGroup.count, Event.count, EventItem.count].sum, "All Events should be destroyed, but..."
    assert_equal 0, [Sex.count, Role.count, Artist.count, Translation.count, Engage.count].sum
    assert_equal 1, User.count
    assert_equal 1, _total_entry, "Positive entries (Expectation: [User:1] only): "+_pair_entries.reject{|i| i[1] < 1}.inspect.gsub(/"/, "")

    # run seeding (1st time)
    implant_seeds  # defined in /db/seeds.rb"
    # NOTE: if NoMethodError is rasied with "undefined method `best_translations'", your model may not be defined as a subclass of BaseWithTranslation?

    n_entries1 = _total_entry
    assert_operator 1000, :<, n_entries1
    assert_operator 5, :<, User.count, "User.all="+User.all.inspect
    assert_operator 5, :<, Role.count, "Role.all="+Role.all.inspect
    assert_operator 5, :<, (ncount = Country.count)
    assert_operator ncount, :<, (mcount = Prefecture.count)
    assert_operator mcount, :<, Place.count
    assert_operator 5, :<, EngageHow.count
    assert_operator 5, :<, Genre.count
    assert_operator 5, :<, EventGroup.count
    assert_operator 5, :<, PlayRole.count

    chorus = PlayRole.find_by(mname: "chorus")
    assert chorus.note.present? # sanity check with the fixture (based on SEEDS in /db/seeds/play_role.rb )
    chorus.update!(note: nil)
    refute chorus.note.present? # sanity check

    assert(defar = Artist.default(:HaramiVid))
    assert_equal defar.title(langcode: :en), ChannelOwner.select_regex(:title, /ハラミちゃん/, langcode: 'ja', sql_regexp: true).distinct.first.title(langcode: :en)
    assert_equal defar, ChannelOwner.select_regex(:title, /ハラミちゃん/, langcode: 'ja', sql_regexp: true).distinct.first.artist

    # run seeding (2nd time)
    def_title = [ChannelOwner::UNKNOWN_TITLES[:ja]].flatten.first
    replaced = def_title.sub(/$/, "-altered")
    Translation.find_by(title: def_title, langcode: "ja", translatable_type: "ChannelOwner").translatable.translations.find_by(langcode: "ja").update!(title: replaced)
    # This slight change in one of the Translations may result in ActiveRecord::RecordInvalid
    # in Validation of Translation because Translations in other two languages are identical.
    # Seeding script should identify the existing records correctly.

    puts "NOTE(TEST:#{File.basename __FILE__}): two warning are expected to be printed below."
    implant_seeds  # defined in /db/seeds.rb"

    assert_equal n_entries1, _total_entry, "The total entry number shoud not change, but..."
    chorus.reload
    refute chorus.note.present?, "should have not changed in the 2nd run of seeding, but..."
  end

  private

    # Returns the total entry number of records, except those of *Rule
    def _total_entry
      _pair_entries.map(&:last).sum
    end

    # Returns the number-of-entries information Array
    #
    # @return [Array<Array>] +[['User', 1], ['Artist', 0], ...]+ except those of *Rule
    def _pair_entries
      Rails.application.eager_load! 
      ActiveRecord::Base.descendants.select{|i| !i.abstract_class? && !i.name.include?('::') && i.table_name == i.name.underscore.pluralize}.sort{|a,b| a.name <=> b.name}.reject{|j| /Rule\z/ =~ j.name}.map{|k| [k.name, k.count]}
    end
end

