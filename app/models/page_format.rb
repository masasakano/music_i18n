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
class PageFormat < ApplicationRecord
  has_many :static_pages, dependent: :restrict_with_exception

  validates_presence_of   :mname
  validates_uniqueness_of :mname

  FULL_HTML     = 'full_html'
  FILTERED_HTML = 'filtered_html'
  MARKDOWN      = 'markdown'

  # Returns the identified model by mname
  #
  # @param name [String, Symbol] mname
  # @return [self, NilClass]
  def self.[](name)
    find_by mname: name.to_s
  end
end

