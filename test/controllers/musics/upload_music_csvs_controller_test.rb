# coding: utf-8
require 'test_helper'
require 'w3c_validators'

class Musics::UploadMusicCsvsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  setup do
    @validator = W3CValidators::NuValidator.new
    @editor = roles(:general_ja_editor).users.first  # Editor can manage.
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
  end

  test "should not create when no file is specified" do
    sign_in @editor

    assert_difference('Translation.count*1000 + Music.count*100 + Artist.count*10 + Engage.count*1', 0) do
      post musics_upload_music_csvs_url, params: { }
      assert_response :redirect
      assert_redirected_to new_music_url
    end
  end

  test "should create" do
    sign_in @editor

    # Creation success
    #
    # See music_test.rb for unit-testing.
    assert_difference('Translation.count*1000 + Music.count*100 + Artist.count*10 + Engage.count*1', 7323) do # Because the 3rd row is Artist.unknown, which already exists.
      post musics_upload_music_csvs_url, params: { file: fixture_file_upload('music_artists_3rows.csv', 'text/csv') }
      assert_response :success
    end
    trans_last = Translation.order(created_at: :desc).first
    assert_equal '子守唄',     trans_last.title
    assert_equal 'コモリウタ', trans_last.ruby
    assert_equal 'Komoriuta',  trans_last.romaji
    assert_equal '香川県',     Music.order(created_at: :desc).first.place.prefecture.title(langcode: "ja")
    assert_equal 'ja',         trans_last.langcode
    assert_equal false,        trans_last.is_orig, 'ja-title with no en-title but with "en" means ja-title should be is_orig=false, but...'
    assert_equal @editor,      trans_last.create_user, "(NOTE: for some reason, created_user_id is nil?): (last-)Translation=#{trans_last.inspect}"
    assert_equal Float::INFINITY, trans_last.weight

    # Repeated "creation" success, doing nothing
    assert_difference('Translation.count*1000 + Music.count*100 + Artist.count*10 + Engage.count*1', 0) do
      post musics_upload_music_csvs_url, params: { file: fixture_file_upload('music_artists_3rows.csv', 'text/csv') }
      assert_response :success
    end
  end
end

