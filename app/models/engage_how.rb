# coding: utf-8
# == Schema Information
#
# Table name: engage_hows
#
#  id         :bigint           not null, primary key
#  note       :text
#  weight     :float            default(999.0)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class EngageHow < BaseWithTranslation
  # defines {#unknown?} and +self.class.unknown+
  include ModuleUnknown

  # Class-method helpers
  include ClassMethodHelper

  # For the translations to be unique (required by BaseWithTranslation).
  MAIN_UNIQUE_COLS = []

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" when "The Beatles" is passed.  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = true

  has_many :engages, dependent: :restrict_with_exception

  # Validates translation immediately before it is added.
  #
  # Called by a validation in {Translation}
  # Basically, Translations must be unique.
  #
  # @param record [Translation]
  # @return [Array] of Error messages, or empty Array if everything passes
  def validate_translation_callback(record)
    validate_translation_neither_title_nor_alt_exist(record)  # defined in BaseWithTranslation
  end

  validates_presence_of :weight  # Because of the DB default value, this does nothing in practice.
  validates :weight, :numericality => { :greater_than_or_equal_to => 0 }

  UNKNOWN_TITLES = UnknownEngageHow = {
    "ja" => '関与形態不明',
    "en" => 'UnknownEngaging',
    #"fr" => 'ArtisteInconnu',
  }

  def <(other)
    raise TypeError, "cannot compare with non-#{self.class.name}" if !other.respond_to?(:engages) || !other.respond_to?(:weight)
    weight < other.weight
  end

  def >(other)
    raise TypeError, "cannot compare with non-#{self.class.name}" if !other.respond_to?(:engages) || !other.respond_to?(:weight)
    weight > other.weight
  end

  def <=>(other)
    raise TypeError, "cannot compare with non-#{self.class.name}" if !other.respond_to?(:engages) || !other.respond_to?(:weight)
    if    self < other
      -1
    elsif self > other
      1
    else  # TypeError hould have been already raised in comparison with a different class.
      0
    end
  end

  # Returning a default Model in the given context
  #
  # place is ignored so far.
  #
  # @option context [Symbol, String]
  # @option place: [Place]
  # @return [EngageHow]
  def self.default(context=nil, place: nil)
    case context.to_s.underscore.singularize
    when %w(harami_vid harami1129)
      return find_default(/^((original|オリジナル).*(singer|歌手))|((original|オリジナル).*(singer|歌手))$/i)
    end

    self.unknown
  end

end

