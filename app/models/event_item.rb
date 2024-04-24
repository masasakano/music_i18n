# == Schema Information
#
# Table name: event_items
#
#  id                                       :bigint           not null, primary key
#  duration_minute                          :float
#  duration_minute_err(in second)           :float
#  event_ratio(Event-covering ratio [0..1]) :float
#  machine_title                            :string           not null
#  note                                     :text
#  start_time                               :datetime
#  start_time_err(in second)                :float
#  weight                                   :float
#  created_at                               :datetime         not null
#  updated_at                               :datetime         not null
#  event_id                                 :bigint           not null
#  place_id                                 :bigint
#
# Indexes
#
#  index_event_items_on_duration_minute  (duration_minute)
#  index_event_items_on_event_id         (event_id)
#  index_event_items_on_event_ratio      (event_ratio)
#  index_event_items_on_machine_title    (machine_title) UNIQUE
#  index_event_items_on_place_id         (place_id)
#  index_event_items_on_start_time       (start_time)
#  index_event_items_on_weight           (weight)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id) ON DELETE => restrict
#  fk_rails_...  (place_id => places.id) ON DELETE => nullify
#
class EventItem < ApplicationRecord
  include ModuleCommon

  belongs_to :event
  belongs_to :place, optional: true
  has_one :event_group, through: :event
  has_one :prefecture, through: :place
  has_one :country, through: :prefecture

  has_many :artist_music_plays, dependent: :destroy  # dependent is a key  # to an Association model! (NOT to Artists/Musics)
  %i(artists musics play_roles instruments).each do |esym|
    has_many esym, -> {distinct}, through: :artist_music_plays
  end

  has_many :harami_vid_event_item_assocs, dependent: :restrict_with_exception  # dependent is a key
       # This setting basically prohibits a deletion of an EventItem associated with at least one user
       # so that a HaramiVid would not become EventItem-less.
       # This means you should merge the EventItem to another or something before destroy.
  has_many :harami_vids, -> {distinct}, through: :harami_vid_event_item_assocs  # if the unique constraint is on for Association, `distinct` is redundant

  validates_uniqueness_of :machine_title
  %i(start_time_err duration_minute duration_minute_err event_ratio).each do |ec|
    validates ec, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  end
  %i(event_ratio).each do |ec|
    validates ec, numericality: { less_than_or_equal_to: 1 }, allow_blank: true
  end

  def destroyable?
    !harami_vid_event_item_assocs.exists?
  end
end
