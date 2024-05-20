# coding: utf-8

require "test_helper"

# Testing integration of fixtures
class FixtureTest < ActiveSupport::TestCase
  include ModuleCommon

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  setup do
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
      event_items: %i(
        harami_vid5
      ).map{|ek| harami_vids(ek)},
      artist_music_plays: %i(
        harami_vid5
      ).map{|ek| harami_vids(ek)},
    }.with_indifferent_access
  end

  test "fixtures should have significant weights" do
    [EngageHow, PlayRole].each do |klass|
      refute EngageHow.where(weight: nil).exists?, "class=#{klass.name}"
      assert EngageHow.where.not(weight: nil).exists?, 'sanity check'
      refute EngageHow.where.not(weight: nil).where("weight < 0").exists?, "class=#{klass.name}"
    end
  end

  test "fixtures translations assocs" do
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

  test "fixtures ChannelOwner and Artists" do
    assert_nil((m=ChannelOwner.find_by(themselves: true,  artist: nil)), "model=#{m}")
    assert_nil((m=ChannelOwner.where(themselves: false).where.not(artist: nil).first), "Allowed, but not good for fixtures: model=#{m}")
  end

  test "fixtures consistency between MusicAssoc-Music and EventItem-Music" do
    HaramiVid.all.each do |ehv|
      ((mu4assoc=ehv.musics) + (mu4evit=ehv.music_plays)).sort.uniq.each do |emu|
        msg1 = "In HaramiVid (note=#{ehv.note.inspect}), Music (#{emu.title}; note=#{emu.note.inspect}) is in "
        assert_includes mu4assoc, emu, msg1+"HaramiVidMusicAssoc but not in ArtistMusicPlay (through HaramiVidEventItemAssoc)."
        assert_includes mu4evit,  emu, msg1+"ArtistMusicPlay (HaramiVidEventItemAssoc) but not in HaramiVidMusicAssoc."
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
