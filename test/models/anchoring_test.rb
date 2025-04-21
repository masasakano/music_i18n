# == Schema Information
#
# Table name: anchorings
#
#  id              :bigint           not null, primary key
#  anchorable_type :string           not null
#  note            :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  anchorable_id   :bigint           not null
#  url_id          :bigint           not null
#
# Indexes
#
#  index_anchorings_on_anchorable  (anchorable_type,anchorable_id)
#  index_anchorings_on_url_id      (url_id)
#  index_url_anchorables           (url_id,anchorable_type,anchorable_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (url_id => urls.id) ON DELETE => cascade
#
require "test_helper"

class AnchoringTest < ActiveSupport::TestCase
  test "polymorphic relations" do
    anch = anchorings(:one)
    assert_equal anch.url,     urls(:one)
    assert_equal anch.anchorable, channels(:one)

    anch = anchorings(:url_haramichan_main_artist_harami)
    assert_equal anch.url,     urls(:url_haramichan_main)
    assert_equal anch.anchorable, artists(:artist_harami)
  end
end
