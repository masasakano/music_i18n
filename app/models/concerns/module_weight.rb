# Common module for models that have the weight attribute
#
# This assumes that weight can be nil/null.
#
# The model that includes this module should have a (set of) model test as follows:
#
#    test "weight validations" do
#      mdl = my_models(:one)
#      user_assert_model_weight(mdl, allow_nil: true)  # defined in test_helper.rb
#    end
#
# @example
#    include ModuleWeight  # adds a validation
#
module ModuleWeight
  extend ActiveSupport::Concern

  included do
    validates :weight, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  end

end

