# == Schema Information
#
# Table name: harami_vid_music_assocs
#
#  id                                                                          :bigint           not null, primary key
#  completeness(The ratio of the completeness in duration of the played music) :float
#  flag_collab(False if it is not a solo playing)                              :boolean
#  note                                                                        :text
#  timing(Startint time in second)                                             :integer
#  created_at                                                                  :datetime         not null
#  updated_at                                                                  :datetime         not null
#  harami_vid_id                                                               :bigint           not null
#  music_id                                                                    :bigint           not null
#
# Indexes
#
#  index_harami_vid_music_assocs_on_harami_vid_id  (harami_vid_id)
#  index_harami_vid_music_assocs_on_music_id       (music_id)
#  index_unique_harami_vid_music                   (harami_vid_id,music_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (harami_vid_id => harami_vids.id) ON DELETE => cascade
#  fk_rails_...  (music_id => musics.id) ON DELETE => cascade
#
require 'test_helper'

class HaramiVidMusicAssocTest < ActiveSupport::TestCase
  test "fixture and belongs to unique combination" do
    ura = harami_vid_music_assocs(:harami_vid_music_assoc1)
    assert_equal harami_vids(:harami_vid1), ura.harami_vid
    assert_equal musics(:music1), ura.music

    ura2 = ura.dup
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique){ ura2.save! }  # PG::UniqueViolation (though it is caught by Rails validation before passed to the DB)
  end

  test "dependent on_delete and has_many" do
    ura = harami_vid_music_assocs(:harami_vid_music_assoc1)
    h1 = harami_vids(:harami_vid1)
    m1 = musics(:music1)
    chan = Channel.primary
    h2 = HaramiVid.create!(channel: chan)

    n_orig = HaramiVidMusicAssoc.count
    m1hv = m1.harami_vids
    assert_equal h1, m1hv[0]

    m1hv << h2
    assert_equal n_orig+1, HaramiVidMusicAssoc.count
    m1hv2 = m1.harami_vids
    assert_equal 2, m1hv2.size

    ura3 = HaramiVidMusicAssoc.last
    assert_raises(ActiveRecord::RecordInvalid){
      ura3.update!(timing: -3) }       # "Validation failed: Timing (-3) must be 0 or positive."
    assert_nothing_raised{ 
      ura3.update!(timing: 0) }
    assert_raises(ActiveRecord::RecordInvalid){
      ura3.update!(completeness: -3) } # "Validation failed: Completeness (-3) must be within (0..1)."
    assert_raises(ActiveRecord::RecordInvalid){
      ura3.update!(completeness:  3) } # "Validation failed: Completeness (3) must be within (0..1)."
    assert_nothing_raised{ 
      ura3.update!(completeness: 0)
      ura3.update!(completeness: 1)
    }

    h2.destroy
    assert_equal n_orig,   HaramiVidMusicAssoc.count  # on_delete: :cascade

    # h1.has_many is not tested.
  end
end
