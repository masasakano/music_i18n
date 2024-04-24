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
require "test_helper"

class HaramiVidEventItemAssocTest < ActiveSupport::TestCase
   test "association" do
     hs = {harami_vid: HaramiVid.first, event_item: EventItem.first}
     rec0 = HaramiVidEventItemAssoc.new(hs)
     rec1 = HaramiVidEventItemAssoc.new(hs)
     rec0.save!
     assert_raises(ActiveRecord::RecordNotUnique, "not unique violation: #{HaramiVidEventItemAssoc.where(hs).all}"){
       rec1.save!(validate: false)} # DB level
     assert_raises(ActiveRecord::RecordInvalid){   rec1.save! }                  # Rails level

     %w(harami_vid event_item).each do |metho|
       metho_w = metho+"="
       rec1.send metho_w, nil
       assert_raises(ActiveRecord::NotNullViolation){rec1.save!(validate: false) } # DB level
       refute rec1.valid?, "#{metho} is null and should be invalid, but..."
       rec1.send metho_w, rec0.send(metho)
   
       metho_id   = metho+"_id"
       metho_id_w = metho_id + "="
       rec1.send(metho_id_w, metho.camelize.constantize.order(:id).last.id+1)
       assert_raises(ActiveRecord::InvalidForeignKey){rec1.save!(validate: false) } # DB level
       refute rec1.valid?, "#{metho_id} is invalid and should be caught as invalid, but..."
       rec1.send metho_id_w, rec0.send(metho_id)
     end
   end
end
