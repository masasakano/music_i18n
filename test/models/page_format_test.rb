# == Schema Information
#
# Table name: page_formats
#
#  id                       :bigint           not null, primary key
#  description              :text
#  mname(unique identifier) :string           not null
#  note                     :text
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_page_formats_on_mname  (mname) UNIQUE
#
require "test_helper"

class PageFormatTest < ActiveSupport::TestCase
  test "non-null" do
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::NotNullViolation){
      PageFormat.create!(note: nil) }  # PG::NotNullViolation => Rails: "Validation failed: Iso5218 can't be blank"
  end

  test "unique" do
    page1 = page_formats(:one)
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique){ PageFormat.create!(mname: page1.mname) }  # PG::UniqueViolation => "Validation failed: Iso5218 has already been taken"
  end

  test "has_many" do
    page_format1 = PageFormat.first
    assert_nothing_raised{
      page_format1.static_pages.count }
  end

  test "square brackets" do
    assert_equal page_formats(:page_format_full_html), PageFormat['full_html']
  end
end
