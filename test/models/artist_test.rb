# == Schema Information
#
# Table name: artists
#
#  id                                         :bigint           not null, primary key
#  birth_day                                  :integer
#  birth_month                                :integer
#  birth_year                                 :integer
#  memo_editor(Internal-use memo for Editors) :text
#  note                                       :text
#  wiki_en                                    :text
#  wiki_ja                                    :text
#  created_at                                 :datetime         not null
#  updated_at                                 :datetime         not null
#  place_id                                   :bigint           not null
#  sex_id                                     :bigint           not null
#
# Indexes
#
#  index_artists_birthdate    (birth_year,birth_month,birth_day)
#  index_artists_on_place_id  (place_id)
#  index_artists_on_sex_id    (sex_id)
#
# Foreign Keys
#
#  fk_rails_...  (place_id => places.id)
#  fk_rails_...  (sex_id => sexes.id)
#
require 'test_helper'

class ArtistTest < ActiveSupport::TestCase
  test "CHECK constraints and on_delete dependency" do
    sexi = Sex.create!(iso5218: 99)
    placei = Place.create!(prefecture: Prefecture.last)
    art = Artist.new(sex: sexi, place: placei)

    ## Check constraints
    
    art.birth_month = 13
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid){ art.save! }
    # DRb::DRbRemoteError: PG::CheckViolation: ERROR:  new row for relation "artists" violates check constraint "check_artists_on_birth_month"

    art.birth_month = 0
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid){ art.save! }

    art.birth_year = -1
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid){ art.save! }

    art.birth_day = -1
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid){ art.save! }

    art.birth_day = 32
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid){ art.save! }

    art.birth_year  = 2019
    art.birth_month = 2
    art.birth_day   = 29
    assert_raises(ActiveRecord::RecordInvalid){ art.save! }  # Not in a leap year, hence wrong

    # Successful save.
    art.birth_day   = 28
    assert_nothing_raised{ art.save! }

    ## Foreign key dependency

    art.birth_year  = nil
    art.birth_month = nil
    art.birth_day   = nil
    art.save!
    art.reload

    assert_raises(ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey){ sexi.destroy }
    # Rails: Message: <"Cannot delete record because of dependent artists">
    # DB: DRb::DRbRemoteError: PG::ForeignKeyViolation: ERROR:  update or delete on table "sexes" violates foreign key constraint "fk_rails_091139f78f" on table "artists"

    assert_raises(ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey){ placei.destroy }

    assert_difference('Engage.count', -2) do
      # 2 musics associated.
      artists(:artist2).destroy
    end

  end

  test "create with translation" do
    tit = 'a random new music'
    #assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::NotNullViolation){ # the latter for DB level.
    assert_raises(ActiveRecord::RecordInvalid, "Sex must exist"){
      Artist.create_with_orig_translation!({}, translation: {title: tit, langcode: 'en'})}
    bwt_new = Artist.create_with_orig_translation!({sex: Sex.first}, translation: {title: tit, langcode: 'en'})
    assert_equal tit, bwt_new.title

    title_existing = Translation.where(translatable_type: "Artist", langcode: "en", is_orig: true).first.title_or_alt
    bwt_new = Artist.create_with_orig_translation!({sex: Sex.first}, translation: {title: title_existing, langcode: 'en'})
    assert_equal title_existing, bwt_new.title, "Artist can have an existing title, as long as the Place differs, but..."
  end

  test "custom unique constraints" do
    art1 = artists( :artist1 )

    # Testing a private method
    assert     art1.send(:birth_day_not_disagree?, [nil, nil, nil], [nil, nil, nil])
    assert     art1.send(:birth_day_not_disagree?, [1999, nil, nil], [nil, nil, nil])
    assert     art1.send(:birth_day_not_disagree?, [nil, nil, nil], [1999, nil, nil])
    assert     art1.send(:birth_day_not_disagree?, [1999, nil, nil], [1999, nil, nil])
    assert     art1.send(:birth_day_not_disagree?, [1999, 1, 2], [1999, 1, 2])
    assert_not art1.send(:birth_day_not_disagree?, [1999, 1, 2], [1999, 1, 4])
    assert_not art1.send(:birth_day_not_disagree?, [2000, nil, nil], [1999, nil, nil])
    assert     art1.valid?

    hs_tmpl = %i(place birth_year birth_month birth_day).map{|i| [i, art1.send(i)]}.to_h
    art2 = Artist.new(sex: Sex[2], **hs_tmpl)  # Only Sex differs.
    assert_not_equal art1.sex, art2.sex
    assert     art2.valid?

    art2.unsaved_translations << art1.translations[0].dup
    art2.unsaved_translations[0].translatable_id = nil
    assert_not art2.valid?  # Different Sexes do not matter; unsaved_translations are inconsistent.

    assert_equal Place.unknown(country: Country['JPN']), art1.place  # Sanity check of Fixture
    art2.place = places(:unknown_place_tokyo_japan)
    assert_not art2.valid?  # Tokyo < Japan(existing), hence still invalid

    art2.place = Place.unknown
    assert_not art2.valid?  # Japan(existing) < World, hence still invalid

    art2.birth_month = nil
    assert_not art2.valid?  # nil birth month includes any values

    art2.place = places(:perth_aus)
    assert     art2.valid?  # Japan != Aus
    art2.save!

    art2.reload  # Essential to activate {#translations}
    assert_equal art1.title, art2.title  # save worked
    assert     art2.valid?  # comparing with Translations
    art2.place = art1.place
    assert_not art2.valid?  # validation fails again.
  end

  test "callback before_validation add_place_for_validation" do
    assert_nothing_raised(){
      Artist.create!(sex: Sex[9], note: 'callback-test') }
    assert_raises(ActiveRecord::RecordInvalid){
      Artist.create!(place: Place.unknown) }
  end

  test "find_by_name" do
    sex = Sex.unknown
    place = Place.unknown

    beatles = Artist.create_with_orig_translation!({sex: sex, place: place, note: 'with article'}, translation: {title: 'Beatles, The', langcode: 'en'})
    assert_equal beatles, Artist.find_by_name("Beatles, The")
    assert_equal beatles, Artist.find_by_name("The Beatles")
    assert_equal beatles, Artist.find_by_name("the  Beatles\n")
    assert_equal beatles, Artist.find_by_name("beatles\n")
    assert_nil            Artist.find_by_name("Les Beatles")

    angeles = Artist.create_with_orig_translation!({sex: sex, place: place, note: 'without article'}, translation: {title: 'ANGELES', langcode: 'en'})
    assert_equal angeles, Artist.find_by_name("angeles\n")
    assert_equal angeles, Artist.find_by_name("The  angeles\n")
    assert_equal angeles, Artist.find_by_name("Angeles, The")
    assert_equal angeles, Artist.find_by_name("los angeles\n")
    assert_equal angeles, Artist.find_by_name("angeles, Los\n")
    assert_equal angeles, Artist.find_by_name("Les Angeles")
    assert_nil            Artist.find_by_name("los angeles, Los\n")
  end

  test "unknown" do
    assert Artist.unknown
    assert_operator 0, '<', Artist.unknown.id
    obj = Artist[/UnknownArt/i, 'en']
    assert_equal obj, Artist.unknown
    assert obj.unknown?
  end

  test "self.find_all_by_title_plus" do
    art_pro = artists :artist_proclaimers
    art_pro_en = translations :artist_proclaimers_en
    place_uk_unknown = places :unknown_place_unknown_prefecture_uk
    genre_pop = genres :genre_pop
    sex9 = sexes( :sex9 )

    ## sanity checks of the fixture
    assert_equal 1983,             art_pro.birth_year
    assert_equal place_uk_unknown, art_pro.place
    assert_equal sex9,             art_pro.sex

    rela = Artist.find_all_by_title_plus(["The Proclaimers"])
    assert_operator 1, '<=', rela.count
    assert_equal    1,       rela.count
    artist =                   Artist.find_by_title_plus(["The Proclaimers"])
    assert_equal art_pro, artist
    assert_equal :exact,       artist.match_method
    assert_equal "Proclaimers, The", artist.matched_string # Definite article moved in the matched string
    assert_equal art_pro, Artist.find_by_title_plus(["the proclaimers"])

    assert_equal art_pro, Artist.find_by_title_plus(["Proclaimers, The"])
    assert_equal art_pro, Artist.find_by_title_plus(["proclaimers, the"], match_method_upto: :exact_ilike)
    assert_nil                Artist.find_by_title_plus(["proclaimers, the"], match_method_upto: :exact)
    assert_nil                Artist.find_by_title_plus(["proclaimers"],      match_method_upto: :exact_ilike)
    assert_equal art_pro, Artist.find_by_title_plus(["proclaimers"]) #Def:match_method_upto: :optional_article_ilike,
    assert_nil            Artist.find_by_title_plus(["proclaimers"], [:ruby, :romaji])

    # With a different place from the existing, nothing is matched, depending where.
    # The existing is UnknownPrefecture_in_UK, hence anywhere in the UK should match.
    perth_uk  = places( :perth_uk )
    perth_aus = places( :perth_aus )
    assert_equal art_pro, Artist.find_by_title_plus(["Proclaimers"])  # Template
    assert_equal art_pro, Artist.find_by_title_plus(["Proclaimers"], place: nil)
    assert_equal art_pro, Artist.find_by_title_plus(["Proclaimers"], place: Place.unknown)
    assert_equal art_pro, Artist.find_by_title_plus(["Proclaimers"], place:    perth_uk)
    assert_equal art_pro, Artist.find_by_title_plus(["Proclaimers"], place_id: perth_uk.id)
    assert_nil            Artist.find_by_title_plus(["Proclaimers"], place:    perth_aus)
    assert_nil            Artist.find_by_title_plus(["Proclaimers"], place_id: perth_aus.id)

    # With a different year from the existing, nothing is matched.
    assert_equal art_pro, Artist.find_by_title_plus(["Proclaimers"], birth_year: nil)
    assert_nil            Artist.find_by_title_plus(["Proclaimers"], birth_year: 1877)

    # With a different Sex from the existing, it still matches.
    assert_equal art_pro, Artist.find_by_title_plus(["Proclaimers"], sex: nil)
    assert_equal art_pro, Artist.find_by_title_plus(["Proclaimers"], sex: Sex.unknown)
    assert_equal art_pro, Artist.find_by_title_plus(["Proclaimers"], sex: sex9)
    assert_equal art_pro, Artist.find_by_title_plus(["Proclaimers"], sex_id: sex9.id)
  end

  test "music association" do
    artai = artists(:artist_ai)
    assert_operator 1, :<=, (count_mu = artai.musics.count), 'check has_many musics and also fixtures'
    assert_difference("artai.musics.count", 1){  # via Engage
      artai.musics << musics(:music_ihojin1)
    }
  end

  test "associations via ArtistMusicPlayTest" do
    evi0 = EventItem.create!(machine_title: "EvI0 ArtistMusicPlayTest", event: Event.first)
    art0 = Artist.create!(sex: Sex.first).with_translation(langcode: "en", is_orig: "true", title: "Sam0 ArtistMusicPlayTest")
    mus0 = Music.create!().with_translation(langcode: "en", is_orig: "true", title: "Song0 ArtistMusicPlayTest")

    art1  = artists(:artist_harami)
    evit1 = event_items(:evit_1_harami_budokan2022_soiree)
    assert_operator 1, :<=, art1.artist_music_plays.count, 'check has_many artist_music_plays and also fixtures'
    assert_operator 1, :<=, (count_ev = art1.event_items.count)
    assert   art1.event_items.include?(evit1)
    assert_operator 1, :<=, (count_mu = art1.play_musics.count), 'check has_many musics and also fixtures'
    assert_equal 1,         art1.play_roles.count, 'check has_many play_roles and also fixtures'
    assert_equal 1,         art1.instruments.count, 'check has_many instruments and also fixtures'

    art1.artist_music_plays << ArtistMusicPlay.new(event_item: evit1, music: mus0, play_role: PlayRole.first, instrument: Instrument.first)
    assert_equal count_mu+1, art1.play_musics.count
    assert_equal count_ev,   art1.event_items.count, 'distinct?'

    assert_difference("ArtistMusicPlay.count", -ArtistMusicPlay.where(artist: art1).count, "Test of dependent"){
      # must first destroy dependent ChannelOwner => Channel(s) => HaramiVid(s) => Harami1129(s) before destroying Artist
      if (chow=art1.channel_owner)
        if chow && chow.channels.exists?
          chow.channels.each do |ea_ch|
            ea_ch.harami1129s.update_all(harami_vid_id: nil) if ea_ch.harami1129s.exists?
            ea_ch.harami_vids.destroy_all if ea_ch.harami_vids.exists?
            ea_ch.destroy!
          end
        end
        chow.reload.destroy
      end
      art1.reload.destroy
    }
  end

  # @see  test "associations" in /test/models/channel_owner_test.rb
  test "channel_owner association" do
    art = artists(:artist_proclaimers)
    chan1 = ChannelOwner.create_basic!(title: "dummy", langcode: "en", is_orig: false, themselves: true, artist: art, note: "chan1-dayo")

    assert_equal chan1, art.channel_owner
    assert_equal chan1.title(langcode: :en), art.title(langcode: :en)

    # assert_raises(ActiveRecord::StatementInvalid){ art.delete }  # DB level
    ## PostgreSQL server log example:
    # ERROR:  update or delete on table "artists" violates foreign key constraint "fk_rails_8d25b890da" on table "channel_owners"
    # DETAIL:  Key (id)=(458496872) is still referenced from table "channel_owners".
    ## NOTE: Don't run the code above in testing, because this would mess up the subsequent statements!
    # For example, you cannot do "chan1.destroy" anymore, presumably because Rails' cache consider
    # "chan1.artist_id" is invalid, pointing to a non-existent "artists" table entry in the DB (which is actually not
    # the case because the DB prevents the Artist from being deleted).

    assert_raises(ActiveRecord::DeleteRestrictionError){ art.destroy! }  # Rails validation.

    assert_difference('ChannelOwner.count', -1, "ChannelOwner=#{chan1.inspect}"){
      chan1.destroy }
    art.reload
    assert_difference('Artist.count', -1){
      art.destroy!  }
  end

  # @see  test "associations" in /test/models/channel_owner_test.rb
  test "channel_owner translations" do
    art = artists(:artist_proclaimers)
    assert_equal 1, art.translations.where(langcode: "en").size, 'check fixtures'
    art.translations << Translation.new(title: "second-tit", langcode: "en", is_orig: false, weight: 1000000)
    art.reload
    assert_equal 2, art.translations.where(langcode: "en").size, 'sanity check'

    chan1 = ChannelOwner.create_basic!(title: "dummy", langcode: "en", is_orig: false, themselves: true, artist: art, note: "chan1-dayo")
    # only 1 Translation should be imported.

    assert_equal chan1, art.channel_owner, 'sanity check'
    assert_equal chan1.title(langcode: :en), art.title(langcode: :en), 'sanity check'
    assert_equal 1, chan1.translations.where(langcode: "en").size

    ## Now update Translation of Artist, which should be propagated to ChannelOwner!
    art_tra_en = art.best_translations["en"]
    art_tra_en.update!(alt_title: (new_alt="NewAlt"), romaji: (new_rom="NewRom"), weight: (new_wei=12.3))
    art.reload
    assert_equal new_alt, art.alt_title(langcode: "en"), 'sanity check'
    assert_equal new_wei, art.best_translations["en"].weight, 'sanity check'

    chan1.reload
    assert_equal 1, chan1.translations.where(langcode: "en").size
    assert_equal new_alt, chan1.alt_title(langcode: "en")
    assert_equal new_rom, chan1.romaji(langcode: "en")
    assert_equal new_wei, chan1.best_translations["en"].weight
  end

  test "create_basic!" do
    art = nil
    assert_nothing_raised{
      art = Artist.create_basic!}
    assert_match(/^Artist\-basic\-/, art.title)
    assert  art.best_translation.is_orig
    assert_equal Sex, art.sex.class
    assert_nil  art.birth_year

    art = Artist.create_basic!(sex_id: Sex.third.id)
    assert_equal Sex.third, art.sex

    art = Artist.create_basic!(sex: Sex.second, sex_id: Sex.third.id)
    assert_equal Sex.third, art.sex

    se = Sex.last
    art = Artist.create_basic!(sex: se)
    assert_equal se, art.sex

    #art = Artist.new_basic
    art = Artist.initialize_basic
    art.save!
    art.reload
    assert art.best_translation.present?

    tra = Artist.first.best_translation.dup
    assert_nothing_raised{
      art = Artist.create_basic!(translation: tra, birth_year: 1907)}  # Identical Translation for an existing Artist with a different birth_year is accepted.
    assert_equal 1907, art.birth_year
  end
end

