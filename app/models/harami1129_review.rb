# == Schema Information
#
# Table name: harami1129_reviews
#
#  id                                                                      :bigint           not null, primary key
#  checked(This record of Harami1129 is manually checked)                  :boolean          default(FALSE)
#  harami1129_col_name(Either ins_singer or ins_song)                      :string           not null
#  harami1129_col_val(String Value of column harami1129_col_name)          :string
#  note                                                                    :text
#  created_at                                                              :datetime         not null
#  updated_at                                                              :datetime         not null
#  engage_id(Updated Engage)                                               :bigint           not null
#  harami1129_id(One of Harami1129 this change is applicable to; nullable) :bigint
#  user_id(Last User that created or updated, or nil)                      :bigint
#
# Indexes
#
#  index_harami1129_reviews_on_engage_id           (engage_id)
#  index_harami1129_reviews_on_harami1129_col_val  (harami1129_col_val)
#  index_harami1129_reviews_on_harami1129_id       (harami1129_id)
#  index_harami1129_reviews_on_user_id             (user_id)
#  index_harami1129_reviews_unique01               (harami1129_id,harami1129_col_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (engage_id => engages.id) ON DELETE => cascade
#  fk_rails_...  (harami1129_id => harami1129s.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => nullify
#
class Harami1129Review < ApplicationRecord
  belongs_to :harami1129
  belongs_to :engage
  belongs_to :user, optional: true  # nullable

  validates_uniqueness_of :harami1129_id, scope: :harami1129_col_name
  validates :harami1129_col_name, acceptance: { accept: %w(ins_singer ins_song) }
end
