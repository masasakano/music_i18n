# coding: utf-8

# == Schema Information
#
# Table name: places
#
#  id            :bigint           not null, primary key
#  note          :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  prefecture_id :bigint           not null
#
# Indexes
#
#  index_places_on_prefecture_id  (prefecture_id)
#
# Foreign Keys
#
#  fk_rails_...  (prefecture_id => prefectures.id) ON DELETE => cascade
#
class Place < BaseWithTranslation
  include Translatable
  belongs_to :prefecture
  has_one :country, through: :prefecture
  has_many :harami_vids
  has_many :artists, dependent: :restrict_with_exception
  has_many :musics,  dependent: :restrict_with_exception

  # For the translations to be unique.
  MAIN_UNIQUE_COLS = [:prefecture, :prefecture_id]

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" from "The Beatles".  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = true

  UnknownPlace = {
    "ja" => 'どこかの場所',
    "en" => 'UnknownPlace',
    "fr" => 'PlaceInconnue',
  }.with_indifferent_access
  UnknownPlace.default_proc = proc do |hash, key|
    (hash.keys.include? key.to_s) ? hash[key.to_s] : nil  # Symbol keys (langcode) are acceptable.
  end

  # Returns String names of the classes of instances that depend on this instance.
  #
  # @return [Array<String>]
  def children_class_names
    %i(harami_vids artists musics).map{ |eam|
      send(eam).empty? ? nil : eam.to_s.classify
    }.compact
  end

  # Returns true if this has any dependent child instances
  #
  def has_children?
    !children_class_names.empty?
  end

  # Information of "(Prefecture < Country-Code)" is added.
  # @return [String]
  def inspect
    return(super) if !prefecture
    pref = prefecture
    s_pref = pref.title(langcode: 'en', lang_fallback: true)
    country = pref.country
    if country
      s_country = country.iso3166_a3_code
      s_country = country.title if s_country.blank?
    end
    super.sub(/, prefecture_id: \d+/, '\0'+sprintf("(%s < %s)", s_pref, s_country))
  end

  # Modifying {BaseWithTranslation.[]}
  #
  # So it accepts {Prefecture} or {Country},
  # which is highly desirable to be given.
  #
  # @example for Japan (Country-Code=392 or JPN)
  #   Place[/都庁/, 'ja', true, Prefecture[13, Country[392]]]  # => '都庁'(alt_title) in Tokyo(iso3166_loc_code: 13)
  #   Place[/高松駅/, Country['JPN']] # => 高松駅 in 香川県(iso3166_loc_code: 37) providing there is no other (if there is another '高松駅', this may return an unexpected {Place}).
  #
  # @param value [Regexp, String] e.g., 'Tokyo'
  # @param langcode [String, NilClass, Country] like 'ja'. If nil, all languages
  # @param with_alt [Boolean, Country] if TRUE (Def: False), alt_title is ALSO searched.
  # @param pref [Prefecture]
  # @param cntry [Country]
  # @return [BaseWithTranslation, NilClass]
  def self.[](value, langcode=nil, with_alt=false, pref=nil, cntry=nil)
    ## Adjusts the arguments
    if langcode.respond_to?(:prefectures)
      cntry = langcode
      langcode = nil
    elsif langcode.respond_to?(:places)
      pref = langcode
      langcode = nil
    elsif with_alt.respond_to?(:prefectures)
      cntry = with_alt
      with_alt = false
    elsif with_alt.respond_to?(:places)
      pref = with_alt
      with_alt = false
    end

    wherepref = pref ? {prefecture: pref} : {}
    wherecnt = cntry ? {country: cntry} : {}
    if wherepref.empty? && wherecnt.empty?
      super(value, langcode, with_alt)
    elsif value.nil?
      find_all_without_translations.where(**(wherepref.merge wherecnt)).first
    else
      kwd = (with_alt ? :titles : :title)
      select_regex(kwd, value, langcode: langcode).select{|i| i.prefecture == pref || i.country == cntry}.first
    end
  end

  # Returns an unknown place somewhere
  #
  # @example anywhere in the world
  #    Place.unknown
  #
  # @example unknown place in Japan
  #    Place.unknown(country: 'JPN')
  #
  # @example unknown place in Tokyo
  #    Place.unknown(prefecture: '東京都')
  #
  # @example unknown place in Perth, UK
  #    Place.unknown(country: 'GBR', prefecture: 'Perth')
  #
  # @param country: [Country, NilClass, String] String as the registered English name.
  # @param prefecture: [Prefecture, NilClass, String] String as the registered Prefecture name.
  # @return [Place]
  def self.unknown(country: nil, prefecture: nil)
    if prefecture
      prefecture = Prefecture[prefecture] if !prefecture.respond_to? :places  # else, prefecture as given
    else
      prefecture = Prefecture.unknown(country: country)
    end
    select_by_translations({prefecture: prefecture}, **({en: {title: UnknownPlace['en']}})).first
  end


  # Returns true if self is one of the unknown places
  def unknown?
    title(langcode: 'en') == UnknownPlace['en']
  end

  # Unknown {Place} belonging to self
  #
  # @return [Place]
  def unknown_sibling
    self.prefecture.unknown_place
  end

  # Similar to #{encompass?} but returns false if self==other
  #
  # @param other [Place, Prefecture, Country]
  # @raise [TypeError] if other is none of {Country}, {Prefecture}, {Place}
  def encompass_strictly?(other)
    (self != other) && encompass?(other)
  end
  alias_method :coarser_than?, :encompass_strictly? if ! self.method_defined?(:coarser_than?)

  # True if self encompasses other
  #
  # For non-unknown Place, it returns true only if
  #
  # * self == other
  # * self.unknown? and belongs to the same or narrower prefecture
  #   * e.g., self.unknown[prefecture: Prefecture['Kagawa', 'en'] and other is Place['Takamatsu', 'en']
  #   * this returns false for the other way around (i.e., other.unknown?)
  #
  # @param other [Place, Prefecture, Country]
  # @raise [TypeError] if other is none of {Country}, {Prefecture}, {Place}
  def encompass?(other)
    raise TypeError, "(#{self.class.name}.#{__method__}) Contact the code developer. Argument has to one of Country, Prefecture, Place. but #{other.class.name}: other=#{other.inspect}" if !other.respond_to? :unknown?
    if other == self
      true
    elsif other.respond_to?(:prefectures) || other.respond_to?(:places)
      false  # other is Country or Prefecture
    else
      unknown? && self.prefecture.encompass?(other)
    end
  end

  # True if self is or may be a part of other.
  #
  # The inverse function of {#encompass_strictly?}
  #
  # @param other [Place, Prefecture, Country]
  # @raise [TypeError] if other is none of {Country}, {Prefecture}, {Place}
  def covered_by?(other)
    raise TypeError, "(#{self.class.name}.#{__method__}) Contact the code developer. Argument has to one of Country, Prefecture, Place. but #{other.class.name}: other=#{other.inspect}" if !other.respond_to? :encompass?
    other.encompass_strictly?(self)
  end

  # True if self is or may be a part of other.
  #
  # It differs from {#covered_by?} in handling for unknown?
  #
  # @param other [Place, Prefecture, Country]
  # @raise [TypeError] if other is none of {Country}, {Prefecture}, {Place}
  def covered_by_permissively?(other)
    raise TypeError, "(#{self.class.name}.#{__method__}) Contact the code developer. Argument has to one of Country, Prefecture, Place. but #{other.class.name}: other=#{other.inspect}" if !other.respond_to? :encompass?

    if other == self
      true
    elsif other.respond_to?(:prefectures) || other.respond_to?(:places)
      # other is Country or Prefecture
      self.prefecture.covered_by_permissively?(other)
    else
      # other is Place AND not identical to self
      # Example: if self is Place.unknown(prefecture: Prefecture['Kagawa', 'en']),
      #  this returns true for any Place in Prefecture['Kagawa', 'en'].
      (self.unknown? || other.unknown?) && self.prefecture.covered_by_permissively?(other.prefecture)
    end
  end

  # If allow_nil=true this returns false when other is nil.
  # Else, this returns true when other is nil.
  #
  # @param other [Genre]
  # @param allow_nil [Boolean] if nil, (nil, male) would return false.
  # @raise [TypeError] if other is non-nil and not Genre
  def not_disagree?(other, allow_nil: true)
    return allow_nil if other.nil?
    raise TypeError, "other is not a kind of Place (Prefecture/Country): #{other.inspect}" if !((Place === other) || (Prefecture === other) || (Country === other))
    covered_by_permissively?(other) || encompass?(other)
  end

  # Returns an Array of translation of the ascendants like [self, {Prefecture}, {Country}] 
  #
  # @example
  #   self.title_or_alt_ascendants(langcode: 'ja')
  #    # => ["Shijo", "Kyoto", "Japan"]
  #
  # @param langcode: [String, NilClass] like 'ja'
  # @param prefer_alt: [Boolean] if true (Def: false), alt_title is preferably
  #    returned as long as it exists.
  # @return [Array]
  def title_or_alt_ascendants(**kwd)
    [title_or_alt(**kwd), prefecture.public_send(__method__, **kwd)].flatten
  end

  # true if it has any desendants/children
  def has_descendants?
    return true if !artists.empty?
    return true if !musics.empty?
    return true if !harami_vids.empty?
    false
  end

  # Used in the class {CheckedDisabled}
  #
  # Return {CheckedDisabled}.
  # If one of them is {#covered_by?} the other, the index is used.
  # If there is none, returns nil.
  #
  # So far, accepts 2 elements only.
  #
  # @param sexes [Array<Sex, NilClass>]
  # @param defcheck_index [Integer] Default.
  # @return [CheckedDisabled, NilClass]
  def self.index_boss(places, defcheck_index: CheckedDisabled::DEFCHECK_INDEX)
    raise "Unsupported size=#{places.size}" if places.size != 2

    case places.compact.size
    when 0
      return nil
    when 1
      return CheckedDisabled.new(disabled: true, checked_index: places.find_index{|i| i})
    end

    disabled = true
    if places[0].covered_by? places[1]
      iret = 0
    elsif places[1].covered_by? places[0]
      iret = 1
    else
      # 2 places are unrelated.
      iret = defcheck_index
      disabled = false
    end

    CheckedDisabled.new disabled: disabled, checked_index: iret
  end


  # Validates if a {Translation} is unique within the parent ({Prefecture})
  #
  # Fired from {Translation}
  def validate_translation_callback(record)
    validate_translation_unique_within_parent(record)
  end
end
