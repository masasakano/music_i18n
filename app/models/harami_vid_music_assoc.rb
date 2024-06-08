# == Schema Information
#
# Table name: harami_vid_music_assocs
#
#  id                                                                          :bigint           not null, primary key
#  completeness(The ratio of the completeness in duration of the played music) :float
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
class HaramiVidMusicAssoc < ApplicationRecord
  include ModuleCommon # for add_trans_info()
  belongs_to :harami_vid
  belongs_to :music

  validates_uniqueness_of :music, scope: :harami_vid
  validates_numericality_of :timing, allow_nil: true, greater_than_or_equal_to: 0, message: "(%{value}) must be 0 or positive."
  validate :completeness_between  # For Float, this does not work?: validates_numericality_of :completeness_between, within: (0..1)

  alias_method :inspect_orig, :inspect if ! self.method_defined?(:inspect_orig)
  include ModuleModifyInspectPrintReference
  redefine_inspect

  private

    def completeness_between
      if completeness && !(0..1).cover?(completeness)
        errors.add :completeness, "#{completeness} out of range of (0..1)."
      end
    end
end
