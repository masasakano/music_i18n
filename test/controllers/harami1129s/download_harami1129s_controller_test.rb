# coding: utf-8
require 'test_helper'

class DownloadHarami1129sControllerTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------
  # add from here
  include Devise::Test::IntegrationHelpers

  setup do
    #if !ENV['URI_HARAMI1129'] || /\.(com|org|net)$/ =~ URI.parse(ENV['URI_HARAMI1129']).host.downcase
    #  raise 'Environmental variable URI_HARAMI1129 should be specified for testing.'
    #end
    #ENV['URI_HARAMI1129'] = 'file://'+(Rails.root+'test/controllers/harami1129s/data/harami1129_sample.html').to_s
    ENV['URI_HARAMI1129'] = (Rails.root+'test/controllers/harami1129s/data/harami1129_sample.html').to_s

    get '/users/sign_in'
    sign_in users(:user_sysadmin)
    #sign_in User.find(1)  # superuser
    post user_session_url

    ## If you want to test that things are working correctly, uncomment this below:
    #follow_redirect!
    #assert_response :success
  end
  # add until here
  # ---------------------------------------------

  # setup do
  #   @harami1129 = harami1129s(:harami1129one)
  # end

  test "should get index" do
    begin
      #get '/users/sign_in'
      ## sign_in users(:user_001)
      #sign_in User.find(1)  # superuser
      #post user_session_url

      ## If you want to test that things are working correctly, uncomment this below:
      #follow_redirect!
      #assert_response :success

      #print "DEBUG:logged_in?=#{user_signed_in?}; current_user="; p current_user  # => undefined method `user_signed_in?' 'current_user'
      n_downloaded = 3
      PARAMS2SEND = {debug: 1, max_entries_fetch: n_downloaded, Harami1129s::DownloadHarami1129sController::DOWNLOAD_FORM_SUBMIT_NAME => "Download data", }
      Harami1129.delete_all
      assert_difference('Harami1129.count', n_downloaded) do
        formprm = Harami1129s::DownloadHarami1129sController::DOWNLOAD_FORM_STEP[:download]
        PARAMS2SEND[:step_to] = formprm
        get new_harami1129s_download_harami1129s_url, params: PARAMS2SEND
        assert_response :redirect
        assert_redirected_to harami1129s_url
      end
      h1129 = Harami1129.first
      assert_operator h1129.title.size, '>', 0
      assert_nil      h1129.ins_title
      assert_nil      h1129.ins_link_root

      Harami1129.delete_all
      assert_difference('Harami1129.count', n_downloaded) do
        formprm = Harami1129s::DownloadHarami1129sController::DOWNLOAD_FORM_STEP[:internal_insert]
        PARAMS2SEND[:step_to] = formprm
        get new_harami1129s_download_harami1129s_url, params: PARAMS2SEND
        assert_response :redirect
        assert_redirected_to harami1129s_url
      end
      h1129 = Harami1129.first
      assert_operator h1129.title.size, '>', 0
      assert_equal    h1129.title[0..10],          h1129.ins_title[0..10]
      assert_equal    h1129.title.gsub(/！/, '!'), h1129.ins_title
      assert_equal    'youtu.be/'+h1129.link_root, h1129.ins_link_root
      assert_nil  Artist['aiko']

      Harami1129.delete_all
      n_downloaded = 15  # more download
      n_artists = Artist.count
      n_musics  = Music.count
      artists_orig_ids = Artist.pluck :id
      musics_orig_ids  = Music.pluck :id
      #puts "Artist="+Artist.all.map(&:title).inspect
      ## Artist=["Madonna", "John Lennon", "ハラミちゃん", nil, "UnknownArtist", "Ai", "RCサクセション"]
      ## Music=["Music1 by Madonna", "Give Peace a Chance Music2", nil, nil, "UnknownMusic", "How?", "Story", "乾杯"]
      assert_difference('Harami1129.count', n_downloaded) do
        formprm = Harami1129s::DownloadHarami1129sController::DOWNLOAD_FORM_STEP[:populate]
        PARAMS2SEND[:step_to] = formprm
        get new_harami1129s_download_harami1129s_url, params: PARAMS2SEND.merge({max_entries_fetch: n_downloaded})
        assert_response :redirect
        assert_redirected_to harami1129s_url
      end
      h1129 = Harami1129.first
      assert_operator h1129.title.size, '>', 0
      assert_equal    h1129.title[0..10],          h1129.ins_title[0..10]
      assert_equal    h1129.title.gsub(/！/, '!'), h1129.ins_title
      assert_equal    'youtu.be/'+h1129.link_root, h1129.ins_link_root
      assert_equal    h1129.singer, h1129.engage.artist.title
      assert_equal    h1129.song,   h1129.engage.music.title

      artist_aiko = Artist['aiko']
      assert_equal 'aiko', artist_aiko.title
      assert_operator Harami1129.where(ins_singer: 'aiko').count, '>', 0

      # In DB, it has been 'Ai', whereas in the downloaded it is 'AI'
      artist_ai   = Artist.of_title('ai').first  # case-insensitive
      assert_equal 'Ai',   artist_ai.title
      assert_equal 0, Harami1129.where(ins_singer: 'Ai').count
      assert_operator Harami1129.pluck(:ins_singer).select{|i| /\Aai\z/i =~ i}.size, '>', 0

      _weight_user_id_nil? Translation.last

      ## Artist=["Madonna", "John Lennon", "ハラミちゃん", nil, "UnknownArtist", "Ai", "RCサクセション", "Earth, Wind & Fire", "aiko", "あいみょん"].
      assert_operator Artist.count, '>', n_artists
      assert_not Artist.any?{|i| !artists_orig_ids.include?(i.id) && !Harami1129.pluck(:ins_singer).map(&:upcase).include?(i.title.upcase)}
      assert  Artist.last.translations.exists?
      _weight_user_id_nil? Artist.last.translations.last

      ## Music=["Music1 by Madonna", "Give Peace a Chance Music2", nil, nil, "UnknownMusic", "How?", "Story", "乾杯", "Boogie Wonderland", "雨上がりの夜空に", "カブトムシ", "ボーイフレンド", "君はロックを聴かない", "裸の心"]
      assert_operator Music.count, '>', n_musics
      assert_not Music.any?{|i| !musics_orig_ids.include?(i.id) && !Harami1129.pluck(:ins_song).map(&:upcase).include?(i.title.upcase)}
      assert  Music.last.translations.exists?
      _weight_user_id_nil? Music.last.translations.last

      # HaramiVid
      assert_equal h1129.title[0..10], h1129.harami_vid.title[0..10]
      _weight_user_id_nil? HaramiVid.last.translations.last

      # HaramiVidMusicAssoc
      org_timings = Harami1129.where(song: 'Story').pluck(:link_time).uniq
      assert_equal 1, HaramiVidMusicAssoc.where(music: Music['Story'], timing: org_timings[0]).count
      assert_equal 1, HaramiVidMusicAssoc.where(music: Music['Story'], timing: org_timings[1]).count

    ensure
      Rails.cache.clear
    end
  end

  # If this was placed in helper.rb, the error message does not show even which file calls it!
  #
  # @param translation [Translation]
  # @return [Boolean] true if all are nil
  def _weight_user_id_nil?(translation)
    assert_nil  translation.create_user
    assert_nil  translation.update_user
    assert_equal Float::INFINITY, translation.weight
  end
end
