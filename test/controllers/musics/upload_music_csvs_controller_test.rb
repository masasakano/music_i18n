# coding: utf-8
require 'test_helper'

class Musics::UploadMusicCsvsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @editor = users(:user_editor_general_ja)  # Editor can manage.
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should fail to post create" do
    post musics_upload_music_csvs_url
    assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
  end

  test "invalid encoding file update" do
    sign_in @editor

    # Prepare a temporary file /test/fixtures/files/*.csv with a wrong character code
    fixture_dir = Rails.root / 'test' / 'fixtures' / 'files'
    Tempfile.open(['invalid_csv', '.csv'], fixture_dir, encoding: 'ascii-8bit'){|io|
      io.write 0x8f.chr  # #<Encoding:ASCII-8BIT>
      io.flush  # Essential (as newline has not been written?)
      post musics_upload_music_csvs_url, params: { file: fixture_file_upload(File.basename(io.path), 'text/csv') }
      assert_response :redirect
      assert_redirected_to musics_url
    }
    sign_out @editor
  end

  test "should not create when no file is specified" do
    sign_in @editor

    assert_difference('Translation.count*1000 + Music.count*100 + Artist.count*10 + Engage.count*1', 0) do
      post musics_upload_music_csvs_url, params: { }
      assert_response :redirect
      assert_redirected_to new_music_url
    end
    sign_out @editor
  end

  test "should create" do
    sign_in @editor

    get artists_url
    previous_str = _str_user_id_display_name(ModuleWhodunnit.whodunnit)  #  just to (potentially) suppress mal-functioning in setting this...

    # Creation success
    #
    # See music_test.rb for unit-testing.
    assert_difference('Translation.count*1000 + Music.count*100 + Artist.count*10 + Engage.count*1', 7323) do # Because the 3rd row is Artist.unknown, which already exists.
      post musics_upload_music_csvs_url, params: { file: fixture_file_upload('music_artists_3rows.csv', 'text/csv') }
      assert_response :success
    end
     ## See test/fixtures/files/music_artists_3rows.csv
    mu_ito     = Music.order(created_at: :desc)[2]  # ,糸,,Ito,Thread,1992,,,Miyuki Nakajima,ja,クラシック,compo,
    mu_smap    = Music.order(created_at: :desc)[1]
    mu_last    = Music.order(created_at: :desc).first
    art_last  = Artist.order(created_at: :desc).first
    art_smap  = art_last  # Because the last row in CSV does not specify Artist => Artist.unknown
    trans_last = Translation.order(created_at: :desc).first
    eng_smap  = Engage.order(created_at: :desc)[1]
    mu_last_ja  =  mu_last.best_translation(:ja)
    art_last_en = art_last.best_translation(:en)
    art_smap_en = art_last_en
    assert_equal '子守唄',     trans_last.title
    assert_equal 'コモリウタ', trans_last.ruby
    assert_equal 'Komoriuta',  trans_last.romaji
    assert_equal 'ja',         trans_last.langcode
    assert_equal  trans_last,  mu_last_ja
    assert_nil    mu_last_ja.is_orig  # complicated case, where the CSV specifies the language of "en" with no English title provided.
    assert_nil    mu_last.orig_locale

    assert_equal 'SMAP', art_smap_en.title
    assert_equal 'en',   art_smap_en.langcode
    assert_equal "en",   art_smap.orig_locale

    assert_equal 'Thread', mu_ito.best_translation(:en).title
    assert_equal '糸',     mu_ito.best_translation(:ja).title
    assert_equal 'Ito',    mu_ito.best_translation(:ja).romaji
    assert_equal "ja",     mu_ito.orig_locale  # from CSV line

    assert_equal '香川県',     mu_last.place.prefecture.title(langcode: "ja")
    assert_equal Genre.select_regex(:title, /クラシック/).first, mu_ito.genre
    assert_equal 1992,  mu_ito.year
    mu_it_eng = mu_ito.engages.first
    assert_equal 1992,  mu_it_eng.year
    assert_equal EngageHow.select_regex(:title, /compo/i).first, mu_it_eng.engage_how  # case-insensitive search!

    assert_equal art_smap, eng_smap.artist
    assert_equal mu_smap,  eng_smap.music

    # assert_equal false,        trans_last.is_orig, 'ja-title with no en-title but with "en" means ja-title should be is_orig=false, but...'  # => nil because the input langcode="en" does not accept JA chars.
    assert_equal @editor,      trans_last.create_user, "(NOTE: for some reason, created_user_id is nil?): Previous=#{previous_str} User=#{[@editor.id,@editor.email.sub(/@.+/,'')].inspect} #{((whod=ModuleWhodunnit.whodunnit).nil? || whod.id != @editor.id) ? '(!!)!=' : '=='} ModuleWhodunnit.whodunnit=#{ModuleWhodunnit.whodunnit.inspect} / PaperTrail.request.whodunnit=#{PaperTrail.request.whodunnit.inspect} / (last-)Translation=#{trans_last.inspect}"
    assert_equal 40000.0, trans_last.weight  # ==10000*8/2 NOT Float::INFINITY; see Translation#def_weight and (role.rb for 10000.0)

    # Repeated "creation" success, doing nothing
    assert_difference('Translation.count*1000 + Music.count*100 + Artist.count*10 + Engage.count*1', 0) do
      post musics_upload_music_csvs_url, params: { file: fixture_file_upload('music_artists_3rows.csv', 'text/csv') }
      assert_response :success
    end
    sign_out @editor
  end

  private
    # debug helper to return String of User.
    def _str_user_id_display_name(user)
      user ? [@editor.id, @editor.email.sub(/@.+/,'')].inspect : "nil"
    end
end

