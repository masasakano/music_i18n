# coding: utf-8
require "test_helper"

class Artists::MergesControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @artist = artists(:artist_saki_kubota)
    @other  = artists(:artist_ai)
    @music1 = musics(:music_ihojin1)
    @music2 = musics(:music_ihojin2)
    @moderator_all = users(:user_moderator_all)   # All-mighty moderator
    @editor     = users(:user_editor_general_ja)  # (General) Editor can manage.
    @translator = users(:user_translator)
    @def_prm_artist = {
      other_artist_id: @other.id.to_s,
      to_index: '1',
      lang_orig: '1',
      lang_trans: nil,
      engage: '1',
      prefecture_place: '0',
      sex: '1',
      birthday: '0',
      wiki_en: '1',
      wiki_ja: '0',
    }
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should get new" do
    assert_raise(ActionController::UrlGenerationError){
      get artists_new_merges_url  # ID must be given for this :new
    }

    # Fail: No privilege
    get artists_new_merges_url(@artist)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor

    get artists_new_merges_url(@artist)
    assert_response :success

    assert_match(/Other artist/i, css_select('form div.field label').text)
  end

  test "should get edit" do
    assert_raise(ActionController::UrlGenerationError){
      get artists_edit_merges_url  # ID must be given for this :edit
    }

    get artists_edit_merges_url(@artist)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in @editor
    assert_raise(ActionController::ParameterMissing){
      get artists_edit_merges_url(@artist)
    } # This deactivates sign_in !!
    
    sign_in @editor
    get artists_edit_merges_url(@artist, params: {other_artist_id: @other.id})
    assert_response :success
 
    get artists_edit_merges_url(@artist, params: {artist: {other_artist_id: @other.id}})
    assert_response :success

    get artists_edit_merges_url(@artist, params: {artist: {other_artist_title: "久保田" }})
    assert_response :redirect
    assert_redirected_to artists_new_merges_url(@artist)
    follow_redirect!
    flash_regex_assert(/No Artist match/i, type: :alert) # because the current Artist is excluded.
 
    asex = Sex.first
    titnew = "久保田違う人だよ"
    mu2 = Artist.create_with_orig_translation!({sex: asex, note: 'MergesController-temp-creation'}, translation: {title: titnew, langcode: 'ja'})  # Create another Artist containing "久保田" in the title
    get artists_edit_merges_url(@artist, params: {artist: {other_artist_id: nil, other_artist_title: "久保田" }})
    assert_response :success

    titnew3 = "久保だけ一緒の人"
    mu3 = Artist.create_with_orig_translation!({sex: asex, note: 'MergesController-temp-creation'}, translation: {title: titnew3, langcode: 'ja'})  # Create another Artist containing "久保田" in the title
    get artists_edit_merges_url(@artist, params: {artist: {other_artist_id: nil, other_artist_title: "久保" }})
    assert_response :success
    flash_regex_assert(/found more than 1 Artist/i, type: :warning)
 
    strin = sprintf("%s   [%s] [%d] ", titnew, "ja", mu2.id)
    get artists_edit_merges_url(@artist, params: {artist: {other_artist_id: nil, other_artist_title: titnew }})
    assert_response :success
    assert css_select('table th').text.include? titnew
 
    strin = sprintf("%s   [%s] ", titnew, "ja")
    get artists_edit_merges_url(@artist, params: {artist: {other_artist_id: nil, other_artist_title: "久保田" }}) # there should be two 久保田s and one of them is the ID, hence there should be only 1 (== mu2).
    assert_response :success
    assert css_select('table th').text.include? titnew
 
    get artists_edit_merges_url(@artist, params: {artist: {other_artist_id: nil, other_artist_title: "こんな曲はきっとないことでしょう、どうするかな" }})
    assert_response :redirect
    follow_redirect!
    assert css_select('p.alert').text.include? 'No Artist matches'
  end

  ## @artist is merged into @other
  test "should update1" do
    prm_artist = @def_prm_artist.merge({})
    #  other_artist_id: @other.id.to_s,
    #  to: '1',            # => @other
    #  lang_orig: '1',        # => @other
    #  lang_trans: nil,       # => @other
    #  engage: '1'            # => simply merged for there are no overlaps.
    #  prefecture_place: '0', # => @artist
    #  sex: '1',
    #  birthday: '0',
    #  wiki_en: '1',   # "abc"    <=> nil    (see immediate below)
    #  wiki_ja: '0',   # "日本00" <=> "日本other"

    @artist.update!(created_at: DateTime.new(1))  # very old creation.
    @artist.update!(wiki_en: "abc", wiki_ja: '日本00')
    @other.update!( wiki_en: nil,   wiki_ja: '日本other')  # testing nil (so, the other one is adopted)
    @artist.update!(birth_year:  nil, birth_month: 9, birth_day: nil) # this will be chosen b/c at least one of them is non-nil.
    @other.update!( birth_year: 1990, birth_month: 2, birth_day: 3)
    @other.update!( wiki_en: nil,   wiki_ja: '日本other')  # testing nil (so, the other one is adopted)
    artist_bkup = @artist.dup
    other_bkup = @other.dup
    refute @artist.destroyed?, 'sanity check-artist-kubota'
    refute @other.destroyed?, 'sanity check-other'
    
    hvma_bkup = harami_vid_music_assocs(:harami_vid_music_assoc_3_ihojin1)
    assert  hvma_bkup.music.artists.include?(@artist), 'sanity-check'
    place_bkup0 = @artist.place
    sex_bkup1   = @other.sex
    birthday_bkup0 = [@artist.birth_year, @artist.birth_month, @artist.birth_day]
    birthday_bkup1 = [@other.birth_year,  @other.birth_month,  @other.birth_day]
    wikien_bkup1   = @artist.wiki_en  # because @other.wiki_en.nil?
    wikija_bkup1   = @artist.wiki_ja

    # These tests do not cover many potentials, to be honest!
    engage2change11 = engages(:engage_kubota_ihojin1_1) # changed to belong to AI (no change in other parameters)
    engage2change13 = engages(:engage_kubota_ihojin1_3) # changed to belong to AI (no change in other parameters)
    engage2change22 = engages(:engage_kubota_ihojin2_2) # changed to belong to AI (no change in other parameters)
    assert_equal @artist, engage2change11.artist, 'sanity-check'
    assert_equal engage2change13.artist, engage2change22.artist, 'sanity-check'
    assert @artist.engages.exists?, 'sanity-check'
    assert @other.engages.exists?, 'sanity-check'
    n_engages_be4 = @artist.engages.count + @other.engages.count

    trans2delete1 = translations(:artist_saki_kubota_ja)
    assert trans2delete1.is_orig, 'sanity-check: because of is_orit=true, this will be deleted.'
    trans2remain1 = translations(:artist_saki_kubota_en1)
    trans2remain2 = translations(:artist_saki_kubota_en2)
    assert_operator 2, :<, @artist.translations.count, 'sanity-check of fixtures' # should be 3 so far.
    assert_equal @artist, trans2delete1.translatable, 'sanity-check'
    assert_equal trans2delete1.translatable_id, trans2remain2.translatable_id, 'sanity-check'

    patch artists_update_merges_url(@artist), params: { artist: prm_artist }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    ### Trans (Moderator (10➝16;10*, 40), Editor1 (100→DEL,100), Editor2(12➝22,)) 

    sign_in @editor
    assert_difference('Artist.count', -1) do
      assert_difference('Translation.count', -1) do # 
        assert_difference('HaramiVidMusicAssoc.count', 0) do
          assert_difference('Engage.count', 0) do
            assert_difference('Music.count', 0) do
              assert_difference('Place.count', 0) do
                patch artists_update_merges_url(@artist), params: { artist: prm_artist }
              end
            end
          end
        end
      end
    end
    assert_response :redirect
    assert_redirected_to artist_path(@other)

    refute Artist.exists?(@artist.id)  # refute @artist.destroyed?  ;;; does not work
    assert Artist.exists?(@other.id)
    @other.reload

    # created_at is adjusted to the older one.
    assert_equal @artist.created_at, @other.created_at

    # Translations deleted/remain
    refute Translation.exists?(trans2delete1.id)
    assert Translation.exists?(trans2remain1.id)
    assert Translation.exists?(trans2remain2.id)

    # Translations
    user_assert_updated?(trans2remain1)  # defined in test_helper.rb
    user_assert_updated?(trans2remain2)  # defined in test_helper.rb

    # HaramiVidMusicAssoc
    user_refute_updated?(hvma_bkup, 'HaramiVidMusicAssoc should not change')  # defined in test_helper.rb

    # Engage
    assert Engage.exists?(engage2change11.id)
    assert Engage.exists?(engage2change13.id)
    assert Engage.exists?(engage2change22.id)
    cont_old = engage2change11.contribution
    [engage2change11, engage2change13,  engage2change22]. each do |i|
      user_assert_updated_attr?(i, :artist)  # defined in test_helper.rb
    end
    assert_equal @other,   engage2change11.artist  # it was just reloaded in the method above.
    assert_equal cont_old, engage2change11.contribution  # no change
    assert_equal n_engages_be4, Engage.where(artist: @other).count, "Engage-s (with no overlaps) should have been merged, but..."

    # Place, Sex, birthday
    assert_equal place_bkup0, @other.place
    assert_equal sex_bkup1, @other.sex

    arbt = [@artist, @other].map{|em| %i(birth_year birth_month birth_day).map{|eat| em.send(eat)}}
    # The following used to be the case up to Git-commit ae38d91
    # assert_equal birthday_bkup0, [@other.birth_year, @other.birth_month, @other.birth_day], "#{arbt.inspect}" # => [[nil, 9, nil], [1990, 9, 3]]
    ar_birth = [birthday_bkup1[0], birthday_bkup0[1], birthday_bkup1[2]] # [1990, 9, 3]
    assert_equal ar_birth, [@other.birth_year, @other.birth_month, @other.birth_day], "[Model1,2]=#{arbt.inspect}"

    assert_equal wikien_bkup1, @other.wiki_en
    assert_equal wikija_bkup1, @other.wiki_ja

    # note
    str = other_bkup.note+" "+artist_bkup.note
    assert_equal str, @other.note
  end # test "should update1" do


  ## merging case that used to fail.
  test "should update2" do
    sign_in @moderator_all 

    # Populates from Harami1129 fixtures
    h1129s = [harami1129s(:harami1129_sting1), harami1129s(:harami1129_sting2)].map{|i| _populate_harami1129_sting(i)}  # defined in test_helper.rb

    hvma_bkups = h1129s.map{|i| i.harami_vid.harami_vid_music_assocs}.flatten  # HaramiVidMusicAssoc

    # sanity checks
    assert_equal 2, hvma_bkups.compact.size, 'HaramiVidMusicAssoc should be defined, but...'
    hvma_bkups.each_with_index do |ehv, i|
      assert_equal 1, ehv.music.artists.size, 'Each HaramiVid has only 1 artist.'
    end

    artist_origs = hvma_bkups.map{|i| i.music.artists.first}
    refute_equal(*(artist_origs+['Artists should differ, but...']))
#print "DEBUG(#{File.basename __FILE__}): artist-translat="; p artist_origs.map{|em| em.translations.map{|et| et.title_or_alt}}.inspect
#print "DEBUG(#{File.basename __FILE__}): artist-origs-tra="; p artist_origs.map{|em| em.orig_translation.title_or_alt}.inspect

    transs = artist_origs.map{|i| i.translations}
    transs.each do |ea|
      ea.each do |ej|
        ej.reload  # to make sure the contents are loaded
      end
      assert_equal 1, ea.size
      bool = ea.first.is_orig
      assert bool, "is_orig should be true but (#{bool.inspect})"
    end
    trans_attrs = {}.with_indifferent_access  # Hash of Double Arrays
    %i(title is_orig translatable_id).each do |ek|
      trans_attrs[ek] = artist_origs.map{|i| i.translations.map{|j| j.send(ek)}}  # Double Array
    end
    engages = h1129s.map{|i| i.engage}.map{|j| j.reload}
    engages2= h1129s.map{|i| i.harami_vid.musics.map{|em| em.engages}}.flatten.map{|ee| ee.reload; ee}
    assert_equal engages, engages2, 'sanity-check'
    assert_equal 2, engages.size, 'sanity-check'
    engages[1].update!(contribution: 0.7)

    # Sanity checks (Orig-Langcodes should be defined and differ between the two ("Sting" <=> "スティング"))
    refute_equal transs[0][0].orig_langcode, transs[1][0].orig_langcode

    prm_artist = {
      other_artist_id: artist_origs[1].id.to_s,
      to_index: '1',
      lang_orig: '1',
      lang_trans: nil,
      engage: '1',
      prefecture_place: nil,
      sex: nil,
      birthday: nil,
      wiki_en: '0',  # "my_wiki_en0" <=> "my_wiki_en1"  (these are set immediate below)
      wiki_ja: '1',  # "my_wiki_ja0" <=> "my_wiki_ja1"
    }

    # Sets wiki_en|ja
    artist_origs.each_with_index do |art, i|
      art.update!(%w(en ja).map{|j| s="wiki_"+j; [s, "my_#{s}#{i}"]}.to_h)
    end
    wikien_bkup0   = artist_origs[0].wiki_en
    wikija_bkup1   = artist_origs[1].wiki_ja

    assert_difference('Artist.count', -1) do
      assert_difference('Translation.count', 0) do # should not change b/c original translations are completely different (one of them used to be deleted, up to Git-commit ae38d91.
        assert_difference('HaramiVidMusicAssoc.count', 0) do
          assert_difference('Engage.count', 0) do
            assert_difference('Music.count', 0) do
              assert_difference('Place.count', 0) do
                patch artists_update_merges_url(artist_origs[0]), params: { artist: prm_artist }
              end
            end
          end
        end
      end
    end
    assert_response :redirect
    assert_redirected_to artist_path(artist_origs[1])

    refute Artist.exists?(artist_origs[0].id)  # refute artist_origs[0].destroyed?  ;;; does not work
    assert Artist.exists?(artist_origs[1].id)
    artist_origs[1].reload

    # created_at is adjusted to the older one.
    assert_equal artist_origs[0].created_at, artist_origs[1].created_at

    # HaramiVidMusicAssoc
    hvma_bkups.each do |ehv|
      user_refute_updated?(ehv, 'HaramiVidMusicAssoc should not change - its Music remains unchanged, whereas the Artist for the Music has changed.')  # defined in test_helper.rb
    end

    # Translations deleted/remain
    assert Translation.exists?(transs[0][0].id), "Both translations (is_orig was true for both (ja and en)) should remain."
    assert Translation.exists?(transs[1][0].id)
    #refute Translation.exists?(trans2delete1.id)
    #assert Translation.exists?(trans2remain1.id)
    #assert Translation.exists?(trans2remain2.id)
    refute_equal transs[0][0], transs[1][0]

    # Translations
    tra00 = Translation.find(transs[0][0].id)
    assert       trans_attrs[:is_orig][0]
    assert_equal false, tra00.is_orig
    user_assert_updated?(     transs[0][0], "should be updated because is_orig changed from true to false: trans=#{transs[0][0].inspect}")  # defined in test_helper.rb
    assert_equal false, Translation.find(transs[0][0].id).is_orig
    refute_equal trans_attrs[:translatable_id][0][0], tra00.translatable_id
    assert_equal trans_attrs[:translatable_id][1][0], tra00.translatable_id
    # user_assert_updated_attr?(transs[0][0], :translatable_id)  # does not work because model is reloaded?

    # Engage
    assert Engage.exists?(engages[0].id)
    assert Engage.exists?(engages[1].id)
    cont_old = engages[1].contribution

    user_assert_updated_attr?(engages[0], :artist_id)  # model reloaded. defined in test_helper.rb
    user_refute_updated?(     engages[1])  # model reloaded. defined in test_helper.rb

    assert_equal engages[1].artist, engages[0].artist  # it was just reloaded in the method above.
    assert_equal cont_old, engages[1].contribution  # no change

    # wiki_en|ja
    assert_equal wikien_bkup0, artist_origs[1].wiki_en
    assert_equal wikija_bkup1, artist_origs[1].wiki_ja
  end # test "should update2" do


  private

end

