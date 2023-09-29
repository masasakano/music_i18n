# == Schema Information
#
# Table name: model_summaries
#
#  id         :bigint           not null, primary key
#  modelname  :string           not null
#  note       :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_model_summaries_on_modelname  (modelname) UNIQUE
#
require "test_helper"

class ModelSummaryTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
