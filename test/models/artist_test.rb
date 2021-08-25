# == Schema Information
#
# Table name: artists
#
#  id          :bigint           not null, primary key
#  birth_day   :integer
#  birth_month :integer
#  birth_year  :integer
#  note        :text
#  wiki_en     :text
#  wiki_ja     :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  place_id    :bigint           not null
#  sex_id      :bigint           not null
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

end

