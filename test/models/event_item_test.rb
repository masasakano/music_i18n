# == Schema Information
#
# Table name: event_items
#
#  id                                       :bigint           not null, primary key
#  duration_minute                          :float
#  duration_minute_err(in second)           :float
#  event_ratio(Event-covering ratio [0..1]) :float
#  machine_title                            :string           not null
#  note                                     :text
#  start_time                               :datetime
#  start_time_err(in second)                :float
#  weight                                   :float
#  created_at                               :datetime         not null
#  updated_at                               :datetime         not null
#  event_id                                 :bigint           not null
#  place_id                                 :bigint
#
# Indexes
#
#  index_event_items_on_duration_minute  (duration_minute)
#  index_event_items_on_event_id         (event_id)
#  index_event_items_on_event_ratio      (event_ratio)
#  index_event_items_on_machine_title    (machine_title) UNIQUE
#  index_event_items_on_place_id         (place_id)
#  index_event_items_on_start_time       (start_time)
#  index_event_items_on_weight           (weight)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id) ON DELETE => restrict
#  fk_rails_...  (place_id => places.id) ON DELETE => nullify
#
require "test_helper"

class EventItemTest < ActiveSupport::TestCase
  test "constraints" do
    evit1 = event_items(:evit_1_harami_lucky2023)

    assert_raises(ActiveRecord::RecordInvalid){
      EventItem.create!(machine_title: "naiyo") }  # Validation failed: Event must exist
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique){
      EventItem.create!(machine_title: evit1.machine_title, event: evit1.event) } # DB-level Message: <"PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint \"index_event_items_on_machine_title\"\nDETAIL:  Key (machine_title)=(Lucky2023 No.1) already exists.\n">

    assert_raises(ActiveRecord::RecordInvalid){
      EventItem.create!(machine_title: "naiyo1", event: evit1.event, start_time_err: -3) }
    assert_raises(ActiveRecord::RecordInvalid){
      EventItem.create!(machine_title: "naiyo1", event: evit1.event, duration_minute: -3) }
    assert_raises(ActiveRecord::RecordInvalid){
      EventItem.create!(machine_title: "naiyo1", event: evit1.event, event_ratio: 1.5) }  # [0, 1] is allowed.
  end

  test "associations via ArtistMusicPlayTest" do
    evi0 = EventItem.create!(machine_title: "EvI0 ArtistMusicPlayTest", event: Event.first)
    art0 = Artist.create!(sex: Sex.first).with_translation(langcode: "en", is_orig: "true", title: "Sam0 ArtistMusicPlayTest")
    mus0 = Music.create!().with_translation(langcode: "en", is_orig: "true", title: "Song0 ArtistMusicPlayTest")

    evit1 = event_items(:evit_1_harami_budokan2022_soiree)
    assert_operator 2, :<=, evit1.artist_music_plays.count, 'check has_many artist_music_plays and also fixtures'
    assert_operator 2, :<=, evit1.artists.count, 'check has_many artists and also fixtures'
    assert   evit1.artists.include?(artists(:artist_harami))
    assert_operator 1, :<=, evit1.musics.count, 'check has_many musics and also fixtures'
    assert_operator 2, :<=, evit1.play_roles.count, 'check has_many play_roles and also fixtures'
    assert_operator 2, :<=, evit1.instruments.count, 'check has_many instruments and also fixtures'

    assert_difference("ArtistMusicPlay.count", -ArtistMusicPlay.where(event_item: evit1).count, "Test of dependent"){
      evit1.destroy
    }
  end
end
