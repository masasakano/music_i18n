# == Schema Information
#
# Table name: harami_vid_event_item_assocs
#
#  id                                                                          :bigint           not null, primary key
#  note                                                                        :text
#  timing(in second; boundary with another EventItem like Artist's appearance) :integer
#  created_at                                                                  :datetime         not null
#  updated_at                                                                  :datetime         not null
#  event_item_id                                                               :bigint           not null
#  harami_vid_id                                                               :bigint           not null
#
# Indexes
#
#  index_harami_vid_event_item                          (harami_vid_id,event_item_id) UNIQUE
#  index_harami_vid_event_item_assocs_on_event_item_id  (event_item_id)
#  index_harami_vid_event_item_assocs_on_harami_vid_id  (harami_vid_id)
#  index_harami_vid_event_item_assocs_on_timing         (timing)
#
# Foreign Keys
#
#  fk_rails_...  (event_item_id => event_items.id) ON DELETE => cascade
#  fk_rails_...  (harami_vid_id => harami_vids.id) ON DELETE => cascade
#
class HaramiVidEventItemAssoc < ApplicationRecord
  belongs_to :harami_vid
  belongs_to :event_item

  validates :harami_vid, uniqueness: { scope: :event_item }, allow_nil: false  # allow_nil: false  is Default
end
