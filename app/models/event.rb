# coding: utf-8

# == Schema Information
#
# Table name: events
#
#  id                        :bigint           not null, primary key
#  duration_hour             :float
#  note                      :text
#  start_time                :datetime
#  start_time_err(in second) :bigint
#  weight                    :float
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  event_group_id            :bigint           not null
#  place_id                  :bigint
#
# Indexes
#
#  index_events_on_duration_hour   (duration_hour)
#  index_events_on_event_group_id  (event_group_id)
#  index_events_on_place_id        (place_id)
#  index_events_on_start_time      (start_time)
#  index_events_on_weight          (weight)
#
# Foreign Keys
#
#  fk_rails_...  (event_group_id => event_groups.id) ON DELETE => restrict
#  fk_rails_...  (place_id => places.id) ON DELETE => nullify
#
class Event < BaseWithTranslation
  # For the translations to be unique (required by BaseWithTranslation).
  MAIN_UNIQUE_COLS = []

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" when "The Beatles" is passed.  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = true

  belongs_to :event_group
  belongs_to :place
  has_one :prefecture, through: :place
  has_one :country, through: :prefecture

  # Validates if a {Translation} is unique within the parent
  #
  # Fired from {Translation}
  # @param record [Translation]
  def validate_translation_callback(record)
    validate_translation_unique_within_parent(record)
  end

  %i(duration_hour).each do |ec|
    validates ec, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  end

  # Returns {TimeWithError} of {#start_time} with {#start_time_err}  in the application Time zone
  #
  # In the DB, time is saved in UT, perhaps corrected from the app
  # timezone; i.e., if a user-input Time is in JST (+09:00), its saved time
  # in the DB is 9 hours behind.
  #
  # This method returns {TimeWithError} with the app-timezone, likely JST +09:00,
  # as set in /config/application.rb
  #
  # @return [TimeWithError]
  def start_app_time
    return nil if !start_time

    t = TimeWithError.at(Time.at(start_time), in: Rails.configuration.music_i18n_def_timezone_str)
    ## Note: TimeWithError.at(start_time) would fail with
    ##   TypeError: can't convert ActiveSupport::TimeWithZone into an exact number

    t.error = start_time_err
    t.error &&= t.error.second 
    t
  end

  # See {ModuleCommon#string_time_err2uptomin} for detail.
  #
  # @return [String] formatted String of Date-Time
  def string_time_err2uptomin(langcode: I18n.locale)
    time_err2uptomin(start_app_time, langcode: I18n.locale)  # defined in module_common.rb
  end
end
