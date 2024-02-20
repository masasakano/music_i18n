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
require "test_helper"

class Harami1129ReviewTest < ActiveSupport::TestCase
  test "validate" do
    h1129_kubota = harami1129s(:harami1129_ihojin1)
    h1129_ai     = harami1129s(:harami1129_ai)

    # Valid transaction
    record = Harami1129Review.new(harami1129: h1129_kubota, engage: h1129_kubota.engage, user: nil, harami1129_col_name: "ins_singer", harami1129_col_val: "xyz")
    record.save!
    assert_equal "xyz", Harami1129Review.where(harami1129: h1129_kubota).first.harami1129_col_val
    record.destroy
    refute              Harami1129Review.where(harami1129: h1129_kubota).exists?

    # invalid
    record = Harami1129Review.new(harami1129: nil,          engage: h1129_kubota.engage, user: nil, harami1129_col_name: "ins_singer", harami1129_col_val: "xyz")
    record = Harami1129Review.new(harami1129: nil,          engage: h1129_kubota.engage, user: nil, harami1129_col_name: "ins_singer", harami1129_col_val: "xyz")
    ### The following is accepted at the moment because harami1129_id is nullable.  This may change in the future.
    # assert_raises(ActiveRecord::NotNullViolation){ record.save!(validate: false) }  #  PG::NotNullViolation: ERROR:  null value in column "harami1129_id" of relation "harami1129_reviews" violates not-null constraint
    # assert_raises(ActiveRecord::RecordInvalid){    record.save! }  # "Validation failed: Harami1129 must exist"
    # refute  record.valid?  # automatic null validation by Rails for belongs_to

    record.harami1129 = h1129_kubota  # valid
    record.engage     = nil           # invalid
    assert_raises(ActiveRecord::NotNullViolation){ record.save!(validate: false) }  #  PG::NotNullViolation: ERROR:  null value in column "engage_id" of relation "harami1129_reviews" violates not-null constraint
    refute  record.valid?  # automatic null validation by Rails for belongs_to

    record.engage     = h1129_kubota.engage # valid
    record.harami1129_col_name = nil  # invalid on DB
    assert_raises(ActiveRecord::NotNullViolation){ record.save!(validate: false) }  #  PG::NotNullViolation: ERROR:  null value in column "harami1129_col_name" of relation "harami1129_reviews" violates not-null constraint
    record.harami1129_col_name = "wrong"  # invalid by Rails validate
    refute  record.valid?  # automatic null validation by Rails for belongs_to

    # Unique violation
    record = Harami1129Review.new(harami1129: h1129_ai, engage: h1129_ai.engage, user: nil, harami1129_col_name: "ins_singer", harami1129_col_val: "xyz")
    assert_raises(ActiveRecord::RecordNotUnique){ record.save!(validate: false) }  # PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint "index_harami1129_reviews_unique01"
    refute  record.valid?  # unique violation
  end
end
