# coding: utf-8

# == Schema Information
#
# Table name: play_roles
#
#  id                                                  :bigint           not null, primary key
#  mname(unique machine name)                          :string           not null
#  note                                                :text
#  weight(weight to sort entries in Index for Editors) :float            default(999.0), not null
#  created_at                                          :datetime         not null
#  updated_at                                          :datetime         not null
#
# Indexes
#
#  index_play_roles_on_mname   (mname) UNIQUE
#  index_play_roles_on_weight  (weight)
#
class PlayRole < BaseWithTranslation
  # defines {#unknown?} and +self.class.unknown+
  include ModuleUnknown

  # For the translations to be unique (required by BaseWithTranslation).
  MAIN_UNIQUE_COLS = []

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" when "The Beatles" is passed.  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = true

  # Optional constant for a subclass of {BaseWithTranslation} to define the scope
  # of required uniqueness of title and alt_title.
  #TRANSLATION_UNIQUE_SCOPES = :default

  has_many :artist_music_plays, dependent: :restrict_with_exception  # dependent is a key / Basically PlayRole should not be easily destroyed - it may be merged instead.
  %i(event_items artists musics instruments).each do |esym|
    has_many esym, -> {distinct}, through: :artist_music_plays
  end

  validates_presence_of   :mname
  validates_uniqueness_of :mname
  validates_presence_of   :weight  # NOTE: At the DB level, a default is defined.
  validates_uniqueness_of :weight  # No DB-level constraint, but this is checked at Rails-level.
  validates :weight, :numericality => { :greater_than_or_equal_to => 0 }

  # NOTE: UNKNOWN_TITLES required to be defined for the methods included from ModuleUnknown. alt_title can be also defined as an Array instead of String.
  UNKNOWN_TITLES = UnknownPlayRole = {
    "ja" => ['イベント項目関与形態不明', '関与形態不明'],
    "en" => ['Unknown Engage-EventItem relation', 'Unknown relation'],
    "fr" => ['Relation inconnue entre Engage-EventItem', 'Relation inconnue'],
  }.with_indifferent_access

  # Returning a default Model in the given context
  #
  # place is ignored so far.
  #
  # @option context [Symbol, String]
  # @option place: [Place]
  # @return [PlayRole]
  def self.default(context=nil, place: nil)
    case context.to_s.underscore.singularize
    when *(%w(harami_vid harami1129))
      ret = self.find_by(mname: "inst_player_main")
      return ret if ret  # This should never fail!
      msg = "Failed to identify the default #{self.name}"
      logger.error("ERROR(#{File.basename __FILE__}:#{__method__}): "+msg)
      raise msg
    end

    self.unknown
  end

end
