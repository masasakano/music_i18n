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
require 'test_helper'

class UserRoleAssocTest < ActiveSupport::TestCase
  test "fixture and belongs to role" do
    ura = user_role_assocs(:user_role_assoc_sysadmin)
    assert_equal 1, ura.role_id
    assert_equal 1, ura.user_id
    assert_equal 'admin', ura.role.name
  end

  test "unique combination" do
    ura = UserRoleAssoc.first
    ura2 = ura.dup
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique){ ura2.save! }  # PG::UniqueViolation (though it is caught by Rails validation before passed to the DB)
  end
end
