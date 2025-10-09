# coding: utf-8

require "test_helper"

# Testing integration of fixtures
#
# == Example of integration
#
# * 1 HaramiVid
#   * Translation (must have 1 (or more))
#   * Channel (must belongs_to)
#     * Translation (must have 1 (or more))
#     * ChannelOwner (must)
#       * Translation-s (must)
#       * If themselves==true
#         * Artist (must belongs_to)
#           * Translation-s (must)
#           * best_translations must agree with ChannelOwner' best_translations
#     * ChannelType (must)
#       * Translation-s (must)
#     * ChannelPlatform (must)
#       * Translation-s (must)
#   * HaramiVidEventItemAssoc (through, must have 1 or more)
#     * EventItem (must have 1 (or more))
#       * Place (...)
#       * Event (must belongs_to)
#         * Place (...)
#         * Translation (must have 1 (or more))
#         * EventItem (unknown; must have 1)
#         * EventGroup (must belongs_to)
#           * Place (...)
#           * Translation (must have 1 (or more))
#           * Event (unknown; must have 1)
#       * ArtistMusicPlay (belongs_to, usually have 1 or more)
#         * Music-s (usually should agree with those appearing in HaramiVidMusicAssoc for the HaramiVid)
#         * Artist 1 (usually the default Artist)
#         * Artist 2 (ChannelOwner of HaramiVid, if ChannelOwner#themselves is true)
#   * HaramiVidMusicAssoc (through, usually have 1 or many more)
#     * Music-s (usually should agree with those appearing in ArtistMusicPlay through HaramiVidEventItemAssoc)
#       * Place (...)
#       * Translation (must have 1 (or more))
#       * Engage-s (usually should have 1 or more)
#         * Artist-s (belongs_to, 1 or more)
#           * Place (...)
#           * Translation (must have 1 (or more))
#         * EngageHow-s (belongs_to, 1 or more)
#           * Translation (must have 1 (or more))
#   * Harami1129 (usually have 1 (or many more))
#     * EventItem (belongs_to; must; must be consistent with one of HaramiVidEventItemAssoc)
#   * Place (belongs_to, optional)
#       * Translation (must have 1 (or more))
#       * Prefecture (belongs_to, must)
#         * Translation (must have 1 (or more))
#         * Place (unknown; must)
#         * Country (belongs_to, must)
#           * Translation (must have 1 (or more))
#           * Prefecture (unknown; must)
#
class FixtureTest < ActiveSupport::TestCase
  include ModuleCommon

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  setup do
    @def_artist = artists(:artist_harami)
    @allowed = {
      harami_vids: %i(
        music99 music999 music_unknown music_how music_kampai music_robinson music_light
      ).map{|ek| musics(ek)},
      artists: %i(
        music99 music999 music_unknown music_kampai
      ).map{|ek| musics(ek)},
      musics: %i(
        harami_vid5
      ).map{|ek| harami_vids(ek)},
      harami_vid_music_assoc_musics: %i(
        music_kampai
      ).map{|ek| musics(ek)},  # skip checking consistency between HaramiVidMusicAssoc and ArtistMusicPlays
      event_items: %i(
        harami_vid5
      ).map{|ek| harami_vids(ek)},
      artist_music_plays: %i(
        harami_vid5
      ).map{|ek| harami_vids(ek)},
    }.with_indifferent_access
  end

  test "all valid" do
    # Note: Fixtures of Channel must be manually updated every time seeds is updated.  It may cause an error here!.
    Rails.application.eager_load!
    ActiveRecord::Base.descendants.select{|i| !i.abstract_class? && !i.name.include?('::') && i.table_name == i.name.underscore.pluralize}.sort{|a,b| a.name <=> b.name}.each do |model|
      if !model
        print "strange model: "; p model
        next
      end
      model.all.each do |record|
        assert record.valid?, "Fixture validate error: record=#{record.inspect}"+" ERROR=#{record.valid?; record.errors.inspect}"
      end
    end
  end

  test "fixtures should have significant weights" do
    [EngageHow, PlayRole].each do |klass|
      refute EngageHow.where(weight: nil).exists?, "class=#{klass.name}"
      assert EngageHow.where.not(weight: nil).exists?, 'sanity check'
      refute EngageHow.where.not(weight: nil).where("weight < 0").exists?, "class=#{klass.name}"
    end
  end

  test "fixtures translations assocs" do
    Rails.application.eager_load!
    BaseWithTranslation.descendants.each do |klass|
      klass.all.each do |obj|
        _assert_fixtures(obj, :translations)
      end
    end
  end

  test "fixtures translations should have valid values" do
    refute Translation.where(title: nil, alt_title: nil).exists?
    refute Translation.where(langcode: nil).exists?
    refute((m=Translation.where.not(langcode: "ja").find{|tra|
      %i(title romaji alt_title alt_romaji).any?{|em| contain_asian_char?(tra.send(em)) }  # Katakana ruby is allowed for En etc.
    }), "non-Japanese Tranlation title/alt_title contains Asian characters: err="+m.inspect)
  end

  test "fixtures null assocs" do
    # many of belongs_to are caught by Rails (if not allowing null for the columns) but some of them are not.
    # This also tests empty has_many.
    hsall = {
      UserRoleAssoc => %w(user role),  # belongs_to
      Channel => %w(channel_owner channel_platform channel_type),
      Engage =>                     %w(artist music engage_how),
      ArtistMusicPlay => %w(event_item artist music play_role instrument),
      HaramiVidMusicAssoc     => %w(harami_vid music),
      HaramiVidEventItemAssoc => %w(harami_vid event_item),
      Artist => %w(sex),
      Place => %w(prefecture),   # belongs_to
      Prefecture => %w(country), # belongs_to
      Prefecture => %w(places),   # has_many (at least 1)
      Country => %w(prefectures), # has_many (at least 1)
      Event => %w(event_group), # belongs_to
      EventItem => %w(event),   # belongs_to
      EventGroup => %w(events), # has_many (at least 1)
      Event => %w(event_items), # has_many (at least 1)
    }

    hsall.each_pair do |klass, arcols|
      klass.all.each do |obj|
        _assert_fixtures(obj, arcols)
      end
    end
  end

  test "fixtures assocs many-to-many" do
    hsall = {
      Music => %w(artists harami_vids),
      HaramiVid => %w(event_items musics artist_music_plays),  # HaramiVid should have all of them as long as it is for Music
    }

    hsall.each_pair do |klass, arcols|
      klass.all.each do |obj|
        _assert_fixtures(obj, arcols)
      end
    end
  end

  test "fixtures ChannelOwners and Artists" do
    assert_nil((m=ChannelOwner.find_by(themselves: true,  artist: nil)), "model=#{m}")
    assert_nil((m=ChannelOwner.where(themselves: false).where.not(artist: nil).first), "Allowed, but not good for fixtures: model=#{m}")

    ChannelOwner.where(themselves: true).each do |eco|
      eco_bests = eco.best_translations
      art_bests = eco.artist.best_translations
      cols = [:title, :alt_title, :ruby, :romaji, :alt_ruby, :alt_romaji, :is_orig, :langcode]
      %w(en ja).each do |lc|
        assert_equal eco_bests[lc].slice(*cols), art_bests[lc].slice(*cols), "ChannelOwner (#{str2identify_fixture(eco_bests[lc], note_label: "trans.note=")}) has inconsistent Translation in lc=#{lc} with Artist (#{str2identify_fixture(art_bests[lc], note_label: "trans.note=")})"  # str2identify_fixture() defined in model_helper.rb
      end
    end
  end

  test "fixtures consistency between MusicAssoc-Music and EventItem-Music" do
    HaramiVid.all.each do |hvid|
      assert_consistent_music_assocs_for_harami_vid(hvid)  # defined in model_helper.rb
    end
  #end

  #test "fixtures consistency between Harami112, Engage, EventItem, HaramiVidMusicAssoc, HaramiVidEventItemAssoc" do
    Harami1129.all.each do |h1129|
      assert (eng=h1129.engage) if h1129.engage_id
      assert (evit=h1129.event_item) if h1129.event_item_id
      next if !h1129.harami_vid_id
      assert (hvid=h1129.harami_vid)
      if h1129.engage_id
        assert_includes hvid.musics, eng.music
        if h1129.event_item_id
          assert_includes evit.musics, eng.music, "included Music (note=#{eng.music.note.inspect}) in Harami1129 (note=#{h1129.note.inspect}) usually must be played by the default Artist, too, in EventItem (note=#{evit.note.inspect}) through an ArtistMusicPlay"
        end
      end

      if h1129.event_item_id
        assert_includes hvid.event_items, evit, "EventItem (note=#{evit.note.inspect}) of Harami1129 (note=#{h1129.note.inspect}) must be one of HaramiVid#event_items (hvid.note=#{hvid.note.inspect}) through HaramiVidEventItemAssoc"
      end
    end
  end

  private

    def _assert_fixtures(obj, methods, check_method: :present?)
      bind = caller_locations(1,1)[0]  # Ruby 2.0+
      caller_info = sprintf "%s:%d", bind.absolute_path.sub(%r@.*(/test/)@, '\1'), bind.lineno
      # NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"

      [methods].flatten.each do |em|
        next if obj.id.blank? || obj.destroyed?
        next if @allowed[em] && @allowed[em].include?(obj)
        assert obj.send(em).send(check_method), "(#{caller_info}) #{obj.class.name} Fixture has no #{em}: "+_remove_timestamps_str(obj.inspect)
          
      end
    end
    private :_assert_fixtures

    def _remove_timestamps_str(strin)
      strin.gsub(/, (cre|upd)ated_at: [^,;>]+/, "")
    end
    private :_remove_timestamps_str
end
