# coding: utf-8

# == Schema Information
#
# Table name: event_groups
#
#  id                                                                                          :bigint           not null, primary key
#  end_date(if null, end date is undefined.)                                                   :date
#  end_date_err(Error of end-date in day. 182 or 183 days for one with only a known year.)     :integer
#  note                                                                                        :text
#  order_no(Serial number for a series of Event Group, e.g., 5(-th))                           :integer
#  start_date(if null, start date is undefined.)                                               :date
#  start_date_err(Error of start-date in day. 182 or 183 days for one with only a known year.) :integer
#  created_at                                                                                  :datetime         not null
#  updated_at                                                                                  :datetime         not null
#  place_id                                                                                    :bigint
#
# Indexes
#
#  index_event_groups_on_end_date    (end_date)
#  index_event_groups_on_order_no    (order_no)
#  index_event_groups_on_place_id    (place_id)
#  index_event_groups_on_start_date  (start_date)
#
# Foreign Keys
#
#  fk_rails_...  (place_id => places.id) ON DELETE => nullify
#
class EventGroup < BaseWithTranslation
  # include Rails.application.routes.url_helpers

  # For the translations to be unique (required by BaseWithTranslation).
  MAIN_UNIQUE_COLS = []

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" when "The Beatles" is passed.  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = true

  belongs_to :place, optional: true
  has_one :prefecture, through: :place
  has_one :country, through: :prefecture
  #has_many :events  #, dependent: :destroy

  UnknownEventGroup = {
    "ja" => 'その他のイベント類',
    "en" => 'UncategorizedEventGroup',
    "fr" => "Groupe d'événements non classé",
  }.with_indifferent_access

  # Validates if a {Translation} is unique within the parent
  #
  # Fired from {Translation}
  # @param record [Translation]
  def validate_translation_callback(record)
    validate_translation_unique_within_parent(record)
  end

  %i(start_year end_year).each do |ec|
    validates ec, numericality: { greater_than_or_equal_to: 1 }, allow_blank: true
  end

  %i(start_month end_month).each do |ec|
    validates ec, numericality: { in: 1..12 }, allow_blank: true
  end

  %i(start_day end_day).each do |ec|
    # "30 February" would be allowed...
    validates ec, numericality: { in: 1..31 }, allow_blank: true
  end

  # Returns the unknown {EventGroup}
  #
  # @return [EventGroup]
  def self.unknown
     self[UnknownEventGroup['en'], 'en']
  end

  # Returns true if self is one of the unknown country
  def unknown?
    title(langcode: 'en') == UnknownEventGroup['en']
  end
  alias_method :uncategorized?, :unknown? if ! self.method_defined?(:uncategorized?)

end

class << EventGroup 
  alias_method :uncategorized, :unknown if ! self.method_defined?(:uncategorized)
end

