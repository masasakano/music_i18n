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
  #  "Engage",
  #  "EngageEventItemHow",
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

    superuser = User.roots.first
    [StaticPage, EngageEventItemHow, Instrument, HaramiVidMusicAssoc, ModelSummary, PageFormat,
     Harami1129, Harami1129Review, HaramiVid, Engage, EngageHow,
     EventItem, Event, EventGroup, Artist, Music, Genre, 
     Place, Prefecture, Country, CountryMaster,
     UserRoleAssoc, User, Role, RoleCategory,
     Sex, Translation].each do |klass|
       if User != klass
         klass.destroy_all
         next
       end
       User.where.not(id: superuser).destroy_all
    end

    assert_equal 0, [Sex.count, Role.count, Artist.count, Translation.count, Engage.count].sum
    assert_equal 1, User.count
    assert_equal 1, _total_entry, "Positive entries (Expectation: [User:1] only): "+_pair_entries.reject{|i| i[1] < 1}.inspect.gsub(/"/, "")

    # run seeding (1st time)
    implant_seeds  # defined in /db/seeds.rb"

    n_entries1 = _total_entry
    assert_operator 1000, :<, n_entries1
    assert_operator 5, :<, User.count, "User.all="+User.all.inspect
    assert_operator 5, :<, Role.count, "Role.all="+Role.all.inspect
    assert_operator 5, :<, (ncount = Country.count)
    assert_operator ncount, :<, Prefecture.count
    assert_operator 5, :<, EngageHow.count
    assert_operator 5, :<, Genre.count
    assert_operator 5, :<, EventGroup.count
    assert_operator 5, :<, EngageEventItemHow.count

    chorus = EngageEventItemHow.find_by(mname: "chorus")
    assert chorus.note.present? # sanity check with the fixture (based on SEEDS in /db/seeds/engage_event_item_how.rb )
    chorus.update!(note: nil)
    refute chorus.note.present? # sanity check

    # run seeding (2nd time)
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

