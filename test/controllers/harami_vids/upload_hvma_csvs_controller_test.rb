# coding: utf-8
require 'test_helper'

class Musics::UploadHvmaCsvsControllerTest < ActionDispatch::IntegrationTest
  # add this
  include Devise::Test::IntegrationHelpers

  # CSS for table-row in the associated Music table for HaramiVid
  CSS_MUSIC_TR = "section#harami_vids_show_musics table tbody tr"

  setup do
    @editor    = users(:user_editor)  # HaramiVid editor can manage
    @editor_ja = users(:user_editor_general_ja)  # General Editor cannot.

    @release_dates = [Date.new(2020, 2, 5), Date.new(2021, 3, 6)]
    _, _, @allmdls = prepare_h1129s1(release_dates: @release_dates)  # defined in test/test_helper.rb
    # The first one: @h1129_prms == {title: ["A video 0", "A video 1"], singer: ["OasIs", "OasYs"], song: ["Digsy's Dinner0", "Digsy's Dinner1"], ...}
    # The second one: @assc_prms
    # @allmdls contains keys, including: h1129s musics artists hvmas engages amps

    @hvids = @allmdls[:h1129s].map(&:harami_vid)
    @updated_timing = 17

    @music_rain = musics(:music_rain)
    @music_en_test_title = "This-is-Test-title-for-RAIN"
    @music_rain.translations.where(langcode: "en").destroy_all  # Deletes all EN Translations
    @iocsv = _create_csv_file  # Temporary CSV file
  end

  teardown do
    @iocsv.close
    @iocsv.unlink
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should fail to post create for General Editor" do
    sign_in @editor_ja
    _post2create  # POST to upload a CSV file
    assert_not (200...299).include?(response.code.to_i)  # maybe :redirect or 403 forbidden 
    sign_out @editor_ja
  end

#  test "invalid encoding file update" do
#    sign_in @editor
#
#    # Prepare a temporary file /test/fixtures/files/*.csv with a wrong character code
#    fixture_dir = Rails.root / 'test' / 'fixtures' / 'files'
#    Tempfile.open(['invalid_csv', '.csv'], fixture_dir, encoding: 'ascii-8bit'){|io|
#      io.write 0x8f.chr  # #<Encoding:ASCII-8BIT>
#      io.flush  # Essential (as newline has not been written?)
#      post musics_upload_music_csvs_url, params: { file: fixture_file_upload(File.basename(io.path), 'text/csv') }
#      assert_response :redirect
#      assert_redirected_to musics_url
#    }
#    sign_out @editor
#  end

  test "should create" do
    count_eq = 'Music.count*10000 + Artist.count*3000 + Engage.count*1000 + Translation.count*100 + HaramiVidMusicAssoc.count*10 + ArtistMusicPlay.count*1'

    sign_in @editor

    # get artists_url
    get harami_vid_url(@hvids.first)
    assert_response :success
    previous_str = _str_user_id_display_name(ModuleWhodunnit.whodunnit)  #  just to (potentially) suppress mal-functioning in setting this...

    assert_equal 1, (si=@hvids.first.musics.size), 'sanity check with the prepared data'
    assert_equal si, css_select(CSS_MUSIC_TR).size

    ## should not create when no file is specified"
    assert_no_difference(count_eq) do
      post harami_vid_upload_hvma_csv_url(harami_vid_id: @hvids.first.id),
           params: {upload_hvma_csv: { file: "" } }
        # => e.g., http://www.example.com/harami_vids/980190967/upload_hvma_csv?locale=en
      assert_response :redirect
      assert_redirected_to @hvids.first
    end
    follow_redirect!
    assert_includes css_select("div.alert").text, "No CSV file"
    flash.clear  # follow_redirect! AND this line are essential.  Othewise flash from this persists in the next POST!

    assert_equal @release_dates, @hvids.map(&:release_date), "sanity check..."
    assert_nil   @allmdls[:hvmas].first.timing, "sanity check..."

    iocsv = _create_csv_file
    ## sets @h1129_prms, @assc_prms, @allmdls, @hvids 

    assert_equal 1, @hvids.first.harami_vid_music_assocs.count, 'sanity check'
    assert          @hvids.first.artist_music_plays.exists?, 'sanity check'  # 6 AMPs (for 2 Musics by HARAMIchan, Oasis, AI) -- isn't it inconsistent with just 1 HaramiVidMusicAssocs...?
    hvma_exist = @hvids.first.harami_vid_music_assocs.first
    old_music  = hvma_exist.music
    old_timing = hvma_exist.timing
    amp_exist  = @hvids.first.artist_music_plays.where(artist_id: Artist.default(:HaramiVid), music_id: old_music).first

    ## Creation success
#debugger
    assert_difference(count_eq, 133) do
      _post2create  # POST to upload a CSV file
      assert_response :success
#print "DEBUG:27: \n"
#pp HaramiVidMusicAssoc.order(created_at: :desc)[0..2]
    end

    hvid = @hvids.first.reload
    assert_equal hvid.musics.size, css_select(CSS_MUSIC_TR).size
    assert_equal 4, hvid.musics.size  # sanity check - according to the sample (see far below; [雨, "Light, The", 乾杯])
    assert css_select(csstmp=(CSS_MUSIC_TR+"#"+dom_id(old_music))).present?, "Music table not containing the already-associated Music: Failed CSS = "+csstmp.inspect # + "\n"+css_select(CSS_MUSIC_TR)
    %i(music_rain music_kampai music_light).each do |ek|
      # Music table contains the newly associated Musics?
      mu = musics(ek)
      assert css_select(CSS_MUSIC_TR+"#"+dom_id(mu)).present?, "Music (#{ek.inspect} / #{mu.title_or_alt}) is not listed in Music table..."
    end

    hvma_exist.reload
    assert_equal old_music,               hvma_exist.music
    assert_equal @updated_timing,         hvma_exist.timing, "timing for the existing Music should be updated to #{hvma_exist.timing}, but..."  # =17  # 
    refute_equal old_timing,              hvma_exist.timing

    ## Second newest one is Music "The Light"
    hvma_light = HaramiVidMusicAssoc.order(created_at: :desc)[1]
    amp_light  =     ArtistMusicPlay.order(created_at: :desc)[1]
    assert_equal @hvids.first,            hvma_light.harami_vid
#debugger
    assert_equal musics(:music_light),    hvma_light.music
    assert_equal amp_light.music,         hvma_light.music
    assert_equal 142,                     hvma_light.timing  # 02:22
    assert_equal amp_exist.artist,     amp_light.artist
    assert_equal amp_exist.event_item, amp_light.event_item

    assert_equal @music_en_test_title, Translation.last.title  # New English title  (English title in CSV is imported for Music with JA title as is_orig)
    assert_equal @music_en_test_title, musics(:music_rain).title(langcode: :en)
    assert_includes css_select("div.alert.alert-info.notice").first.text, _music_note_csv(:music_kampai), "should be imported b/c that on DB has no Music#note, but..."
    refute_includes css_select("div.alert.alert-info.notice").first.text, _music_note_csv(:music_light), "should have no flash message after this is ignored b/c that on DB already contains this, too."
    assert_includes css_select("div.alert.alert-warning").first.text, _music_note_csv(:music_rain), "should be skipped b/c that on DB already has something different already."

#print "DEBUG:58: \n"
#puts css_select("div.alert")
##puts css_select("dd#item_event")
##puts css_select("section#harami_vids_show_musics")
    # Repeated "creation" success, doing nothing
    assert_no_difference(count_eq) do
      _post2create  # POST to upload a CSV file
      assert_response :success
    end
    sign_out @editor
  end

  private
    # debug helper to return String of User.
    def _str_user_id_display_name(user)
      user ? [@editor.id, @editor.email.sub(/@.+/,'')].inspect : "nil"
    end

    # Returns an Array for a row in CSV for Music to load to associate to HaramiVid
    #
    # Refer to {HaramiVid::MUSIC_CSV_FORMAT}
    #
    # @param timing [HaramiVidMusicAssoc, Integer, String, NilClass]
    # @param music    [Music, NilClass]
    # @param music_ja [String, NilClass] If String is specified, it is used. If music is specified and if this is nil, +music.id+ is used
    # @param music_en [String, NilClass] if nil and if music_ja is Music, pID is given to the music_ja column in the returned Array.
    # @param artist [Artist, String, NilClass] Artist or Artist#title
    # @return [Array] Single Array
    def _mk_csv_ary_row(timing, music_ja=nil, music_en=nil, music: nil, artist: nil, header: nil, hvma_note: nil, year: nil, music_note: nil)
      is_timing_hvma = timing.respond_to?(:timing)

      ## c.f., HaramiVid::MUSIC_CSV_FORMAT
      [
        header,
        (is_timing_hvma ? timing.timing : timing),  # timing (one of seconds and MM:DD and HH:MM:DD)
        (music_ja.present? ? music_ja : (music ? music.id : nil)), # Music JA title
         music_en,                                               # Music EN title
        (artist.respond_to?(:id) ? artist.id : artist),          # Artist title
        (hvma_note || (is_timing_hvma ? timing.note : nil)),     # HaramiVidMusicAssoc#note
        (year || (music ? music.year : nil)),                    # Music-year
        # (music ? music.genre.id : nil),                    # Music-genre
        # ((music && music.place) ? music.place.country.iso3166_a3_code : nil), # Music-place
        (music_note.present? ? music_note : (music ? music.note : nil)),
      ]
    end

    # @return [Array] Double Array
    def _mk_csv_ary2
      arret = []
      # Prepared Music by populating
      arret << _mk_csv_ary_row(
        @updated_timing,   # This differs from @allmdls[:hvmas][0],
        music: @allmdls[:musics][0],
        artist: @allmdls[:artists][0],
        header: "0. Populated from H1129",
        hvma_note: "HMVA-0-note"
      )

      # Preparation: Adjusting Fixture-related records
      mu_key = :music_light
      mu = musics(mu_key)
      mu.update!(note: mu.note.to_s + " ; " + _music_note_csv(mu_key))

      mu_key = :music_kampai
      mu = musics(mu_key)
      mu.update!(note: "")
      if !mu.artists.exists?
        art_tsuyoshi = Artist.create_basic!(title: "Tsuyoshi", langcode: "en", is_orig: true, sex: Sex[:male])
        mu.engages << Engage.new(artist: art_tsuyoshi, engage_how: engage_hows(:engage_how_singer_original))
        mu.artists.reset
        assert_equal "Tsuyoshi", mu.artists.first.title
      end

      # Fixture Music (titles are given -> succeeds & creates HaramiVidMusicAssoc)
      arret << _mk_csv_ary_row(
        "01:10",  # timing (one of seconds and MM:DD and HH:MM:DD)
        mu.title(langcode: :ja),
        mu.title(langcode: :en),
        music: mu,
        artist: mu.artists.first.title,
        header: "1. Manually added Kampai",
        hvma_note: "HMVA-1-note",
        music_note: _music_note_csv(mu_key),  # should be imported b/c that on DB has no Music#note
        year: 1901  # totally inconsistent (but music.year.nil? is true, so this is ignored but raises a warning only)
      )

      # Fixture Music (Year not specified, but ignored -> succeeds)
      mu_key = :music_light
      mu = musics(mu_key)
      arret << _mk_csv_ary_row(
        "02:22",  # timing (one of seconds and MM:DD and HH:MM:DD)
        nil,
        definite_article_stripped(mu.title(langcode: :en)),  # Test of title without a definite article; defined in ModuleCommon
        artist: artists(:artist_proclaimers).title,
        header: "2. Manually added The Light",
        hvma_note: "HMVA-2-note",
        music_note: _music_note_csv(mu_key),  # should be skipped b/c that on DB already contains this (see "preparation" above).
        year: nil
      )

      # Fixture Music (inconsistent Year -> fails)
      mu = musics(:music3)
      arret << _mk_csv_ary_row(
        "02:22",  # timing (one of seconds and MM:DD and HH:MM:DD)
        nil,
        definite_article_to_head(mu.title(langcode: :en)),  # defined in ModuleCommon
        artist: mu.artists.first.title,
        header: "3. Manually added Give Peace a Chance Music3 with the wrong year",
        hvma_note: "HMVA-3-note",
        year: mu.year + 5  # inconsistent, hence this fails
      )

      # Fixture Music (inconsistent Artist -> fails)
      mu = musics(:music1)
      arret << _mk_csv_ary_row(
        "03:33",  # timing (one of seconds and MM:DD and HH:MM:DD)
        nil,
        mu.title(langcode: :en),
        music: mu,
        artist: artists(:artist_spitz).title,
        header: "4. Manually added Music1 with a different Artist",
        hvma_note: "HMVA-4-note"
      )

      # Totally new Music with an existing Artist -> fails
      arret << _mk_csv_ary_row(
        "04:44",  # timing (one of seconds and MM:DD and HH:MM:DD)
        "ある新曲候補",
        "A certain candiate song",
        artist: artists(:artist_spitz).title,
        header: "5. Manually added new Music with an existing Artist",
        hvma_note: "HMVA-5-note"
      )

      # Existing Music with no English title to add a new English title -> succeeds
      mu_key = :music_rain
      mu = musics(mu_key)
      arret << _mk_csv_ary_row(
        "05:55",  # timing (one of seconds and MM:DD and HH:MM:DD)
        @music_rain.title(langcode: :ja),  # Test of JA title
        @music_en_test_title,  # New English title
        artist: @music_rain.artists.first.title,
        header: "6. Existing Music/Artist to add the first English title",
        hvma_note: "HMVA-6-note",
        music_note: _music_note_csv(mu_key)  # should be ignored b/c that on DB has something different already
      )
    end

    # @return [File] +ret.path+ would give the path.
    def _create_csv_file
      assert_equal @release_dates, @hvids.map(&:release_date), "sanity check..."

      ary2 = _mk_csv_ary2
      csv_string = CSV.generate do |csv|
        ary2.each do |row|
          csv << row
        end
      end
      
      csv_first_row_ary = csv_string.split(/\n/).first.split(",")
      assert_equal "0. Populated from H1129", ary2[0][0], "sanity check."
      assert_equal ary2[0][0], csv_first_row_ary[0], "sanity check."

      assert_equal @hvids[0], @allmdls[:hvmas][0].harami_vid, "hvmas: #{@allmdls[:hvmas].inspect}"
      assert_equal ary2[0][1], @updated_timing
      refute_equal ary2[0][1], @allmdls[:hvmas][0]  # the original one (blank) should be updated.
      assert_equal ary2[0][1], csv_first_row_ary[1].to_i

      assert_equal ary2[0][2], csv_first_row_ary[2].to_i, "sanity check: should be pID"

      ioret = Tempfile.open(["temporary_csv", ".csv"])
      ioret.puts csv_string
      ioret.rewind
      ioret
    end

    # Common routine to post
    def _post2create
      # Wrap the Tempfile in the expected UploadedFile format,
      # specifying the path, original name, and content type.
      uploaded_file = Rack::Test::UploadedFile.new(
        @iocsv.path,
        'text/csv',  # content type.
        original_filename: File.basename(@iocsv.path)
      )

      post harami_vid_upload_hvma_csv_url(harami_vid_id: @hvids.first.id),
           params: {upload_hvma_csv: { file: uploaded_file } }
      ## c.f., musics_upload_music_csvs_url, params: { file: fixture_file_upload('music_artists_3rows.csv', 'text/csv') }
    end

    # Common routine to post
    def _music_note_csv(key)
      "Music-Note-#{key}"
    end
end

