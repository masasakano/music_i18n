# coding: utf-8

# == Schema Information
#
# Table name: sexes
#
#  id         :bigint           not null, primary key
#  iso5218    :integer          not null
#  note       :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_sexes_on_iso5218  (iso5218) UNIQUE
#
class Sex < BaseWithTranslation
  # For the translations to be unique (required by BaseWithTranslation).
  MAIN_UNIQUE_COLS = [:iso5218]

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" when "The Beatles" is passed.  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = true

  # Optional constant for a subclass of {BaseWithTranslation} to define the scope
  # of required uniqueness of title and alt_title.
  #TRANSLATION_UNIQUE_SCOPES = :default

  has_many :artists, dependent: :restrict_with_exception
  validates_uniqueness_of :iso5218
  validates :iso5218, presence: true

  # All possible ISO5218 numbers (the constant name is ISO5218+"capital-S")
  ISO5218S = [0, 1, 2, 9]

  UnknownSex = {
    "ja" => '不明',
    "en" => 'not known',
    #"fr" => 'pas connu',
  }

  class << self
    alias_method :bracket_orig, :[] if ! self.method_defined?(:bracket_orig)
  end

  # Modifying {BaseWithTranslation.[]}
  #
  # So it also accepts iso5218 (Integer) or Symbol like :male
  # in addition to String as in default.
  #
  # @example
  #   Sex[2]                # Integer(ISO5218: 2), female
  #   Sex[:unknown]         # Symbol
  #   Sex['not applicable'] # Standard Translation String
  #   Sex['男', 'ja']       # Standard Translation String
  #
  # @param value [Regexp, String, Symbol, Integer, NilClass]
  #   For symbol, the following is accepted. :unknown, :male, and :female
  #   If nil, the first Sex with no translation is returned (there should be none, hence nil).
  # @param langcode [String, NilClass] like 'ja'. If nil, all languages
  # @param with_alt [Boolean] if TRUE (Def: False), alt_title is ALSO searched.
  # @return [BaseWithTranslation, NilClass]
  def self.[](value=nil, *args)
    # Converts Symbol to the corresponding ISO5218 value.
    value = 
      case value
      when :unknown
        0
      when :male
        1
      when :female
        2
      when :'not applicable'
        9
      when Symbol
        raise ArgumentError, "contact the code developer. Symbol given (#{value}) is invalid."
      else
        value
      end

    if value.respond_to?(:infinite?)
      self.find_by(iso5218: value)
    else
      super(value, *args)
    end
  end

  # Returns the unknown {Sex}
  #
  # @return [Sex]
  def self.unknown
     Sex.find_by(iso5218: 0)
  end

  # Returns true if self is the unknown {Sex}
  def unknown?
     iso5218 == 0
  end

  # Used in the class {CheckedDisabled} defined in /app/controllers/concerns/
  #
  # Return {CheckedDisabled} if the index is the first significant one,
  # (preferably defcheck_index if that is OK), i.e., not unknown.
  # If there is none, returns nil.
  #
  # @param sexes [Array<Sex, NilClass>]
  # @param defcheck_index [Integer] Default.
  # @return [CheckedDisabled, NilClass]
  def self.index_boss(sexes, defcheck_index: CheckedDisabled::DEFCHECK_INDEX)
    significants = sexes.map.with_index{ |es, i|
      next nil if !es
      es.unknown? ? nil : i
    }.compact

    disabled = (1 == significants.size)
    if significants.empty?
      nil
    else
      iret = (significants.include?(defcheck_index) ? defcheck_index : significants.first)
      CheckedDisabled.new disabled: disabled, checked_index: iret
    end
  end

  # If allow_nil=true this returns false only when one is a male
  # and the other is a female. Else, this returns false also if other
  # is nil.
  #
  # Note thiw will not work if another significant {Sex} is added
  # in the DB.
  #
  # @param other [Sex]
  # @param allow_nil [Boolean] if nil, (nil, male) would return false.
  def not_disagree?(other, allow_nil: true)
    return allow_nil if other.nil?
    raise TypeError, "other is not Sex: #{other.inspect}" if !(Sex === other)
    sex9 = Sex[9]
    return true if [self, other].any?(&:unknown?) || [self, other].any?{|i| i == sex9}
    self == other
  end
end

class << Sex
  alias_method :create_basic_bwt!, :create_basic! if !self.method_defined?(:create_basic_bwt!)

  # Wrapper of {BaseWithTranslation.create_basic!}
  def create_basic!(*args, iso5218: nil, **kwds)
    create_basic_bwt!(*args, iso5218: (iso5218 || (rand(0.23)*1e6).to_i.to_s), **kwds)
  end
end


