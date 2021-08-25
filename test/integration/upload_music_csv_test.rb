# coding: utf-8
require "test_helper"
require 'w3c_validators'

#Rails.application.config.middleware.insert_before Warden::Manager, ActionDispatch::Cookies
#Rails.application.config.middleware.insert_before Warden::Manager, ActionDispatch::Session::CookieStore

class Musics::UploadMusicCsvsIntegrationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @validator = W3CValidators::NuValidator.new
    @editor = roles(:general_ja_editor).users.first  # Editor can manage.
  end

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
  end

  test "can see the page after create" do
    post musics_upload_music_csvs_url
    assert_response :redirect
    assert_redirected_to new_user_session_path  # Devise sing_in route
    follow_redirect!
    assert_response :success

    sign_in @editor
    #log_in_as( users(:user_sysadmin) )
    #sign_in( users(:user_sysadmin) )

    post musics_upload_music_csvs_url, params: { file: fixture_file_upload('music_artists_3rows.csv', 'text/csv') }
    assert_response :success
    
#print "DEBUG:tbody:"; puts css_select('tbody')[0].to_s

    #### W3C HTML validation (Costly operation!) ##########################
    arerr = @validator.validate_text(response.body).errors
    assert_equal 0, arerr.size, "W3C-HTML-validation-Errors(Size=#{arerr.size}): ("+arerr.map(&:to_s).join(") (")+")"
    ## For debugging
    #@validator.validate_text(response.body).debug_messages.each do |key, value|
    #  puts "#{key}: #{value}"
    #end

    prefix = 'upload_music_csvs-'

    # Artist.unknown alrady existed.
    csssel = css_select("tr##{prefix}row-3 td.#{prefix}artist-new")
    assert_equal 1, csssel.size
    assert_equal 'Existing', csssel[0].text.strip

    # 1st row
    # 1:1/20[20th],糸,,Ito,Thread,1992,,,Miyuki Nakajima,ja,classi,compo,one of the longest hits of J-Pop
    csssel = css_select("tr##{prefix}row-1 td.#{prefix}no")
    assert_equal 1, csssel.size
    assert_equal "1", csssel[0].text.strip
    csssel = css_select("tr##{prefix}row-1 td.#{prefix}head")
    assert_equal "1:1/20[20th]", csssel[0].text.strip

    csssel = css_select("tr##{prefix}row-1 td.#{prefix}music-new")
    assert csssel[0].css('a')[0]['href'].include?('musics/') # <a href="/musics/986866317">New</a>
    assert_equal "New", csssel[0].text.strip
    csssel = css_select("tr##{prefix}row-1 td.#{prefix}artist-new")
    assert csssel[0].css('a')[0]['href'].include?('artists/') # <a href="/artists/1039544043">New</a>
    assert_equal "New", csssel[0].text.strip
    csssel = css_select("tr##{prefix}row-1 td.#{prefix}engage-new")
    assert csssel[0].css('a')[0]['href'].include?('engages/') # <a href="/engages/986866317">New</a>
    assert_equal "Engage", csssel[0].text.strip

    csssel = css_select("tr##{prefix}row-1 td.#{prefix}music_ja")
    assert_equal "糸",     csssel[0].text.strip
    csssel = css_select("tr##{prefix}row-1 td.#{prefix}romaji")
    assert_equal "Ito",    csssel[0].text.strip
    csssel = css_select("tr##{prefix}row-1 td.#{prefix}music_en")
    assert_equal "Thread", csssel[0].text.strip

    csssel = css_select("tr##{prefix}row-1 td.#{prefix}year")
    assert_equal "1992", csssel[0].text.strip
    csssel = css_select("tr##{prefix}row-1 td.#{prefix}country")
    assert_match(/日本/, csssel[0].text, 'actual is: '+csssel[0].text.strip.inspect)

    csssel = css_select("tr##{prefix}row-1 td.#{prefix}artist_ja")
    assert_equal "",    csssel[0].text.strip
    csssel = css_select("tr##{prefix}row-1 td.#{prefix}artist_en")
    assert_equal "Miyuki Nakajima", csssel[0].text.strip

    csssel = css_select("tr##{prefix}row-1 td.#{prefix}langcode")
    assert_equal "ja", csssel[0].text.strip
    csssel = css_select("tr##{prefix}row-1 td.#{prefix}genre")
    assert_match(/クラシック/, csssel[0].text.strip)
    csssel = css_select("tr##{prefix}row-1 td.#{prefix}how")
    assert_match(/作曲/, csssel[0].text.strip)
    csssel = css_select("tr##{prefix}row-1 td.#{prefix}memo")
    assert_equal "one of the longest hits of J-Pop", csssel[0].text.strip
  end
end

