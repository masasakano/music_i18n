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
class Anchoring < ApplicationRecord
  belongs_to :url
  belongs_to :anchorable, polymorphic: true
end
