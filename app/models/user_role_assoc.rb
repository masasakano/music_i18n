# == Schema Information
#
# Table name: user_role_assocs
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  role_id    :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_user_role_assocs_on_role_id              (role_id)
#  index_user_role_assocs_on_user_id              (user_id)
#  index_user_role_assocs_on_user_id_and_role_id  (user_id,role_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (role_id => roles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class UserRoleAssoc < ApplicationRecord
  belongs_to :user
  belongs_to :role
  validates :user, uniqueness: { scope: :role }
end
