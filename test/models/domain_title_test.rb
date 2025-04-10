# == Schema Information
#
# Table name: domain_titles
#
#  id                                         :bigint           not null, primary key
#  memo_editor(Internal-use memo for Editors) :text
#  note                                       :text
#  weight(weight to sort this model index)    :float
#  created_at                                 :datetime         not null
#  updated_at                                 :datetime         not null
#  site_category_id                           :bigint           not null
#
# Indexes
#
#  index_domain_titles_on_site_category_id  (site_category_id)
#  index_domain_titles_on_weight            (weight)
#
# Foreign Keys
#
#  fk_rails_...  (site_category_id => site_categories.id)
#
require "test_helper"

class DomainTitleTest < ActiveSupport::TestCase

  test "associations" do
    dname = domain_titles(:one)
    assert dname.site_category
    assert dname.valid?
    dname.site_category = nil
    refute dname.valid?
  end
end

