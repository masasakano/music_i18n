# coding: utf-8

# == Schema Information
#
# Table name: harami1129s
#
#  id                                                    :bigint           not null, primary key
#  checked_at(Insertion validity manually confirmed at)  :datetime
#  id_remote(Row number of the table on the remote URI)  :bigint
#  ins_at                                                :datetime
#  ins_link_root                                         :string
#  ins_link_time                                         :integer
#  ins_release_date                                      :date
#  ins_singer                                            :string
#  ins_song                                              :string
#  ins_title                                             :string
#  last_downloaded_at(Last-checked/downloaded timestamp) :datetime
#  link_root                                             :string
#  link_time                                             :integer
#  not_music(TRUE if not for music but announcement etc) :boolean
#  note                                                  :text
#  orig_modified_at(Any downloaded column modified at)   :datetime
#  release_date                                          :date
#  singer                                                :string
#  song                                                  :string
#  title                                                 :string
#  created_at                                            :datetime         not null
#  updated_at                                            :datetime         not null
#  engage_id                                             :bigint
#  event_item_id                                         :bigint
#  harami_vid_id                                         :bigint
#
# Indexes
#
#  index_harami1129s_on_checked_at                        (checked_at)
#  index_harami1129s_on_engage_id                         (engage_id)
#  index_harami1129s_on_event_item_id                     (event_item_id)
#  index_harami1129s_on_harami_vid_id                     (harami_vid_id)
#  index_harami1129s_on_id_remote                         (id_remote)
#  index_harami1129s_on_id_remote_and_last_downloaded_at  (id_remote,last_downloaded_at) UNIQUE
#  index_harami1129s_on_ins_link_root_and_ins_link_time   (ins_link_root,ins_link_time) UNIQUE
#  index_harami1129s_on_ins_singer                        (ins_singer)
#  index_harami1129s_on_ins_song                          (ins_song)
#  index_harami1129s_on_link_root_and_link_time           (link_root,link_time) UNIQUE
#  index_harami1129s_on_orig_modified_at                  (orig_modified_at)
#  index_harami1129s_on_singer                            (singer)
#  index_harami1129s_on_song                              (song)
#
# Foreign Keys
#
#  fk_rails_...  (engage_id => engages.id) ON DELETE => restrict
#  fk_rails_...  (event_item_id => event_items.id)
#  fk_rails_...  (harami_vid_id => harami_vids.id)
#
require 'test_helper'

class Harami1129Test < ActiveSupport::TestCase
  test "constraints" do
    assert_raises(ActiveRecord::RecordInvalid){ Harami1129.create! }  # Custom validation: Null entry is invalid.
    ha = harami1129s(:harami1129one)
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique) {
      Harami1129.create!(link_root: ha.link_root, link_time: ha.link_time) }
    # "Link root has already been taken".
    # However, it does not raise, "Ins link root has already been taken",
    # which is correct because they are both nulls.
  end

  test "new constraints re id_remote etc" do
    ha = harami1129s(:harami1129one)
    h2 = ha.dup
    assert_raises(ActiveRecord::RecordInvalid){ p h2.save! }  # Custom validation: Null entry is invalid.
    h2.link_time = 9876
    h2.id_remote = 0
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid){
      h2.save! }  # check
      # DRb::DRbRemoteError: PG::CheckViolation: ERROR:  new row for relation "harami1129s" violates check constraint "check_positive_id_remote_on_harami1129s"
      # "Validation failed: Id remote must be greater than 0"
    h2.id_remote = 101
    h2.last_downloaded_at = Time.now
    assert_nothing_raised{
      h2.save! }

    h3 = h2.dup
    h3.link_time = 9555
    #assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique) {
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique) {
      p h3.save! }
      # DRb::DRbRemoteError: PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint "index_harami1129s_on_id_remote_and_last_downloaded_at"
      # "Validation failed: Id remote has already been taken"
    h3.id_remote = nil
    assert_raises(ActiveRecord::RecordInvalid){  # Rails level only error
      p h3.save! } # Validation failed: Id remote is not a number
    h3.id_remote = 102
    h3.last_downloaded_at = nil
    assert_raises(ActiveRecord::RecordInvalid){  # Rails level only error
      p h3.save! } # Validation failed: Last downloaded at can't be blank

    h3.last_downloaded_at = h2.last_downloaded_at - 500
    assert_nothing_raised{  # Success.
      h3.save! }

    ht = harami1129s(:harami1129two)
    htid = ht.id
    htupdated_at = ht.updated_at
    htbak = ht.dup
    assert_equal    ht.orig_modified_at, ht.last_downloaded_at # as in Fixture
    h4 = Harami1129.insert_a_downloaded!(link_time: ht.link_time, link_root: ht.link_root, note: ht.note)
    assert_operator ht.last_downloaded_at, :<, h4.last_downloaded_at
    assert_operator h4.orig_modified_at,   :<, h4.last_downloaded_at # only last_downloaded_at updated
    assert_equal    ht.note, h4.note
    h5 = Harami1129.insert_a_downloaded!(link_time: ht.link_time, link_root: ht.link_root, note: 'New5')
    assert_operator h4.last_downloaded_at, :<, h5.last_downloaded_at
    assert_equal    h5.orig_modified_at,       h5.last_downloaded_at # orig_modified_at updated, too
    assert_equal    h5.updated_at,             h5.last_downloaded_at
    assert_equal    'New5',  h5.note
    h6 = Harami1129.insert_a_downloaded!(link_time: ht.link_time, link_root: 'new-6', id_remote: 66, note: 'New6')
    assert_not_equal h5.id,  h6.id
    assert_equal    'New6',  h6.note

    ## Error: Existing record
    assert_raises(ActiveRecord::RecordInvalid) { # "Validation failed: Id remote must be greater than 0"
      p Harami1129.insert_a_downloaded!(link_time: ht.link_time, link_root: 'new-6', id_remote: -3) }

    ## Error: New record
    assert_raises(ActiveRecord::RecordInvalid) { # "Validation failed: Id remote has already been taken" (unique: [:id_remote, :last_downloaded_at]
      p Harami1129.insert_a_downloaded!(link_time: ht.link_time, link_root: 'naiyo', id_remote: 66, last_downloaded_at: h6.last_downloaded_at) }
    assert_raises(NoMethodError, ActiveModel::UnknownAttributeError) { # the latter if update! was used in ModuleCommon#update_or_create_by_with_notouch!
      p Harami1129.insert_a_downloaded!(link_time: ht.link_time, link_root: 'naiyo', id_remote: 67, naiyo: nil) }
  end

  test "copy to ins_ columns" do
    h1 = harami1129s(:harami1129one)
    h2 = harami1129s(:harami1129two)
    assert_equal :ins_link_root,  h1.ins_column_key(:link_root)
    assert_equal 'Harami1129One', h1.note

    h1n = 'Harami1129One'
    assert_equal h1n+' Abc', h1.send(:appended_note, h1.note, 'Abc')
    assert_equal 'Harami1129One', h1.note
    assert_equal 'Abc', h1.send(:appended_note, nil, 'Abc')
    assert_equal 'Abc', h1.send(:appended_note, '',  'Abc')
    assert_equal h1n,   h1.send(:appended_note, h1.note, 'One')

    assert_not h1.harami_song_is_music?('happiest birthday to you ')
    assert h1.harami_song_is_music?('happy birthday to you ')
    assert h1.harami_song_is_music?(' Fanfare')
    assert h1.harami_song_is_music?(' ハラミ体操（バラードバージョン） ')

    dayy = Date.yesterday
    dayt = Date.today
    row = Harami1129.new(singer: ' ハラミちゃん',
                         song: " ハラミ体操\u3000 （バラードバージョン） ",  # \u3000: IDEOGRAPHIC SPACE (Zenkaku space)
                         title: 'ハラミtest', link_root: 'testlink1',
                         release_date: dayt, ins_release_date: dayy,
                         last_downloaded_at: Time.now, id_remote: 88,)
    row.note = 'Abc.'
    hs_orig = row.send(:prepare_raw_hash_for_fill_ins_column)
    assert_not                   hs_orig.key? :ins_release_date
    assert_equal 'youtu.be/testlink1',    hs_orig[:ins_link_root], "hs_orig=#{hs_orig.inspect}"
    assert_equal 'ハラミちゃん', hs_orig[:ins_singer]

    upd_data = row.adjust_update_hash(**hs_orig)

    assert_not upd_data.key? :ins_release_date
    assert_equal 'youtu.be/testlink1',    upd_data[:ins_link_root]
    assert_equal 'ハラミtest',   upd_data[:ins_title]
    assert_equal 'ハラミちゃん', upd_data[:ins_singer]
    assert_equal 'ハラミ体操',   upd_data[:ins_song]
    assert_equal 'Abc. (バラードバージョン).', upd_data[:note]
    assert_equal false, upd_data[:not_music]

    # Actual DB "update!" (or actually "create!" in this case).
    ret = row.fill_ins_column!
    assert ret
    assert_equal dayt,           row.release_date
    assert_equal dayy,           row.ins_release_date
    assert_equal 'ハラミちゃん', row.ins_singer
    assert_equal 'youtu.be/testlink1',    row.ins_link_root
    assert_equal 'ハラミtest',   row.ins_title
    assert_equal 'ハラミ体操',   row.ins_song
    assert_equal 'Abc. (バラードバージョン).', row.note
    assert_not   row.not_music

    # 2nd time - no "significant" update
    ret = row.fill_ins_column!
    assert_not row.updated_at_previously_changed?
    assert_not ret  # because ins_at > downloaded_at (note otherwise ins_link_time would be attempted to be updated with link_time=nil)

    # 3nd time - no update
    row.ins_link_time = 77
    row.save!
    assert     row.updated_at_previously_changed?
    assert     row.ins_link_time_previously_changed?
    assert_equal 77, row.ins_link_time
    ret = row.fill_ins_column!
    assert_equal 77, row.ins_link_time
    assert_not ret  # Nothing is even attempted to be updated.
    assert_not row.updated_at_previously_changed?
  end

  test "adjust_update_hash with articles" do
    dayy = Date.yesterday
    dayt = Date.today
    row = Harami1129.new(singer: ' the Beatles ',
                         song: "\n Ｌ’Ｙesterday\n ",
                         title: 'Beat-test', link_root: 'testlink1',
                         release_date: dayt, ins_release_date: dayy,
                         last_downloaded_at: Time.now, id_remote: 43,)
    row.note = 'Abc.'
    hs_orig = row.send(:prepare_raw_hash_for_fill_ins_column)

    upd_data = row.adjust_update_hash(**hs_orig)

    assert_equal 'youtu.be/testlink1', upd_data[:ins_link_root]
    assert_equal 'Beat-test',     upd_data[:ins_title]
    assert_equal 'Beatles, the',  upd_data[:ins_singer]
    assert_equal "Yesterday, L'", upd_data[:ins_song]
    assert_nil                    upd_data[:note]  # No "additional" change to pass to update!, hence nil
    assert_equal false, upd_data[:not_music]
  end

  test "populate_ins_cols" do
    str_equation = 'HaramiVid.count*10000 + Artist.count*1000 + Music.count*100 + Engage.count*10'
    str_equation2= 'EventItem.count*1000 + HaramiVidEventItemAssoc.count*100 + HaramiVidMusicAssoc.count*10 + ArtistMusicPlay.count'

    ## New one (ins_* are nil)
    h1129_ewf = harami1129s(:harami1129_ewf)
    h1129_ew2 = h1129_ewf.dup
    h1129_ew3 = h1129_ewf.dup
    assert_nil h1129_ew2.id, 'sanity check'

    assert_no_difference(str_equation2) do
      assert_difference(str_equation, 0) do
        h1129_ewf.populate_ins_cols(updates: Harami1129::ALL_INS_COLS)
      end
    end

    h1129_ewf.fill_ins_column!
    assert_difference(str_equation2, 1111) do
      assert_difference(str_equation, 11110) do
        h1129_ewf.populate_ins_cols(updates: Harami1129::ALL_INS_COLS)
      end
    end
    assert  h1129_ewf.ins_link_root
    assert_match(%r@youtu\.be/@, h1129_ewf.ins_link_root)
    assert_equal h1129_ewf.ins_song,   h1129_ewf.engage.music.title
    assert_equal h1129_ewf.ins_singer, h1129_ewf.engage.artist.title
    assert_equal h1129_ewf.ins_song,   h1129_ewf.harami_vid.musics.first.title
    assert_equal h1129_ewf.ins_singer, h1129_ewf.harami_vid.artists.first.title
    assert_equal h1129_ewf.link_time, h1129_ewf.harami_vid.harami_vid_music_assocs.first.timing  # 3250
    assert  h1129_ewf.event_item
    evit_orig = h1129_ewf.event_item
    assert_equal 1, evit_orig.harami_vid_event_item_assocs.size

    ## timing update
    h1129_ewf.update!(ins_link_time: 8888, last_downloaded_at: Time.now)
    h1129_ewf.populate_ins_cols(updates: [:ins_link_time])
    assert_equal    1, h1129_ewf.harami_vid.harami_vid_music_assocs.count
    assert_equal 8888, h1129_ewf.harami_vid.harami_vid_music_assocs.first.timing

    ## create new Harami1129 for a new Music and populate it
    #  The same Youtube URI but timing, hence no change in EventItem but HaramiVidMusicAssoc.count and ArtistMusicPlay (HARAMIchan playing)
    h1129_ew2.song = "AliceWonder"  # <=> "Boogie Wonderland"
    h1129_ew2.release_date = h1129_ew2.release_date + 1
    h1129_ew2.title = h1129_ew2.title+"2"
    h1129_ew2.link_time = h1129_ew2.link_time + 250  # <=> 3250
    h1129_ew2.note = h1129_ew2.note+"2"
    h1129_ew2.id_remote = h1129_ew2.id_remote + 10   # <=> 20
    h1129_ew2.save!

    assert_no_difference(str_equation2) do
      assert_difference(str_equation, 0) do
        h1129_ew2.populate_ins_cols(updates: Harami1129::ALL_INS_COLS)
      end
    end

    h1129_ew2.fill_ins_column!
    assert_difference(str_equation2, 11) do    # Increase in HaramiVidMusicAssoc.count and ArtistMusicPlay
      assert_difference(str_equation, 110) do  # Increase in Music and Engage
        h1129_ew2.populate_ins_cols(updates: Harami1129::ALL_INS_COLS)
      end
    end
    h1129_ew2.reload
    assert h1129_ew2.ins_link_root
    assert_equal h1129_ew2.ins_song,   h1129_ew2.engage.music.title
    assert_equal h1129_ew2.ins_singer, h1129_ewf.engage.artist.title  # same Artist as the original

     # checking associated HaramiVid
    hvid = h1129_ew2.harami_vid
    assert_equal 2, hvid.musics.size
    assert_includes hvid.musics.map(&:title), h1129_ew2.ins_song
    assert_equal h1129_ew2.link_time, hvid.harami_vid_music_assocs.last.timing  # 3500
    assert_equal 1, hvid.harami_vid_event_item_assocs.size

     # checking associated EventItem, ArtistMusicPlay
    assert_equal evit_orig,            h1129_ew2.event_item, "EventItem should be identical to the previous H1129"
    assert_equal evit_orig.updated_at, h1129_ew2.event_item.updated_at
    evit = h1129_ew2.event_item
    assert_equal 2, evit.artist_music_plays.count
    assert_equal 1,                             evit.artist_music_plays.pluck(:artist_id).flatten.uniq.size  # HARAMIchan only
    assert_equal Artist.default(:HaramiVid).id, evit.artist_music_plays.pluck(:artist_id).flatten.first, "ArtistMusicPlay-Artist=#{evit.artists.first.title.inspect}"
    assert_equal 2, evit.musics.distinct.size
    assert_includes evit.musics.map(&:title), h1129_ewf.ins_song
    assert_includes evit.musics.map(&:title), h1129_ew2.ins_song
    assert_equal 1, evit.harami_vid_event_item_assocs.size
    assert_equal 1, hvid.harami_vid_event_item_assocs.size

    ## create new Harami1129 for the same Music/Artist as the original but in a different Youtube link and populate it
    #   hence no change in Engage but a new EventItem, HaramiVidEventItemAssoc, HaramiVidMusicAssoc.count, ArtistMusicPlay (HARAMIchan playing)
    h1129_ew3.release_date = h1129_ew3.release_date + 2
    h1129_ew3.link_root = h1129_ew3.link_root+"3"
    h1129_ew3.title = h1129_ew3.title+"3"
    h1129_ew3.note = h1129_ew3.note+"3"
    h1129_ew3.id_remote = h1129_ew3.id_remote + 20   # <=> 20
    h1129_ew3.save!

    assert_no_difference(str_equation2) do
      assert_difference(str_equation, 0) do
        h1129_ew3.populate_ins_cols(updates: Harami1129::ALL_INS_COLS)
      end
    end

    h1129_ew3.fill_ins_column!
    assert_difference(str_equation2, 1111) do    # Increase in HaramiVidMusicAssoc.count and ArtistMusicPlay
      assert_difference(str_equation, 10000) do  # Increase in Music and Engage
        h1129_ew3.populate_ins_cols(updates: Harami1129::ALL_INS_COLS)
      end
    end

    h1129_ew3.reload
    assert h1129_ew3.ins_link_root
    assert_equal h1129_ew3.ins_song,   h1129_ewf.engage.music.title   # same Music as the original
    assert_equal h1129_ew3.ins_singer, h1129_ewf.engage.artist.title  # same Artist as the original

     # checking associated HaramiVid
    hvid = h1129_ew3.harami_vid
    assert_equal 1, hvid.musics.size
    assert_includes hvid.musics.map(&:title), h1129_ew3.ins_song
    assert_equal h1129_ew3.link_time, hvid.harami_vid_music_assocs.first.timing  # 3250
    assert_equal 1, hvid.harami_vid_event_item_assocs.size

     # checking associated EventItem, ArtistMusicPlay
    refute_equal evit_orig,            h1129_ew3.event_item, "EventItem should differ from the previous H1129"
    evit = h1129_ew3.event_item
    assert_equal 1, evit.artist_music_plays.count
    #assert_equal 1,                             evit.artist_music_plays.pluck(:artist_id).flatten.uniq.size  # HARAMIchan only
    assert_equal Artist.default(:HaramiVid).id, evit.artist_music_plays.pluck(:artist_id).flatten.first, "ArtistMusicPlay-Artist=#{evit.artists.first.title.inspect}"
    assert_equal 1, evit.musics.distinct.size
    assert_includes evit.musics.map(&:title), h1129_ewf.ins_song
    assert_includes evit.musics.map(&:title), h1129_ew3.ins_song
    assert_equal 1, evit.harami_vid_event_item_assocs.size
    assert_equal 1, hvid.harami_vid_event_item_assocs.size
  end # test "populate_ins_cols" do

  test "insert_populate" do
    str_equation = 'HaramiVid.count*10000 + Artist.count*1000 + Music.count*100 + Engage.count*10'
    str_eq2      = 'HaramiVidEventItemAssoc.count*1000+Event.count*100 + EventItem.count*10 + ArtistMusicPlay.count'

    ## New one (ins_* are nil)
    h1129_ewf = harami1129s(:harami1129_ewf)
    assert_nil h1129_ewf.harami_vid

    ## before internal_insertion
    pstat = h1129_ewf.populate_status(use_cache: true)
    assert_equal :no_insert, pstat.status(:ins_title)
    assert_equal "\u274c",   pstat.marker(:ins_title)
    assert_equal h1129_ewf.title.gsub(/！/, '!'),  pstat.ins_to_be(:ins_title)
    assert_nil h1129_ewf.reload.harami_vid

    ## run internal_insertion and populate
    assert_difference(str_equation, 11110) do
      h1129_ewf.insert_populate
    end
    hvid = h1129_ewf.reload.harami_vid
    assert_operator h1129_ewf.created_at, :<, hvid.created_at, "sanity check. HaramiVid is newly created from h1129_ewf."

    assert_equal h1129_ewf.song,   h1129_ewf.ins_song
    assert_equal h1129_ewf.singer, h1129_ewf.ins_singer
    assert_equal h1129_ewf.song,   h1129_ewf.engage.music.title
    assert_equal h1129_ewf.singer, h1129_ewf.engage.artist.title
    assert_equal h1129_ewf.song,      h1129_ewf.harami_vid.musics.first.title
    assert_equal h1129_ewf.singer,    h1129_ewf.harami_vid.artists.first.title
    assert_equal h1129_ewf.link_time, h1129_ewf.harami_vid.harami_vid_music_assocs.first.timing  # 3250
    assert_equal h1129_ewf.last_downloaded_at, h1129_ewf.orig_modified_at
    assert_operator h1129_ewf.orig_modified_at, '<', h1129_ewf.ins_at

    assert h1129_ewf.event_item
    assert h1129_ewf.harami_vid.event_items.exists?, "h1129=#{h1129_ewf.inspect}\n hv=#{h1129_ewf.harami_vid.inspect}"
    assert h1129_ewf.harami_vid.event_items.include?(h1129_ewf.event_item)
    assert_equal h1129_ewf.harami_vid.musics.first,               h1129_ewf.event_item.musics.first
    assert_equal Artist.default(:harami1129),                     h1129_ewf.event_item.artists.first

    ## populate_status, where the existing cache is automtically discarded due to a change in updated_at
    pstat = h1129_ewf.populate_status
    exp = :consistent
    act = pstat.status(:ins_title)
    assert_equal exp, act, "populate_status: #{act.inspect} should be #{exp.inspect}"
    assert_equal [exp], pstat.status_cols.values.uniq  # All ins_* should be :consistent
    assert_equal h1129_ewf.ins_title,              pstat.ins_to_be(:ins_title)
    assert_equal h1129_ewf.title.gsub(/！/, '!'),  pstat.ins_to_be(:ins_title)

    # No change for repeated actions
    assert_difference(str_equation, 0) do
      assert_difference(str_eq2, 0) do
        h1129_ewf.insert_populate
      end
    end
    assert_not h1129_ewf.saved_changes?
    assert_equal h1129_ewf.ins_song,   h1129_ewf.engage.music.title

    # modified last_downloaded_at, hence orig_modified_at and maybe checked_at
    #
    # NOTE: These test the scenario (5) in the comment in harami1129.rb,
    # implemented in update_orig_modified_at_checked_at()
    #
    # (5-1) insignificant update in downloaded columns: orig_modified_at is updated, checked_at remains nil.
    h1129_ewf.reload
    assert_not       h1129_ewf.ins_singer.blank?  # == "Earth, Wind & Fire"
    upat = h1129_ewf.updated_at
    engage_old    = h1129_ewf.engage
    h1129_ewf_old = h1129_ewf.dup
    h1129_ewf.update!(singer: h1129_ewf.singer.gsub(/a/, 'A'), last_downloaded_at: Time.now)
    h1129_ewf.insert_populate
    assert_equal     engage_old, h1129_ewf.engage
    assert_equal     h1129_ewf.last_downloaded_at,   h1129_ewf.orig_modified_at
    assert_not_equal h1129_ewf_old.orig_modified_at, h1129_ewf.orig_modified_at
    assert_nil       h1129_ewf.checked_at
    assert_equal     "EArth, Wind & Fire", h1129_ewf.singer
    assert_equal     "Earth, Wind & Fire", h1129_ewf.ins_singer
    assert_not_equal upat, h1129_ewf.updated_at
    upat = h1129_ewf.updated_at

    ## populate_status, where the existing cache is automtically discarded due to a change in updated_at
    pstat = h1129_ewf.populate_status
    assert_equal     "Earth, Wind & Fire", h1129_ewf.ins_singer
    exp = :consistent
    act = pstat.status(:ins_title)
    assert_equal exp, act, "populate_status: #{act.inspect} should be #{exp.inspect}"
    assert_equal :org_inconsistent, pstat.status(:ins_singer)
    assert_equal [exp, :org_inconsistent], pstat.status_cols.values.uniq  # All ins_* should be :consistent
    assert_equal     h1129_ewf.singer.upcase, h1129_ewf.ins_singer.upcase
    assert_not_equal h1129_ewf.singer,     h1129_ewf.ins_singer
    assert_equal     h1129_ewf.singer,     pstat.ins_to_be(:ins_singer)
    assert_not_equal h1129_ewf.ins_singer, pstat.ins_to_be(:ins_singer)

    # (5-2) insignificant update in downloaded columns: checked_at and orig_modified_at are updated.
    h1129_ewf.update!(checked_at: Time.now)
    h1129_ewf_old = h1129_ewf.dup
    h1129_ewf.update!(singer: h1129_ewf.singer.gsub(/r/, 'R'), last_downloaded_at: Time.now)
    h1129_ewf.insert_populate
    assert_equal     engage_old, h1129_ewf.engage
    assert_equal     h1129_ewf.last_downloaded_at,   h1129_ewf.orig_modified_at
    assert_not_equal h1129_ewf_old.orig_modified_at, h1129_ewf.orig_modified_at
    assert_equal     h1129_ewf.checked_at,           h1129_ewf.orig_modified_at
    assert_equal     "EARth, Wind & FiRe", h1129_ewf.singer
    assert_equal     "Earth, Wind & Fire", h1129_ewf.ins_singer
    assert_not_equal upat, h1129_ewf.updated_at
    upat = h1129_ewf.updated_at

    ## populate_status, where the existing cache is automtically discarded due to a change in updated_at
    pstat = h1129_ewf.populate_status
    exp = :checked
    act = pstat.status(:ins_title)
    assert_equal exp, act, "populate_status: #{act.inspect} should be #{exp.inspect}"
    assert_equal exp, pstat.status(:ins_singer)
    assert_equal [exp], pstat.status_cols.values.uniq  # All ins_* should be :consistent
    assert_equal     h1129_ewf.singer.upcase, h1129_ewf.ins_singer.upcase
    assert_not_equal h1129_ewf.singer,     h1129_ewf.ins_singer # Because of the times, no insert is required.
    assert_equal     h1129_ewf.singer,     pstat.ins_to_be(:ins_singer)
    assert_not_equal h1129_ewf.ins_singer, pstat.ins_to_be(:ins_singer)

    # (5-3) no update in downloaded columns: checked_at and orig_modified_at unchange.
    h1129_ewf.update!(singer: h1129_ewf.singer.gsub(/r/, 'R'), last_downloaded_at: Time.now)
    h1129_ewf.insert_populate
    assert_not_equal h1129_ewf.last_downloaded_at,   h1129_ewf.orig_modified_at
    assert_equal     h1129_ewf.checked_at,           h1129_ewf.orig_modified_at
    assert_not_equal upat, h1129_ewf.updated_at
    upat = h1129_ewf.updated_at

    # (5-4) orig_modified_at changed, hence newer than checked_at and orig_modified_at unchange.
    h1129_ewf = h1129_ewf.class.insert_a_downloaded!(orig_modified_at: Time.now, link_time: h1129_ewf.link_time, link_root: h1129_ewf.link_root)

    ## populate_status, where the existing cache is automtically discarded due to a change in updated_at
    pstat = h1129_ewf.populate_status
    exp = :consistent
    act = pstat.status(:ins_title)
    assert_equal exp, act, "populate_status: #{act.inspect} should be #{exp.inspect}"
    assert_equal :org_inconsistent, pstat.status(:ins_singer)

    ## populate_status; if the destination DB has been modified by an editor.
    singer = pstat.dest_current(:ins_singer)
    artist = h1129_ewf.engage.artist
    assert_equal 1, artist.translations.count
    tra = artist.translations.first  # Only 1 Translation for artist in this case (in Fixture).
    tra.update!(title: 'tekito4')
    assert_equal 'tekito4', artist.title

    pstat = h1129_ewf.populate_status(use_cache: true)  # Using cache (as Default; here, the original DB table has not been updated, hence the cache would be used in Default.)
    assert_equal :org_inconsistent, pstat.status(:ins_singer)
    assert_not_equal 'tekito4', singer
    assert_equal     singer, pstat.dest_current(:ins_singer)
    assert_not_equal 'tekito4', pstat.ins_to_be(:ins_singer)

    pstat = h1129_ewf.populate_status(use_cache: false) # NOT using cache, meaning Status updated
    assert_equal :org_inconsistent, pstat.status(:ins_singer)
    assert_not_equal 'tekito4', singer
    assert_not_equal singer, pstat.dest_current(:ins_singer) # changed due to use_cache: false
    assert_equal     'tekito4', pstat.dest_current(:ins_singer) # changed
    assert_not_equal 'tekito4', pstat.ins_to_be(:ins_singer)    # Same (as the orig unchanged)
    assert_equal h1129_ewf.singer, pstat.ins_to_be(:ins_singer) # Same

    # (5-5) Destination became the same as orig, being different from ins_singer
    artist = h1129_ewf.engage.artist
    assert_equal 1, artist.translations.count
    tra = artist.translations.first  # Only 1 Translation for artist in this case (in Fixture).
    tra.update!(title: h1129_ewf.singer)
    assert_equal h1129_ewf.singer, artist.title

    pstat = h1129_ewf.populate_status(use_cache: false) # NOT using cache
    assert_equal :ins_inconsistent, pstat.status(:ins_singer)  # Only org=dest, but not ins_*
    assert_equal     h1129_ewf.singer, pstat.dest_current(:ins_singer)
    assert_equal     h1129_ewf.singer, pstat.ins_to_be(:ins_singer)
  end

  test "populate_ins_cols_story when populate has not been run yet" do
    str_equation = 'HaramiVid.count*10000 + Artist.count*1000 + Music.count*100 + Engage.count*10'
    e_story = engages(:engage_ai_story)
    # m_story = musics(:music_story)
    hvid_fix = harami_vids(:harami_vid1)

    ## New one (ins_* are nil)
    art1 = 'The NewArtist'
    tit1 = hvid_fix.title
    mu1  = e_story.music
    mu1tit = mu1.title
    h1129 = Harami1129.insert_a_downloaded!(title: tit1, orig_modified_at: Time.now, link_time: 123, link_root: 'abcdef', song: mu1tit, singer: art1, release_date: Time.new(0), id_remote: 999)
    assert_equal     tit1, h1129.title
    assert_equal     mu1tit, h1129.song
    assert_equal     art1,   h1129.singer
    h1129.fill_ins_column!
    assert_equal     tit1,   h1129.ins_title
    assert_equal     mu1tit, h1129.ins_song
    assert_equal     'NewArtist, The', h1129.ins_singer

    # This is a new Harami1129 and `pupulate` has not been performed.
    # Hence no destination should be defined.
    pstat = h1129.populate_status
    assert   pstat.status_cols.find_all{|k,v| v == :consistent}.to_h.keys.empty?
    assert_equal [:org_inconsistent], pstat.status_cols.values.uniq  # All ins_* should be :consistent
    assert_nil     pstat.destination(:ins_singer)
    assert_nil     pstat.destination(:ins_song)
    assert_nil     pstat.destination(:ins_title)
    assert_nil     pstat.destination(:ins_link_time)
    assert_nil     pstat.destination(:release_date)
    assert_equal h1129.ins_singer, pstat.dest_to_be(:ins_singer)
    assert_equal mu1tit,  pstat.dest_to_be(:ins_song)
  end

  # Sanity check after 1 entry is added to Harmai1129 fixture to confirm it can be populated.
  # To populate, run: harami1129s(:harami1129_zenzenzense1).insert_populate
  test "insert_populate_zenzenzense" do
    str_equation = 'HaramiVid.count*10000 + Artist.count*1000 + Music.count*100 + Engage.count*10'
    str_eq2      = 'HaramiVidEventItemAssoc.count*1000+Event.count*100 + EventItem.count*10 + ArtistMusicPlay.count'

    ## New one (ins_* are nil)
    h1129_zen = harami1129s(:harami1129_zenzenzense1)
    assert_nil h1129_zen.harami_vid

    ## before internal_insertion
    pstat = h1129_zen.populate_status(use_cache: true)
    assert_equal :no_insert, pstat.status(:ins_title)
    assert_equal "\u274c",   pstat.marker(:ins_title)
    assert_equal h1129_zen.title.gsub(/！/, '!'),  pstat.ins_to_be(:ins_title)
    assert_nil h1129_zen.reload.harami_vid

    ## run internal_insertion and populate
    assert_difference(str_equation, 11110) do
      assert_difference(str_eq2, 1111) do
        h1129_zen.insert_populate
      end
    end
    hvid = h1129_zen.reload.harami_vid
    assert_operator h1129_zen.created_at, :<, hvid.created_at, "sanity check. HaramiVid is newly created from h1129_zen."

    assert_equal h1129_zen.song,   h1129_zen.ins_song
    assert_equal h1129_zen.singer, h1129_zen.ins_singer
    assert_equal h1129_zen.song,   h1129_zen.engage.music.title
    assert_equal h1129_zen.singer, h1129_zen.engage.artist.title
    assert_equal h1129_zen.song,      h1129_zen.harami_vid.musics.first.title
    assert_equal h1129_zen.singer,    h1129_zen.harami_vid.artists.first.title
    #assert_equal h1129_zen.link_time, h1129_zen.harami_vid.harami_vid_music_assocs.first.timing  # 3250
    assert_equal h1129_zen.last_downloaded_at, h1129_zen.orig_modified_at
    assert_operator h1129_zen.orig_modified_at, '<', h1129_zen.ins_at

    assert h1129_zen.event_item
    assert h1129_zen.harami_vid.event_items.exists?, "h1129=#{h1129_zen.inspect}\n hv=#{h1129_zen.harami_vid.inspect}"
    assert h1129_zen.harami_vid.event_items.include?(h1129_zen.event_item)
    assert_equal h1129_zen.harami_vid.musics.first,               h1129_zen.event_item.musics.first
    assert_equal Artist.default(:harami1129),                     h1129_zen.event_item.artists.first

    ## populate_status, where the existing cache is automtically discarded due to a change in updated_at
    pstat = h1129_zen.populate_status
    exp = :consistent
    act = pstat.status(:ins_title)
    assert_equal exp, act, "populate_status: #{act.inspect} should be #{exp.inspect}"
    assert_equal [exp], pstat.status_cols.values.uniq  # All ins_* should be :consistent
    assert_equal h1129_zen.ins_title,              pstat.ins_to_be(:ins_title)
    #assert_equal h1129_zen.title.gsub(/！/, '!'),  pstat.ins_to_be(:ins_title)
  end

  test "create_manual" do
    ms = __method__.to_s
    assert_raises(RuntimeError){
      Harami1129.create_manual()}
    assert_raises(RuntimeError){
      Harami1129.create_manual(title: ms, singer: ms, song: ms, release_date: Date.today)}  # making sure they never happen to exist.

    hscorrect = {title: ms, singer: ms, song: ms, release_date: Date.today, link_root: "youtu.be/"+ms, link_time: 777, id_remote: _get_unique_id_remote, last_downloaded_at: DateTime.now}  # defined in test_helper.rb
    assert_equal Integer, Harami1129.create_manual( **hscorrect).id.class
    assert_raises(ActiveRecord::RecordInvalid, "Should fail in unique validation but..."){
                          Harami1129.create_manual!(**hscorrect)}
    assert_nil            Harami1129.create_manual( **hscorrect).id
  end

  test "insert_populate_true_dryrun" do
    ms = __method__.to_s
    hscorrect = {title: ms+"t", singer: ms+"a", song: ms+"m", release_date: Date.today, link_root: "youtu.be/"+ms, link_time: 778, id_remote: _get_unique_id_remote, last_downloaded_at: DateTime.now}  # defined in test_helper.rb
    h1129 = Harami1129.create_manual!(**hscorrect)
    assert h1129.valid?
    assert h1129.created_at

    model_symbols = [:Artist, :Engage, :Harami1129, :HaramiVid, :HaramiVidMusicAssoc, :Music, :Translation]
    hsary = h1129.insert_populate_true_dryrun(messages: [], dryrun: nil)
    assert_equal model_symbols, hsary.keys.sort
    assert_operator 0, :<, hsary[:Artist].size
    assert_equal 1, hsary[:Artist].size
    assert_equal 1, hsary[:Music].size
    assert_equal 3, hsary[:Translation].size
    assert_equal ms+"t", hsary[:Harami1129][0].ins_title
    assert_equal ms+"t", hsary[:Translation].find{|i| i.translatable_type == "HaramiVid"}.title
    assert_equal ms+"a", hsary[:Translation].find{|i| i.translatable_type == "Artist"}.title
    assert_equal ms+"m", hsary[:Translation].find{|i| i.translatable_type == "Music"}.title
    assert_equal hsary[:Artist].first.id,    hsary[:Engage].first.artist_id
    assert_equal hsary[:Music].first.id,     hsary[:Engage].first.music_id
    assert_equal hsary[:Music].first.id,     hsary[:HaramiVidMusicAssoc].first.music_id
#puts "DEBUG:532:+hsary[:HaramiVid]=#{hsary[:HaramiVid].inspect}"
#    assert_equal hsary[:HaramiVid].first.id, hsary[:HaramiVidMusicAssoc].first.harami_vid_id, "Strangely, not working...the former is nil despite it was non-nil in the method itself: hsary[:HaramiVid]=#{hsary[:HaramiVid].inspect}"
    assert_equal hscorrect[:link_time],      hsary[:HaramiVidMusicAssoc].first.timing
    assert_empty hsary[:Music].first.translations
    assert_raises(ActiveRecord::RecordNotFound){
      hsary[:HaramiVidMusicAssoc].first.music.reload }  # ".music" works perhaps due to cache, but reload does not.

    #
    # Another Harmai1129 with an identical set of Music and Artist (but different link_root & id_remote)
    #
    h1129_ai = harami1129s(:harami1129_ai)  # already populated.
    hsanother = {}
    %i(last_downloaded_at release_date singer song).each do |i|
      hsanother[i] = h1129_ai[i]
    end

    hsanother.merge!({
      id_remote: _get_unique_id_remote,  # defined in test_helper.rb
      title: h1129_ai[:title]+"t",
      link_root: h1129_ai[:link_root]+"2",
      link_time: h1129_ai[:link_time]+1,
    })
    h1129_2 = Harami1129.create_manual!(**hsanother)
    assert h1129_2.valid?
    assert h1129_2.created_at

    hsar2 = h1129_2.insert_populate_true_dryrun(messages: [], dryrun: nil)
    assert_equal model_symbols, hsar2.keys.sort
    assert_equal 1, hsar2[:Artist].size
    assert_equal 1, hsar2[:Music].size
    assert  hsar2[:Artist].first.valid?
    assert  hsar2[:Music ].first.valid?
    assert_equal h1129_ai.engage.artist, hsar2[:Artist].first
    assert_equal h1129_ai.engage.music,  hsar2[:Music].first
  end

  test "insert_populate live-streaming" do
    ms = __method__.to_s
    hscorrect = {title: "【生配信】東京リベンジャーズ特集:"+ms+"t", singer: ms+"a", song: ms+"m", release_date: (rdate=Date.today-2.days), link_root: "youtu.be/"+ms, link_time: 778, id_remote: _get_unique_id_remote, last_downloaded_at: DateTime.now}  # defined in test_helper.rb
    h1129 = Harami1129.create_manual!(**hscorrect)
    assert h1129.valid?
    assert h1129.created_at

    str_equation = 'HaramiVid.count*10000 + Artist.count*1000 + Music.count*100 + Engage.count*10'
    str_eq2      = 'HaramiVidEventItemAssoc.count*1000+Event.count*100 + EventItem.count*10 + ArtistMusicPlay.count'

    ## before internal_insertion
    pstat = h1129.populate_status(use_cache: true)
    assert_equal :no_insert, pstat.status(:ins_title)
    assert_equal "\u274c",   pstat.marker(:ins_title)
    assert_nil h1129.reload.harami_vid

    ## run internal_insertion
    assert_difference(str_equation, 11110) do
      h1129.insert_populate
    end

    hvid = h1129.reload.harami_vid
    assert_operator h1129.created_at, :<, hvid.created_at, "sanity check. HaramiVid is newly created from h1129."

    evit = h1129.event_item
    assert_match(/\bstreamings?\b/,  h1129.event_item.event_group.best_translations["en"].title)
    assert_equal EventGroup.find_by_mname(:live_streamings),  h1129.event_item.event_group
    assert_equal rdate, h1129.event_item.start_time.to_date
    assert_equal evit, hvid.event_items.first

    assert_equal places(:harami_home_unknown_prefecture_japan), evit.place
    amp = evit.artist_music_plays.first
    assert_equal 1, evit.artist_music_plays.count
    assert_equal Artist.default(:HaramiVid), amp.artist
    assert_equal ms+"m", amp.music.title
  end
end

