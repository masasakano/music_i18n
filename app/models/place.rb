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
  }
  UnknownPlace.default_proc = proc do |hash, key|
    (hash.keys.include? key.to_s) ? hash[key.to_s] : nil  # Symbol keys (langcode) are acceptable.
  end

  # Information of "(Prefecture < Country-Code)" is added.
  # @return [String]
  def inspect
    pref = prefecture
    country = pref.country
    s_country = country.iso3166_a3_code
    s_country = country.title if s_country.blank?
    s_pref = pref.title(langcode: 'en', lang_fallback: true)
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

  # Validates translation immediately before it is added.
  #
  # Called by a validation in {Translation}
  #
  # In short, if {Translation#title} (or {Translation#alt_tiele} if title is nil)
  # is not unique within the same 
  #
  # Note: {Translation}.joins(:translatable) would lead to ActiveRecord::EagerLoadPolymorphicError
  #  as of Ruby 6.0.
  #
  # @param record [Translation]
  # @return [Array] of Error messages, or empty Array if everything passes
  def validate_translation_callback(record)
    msg = msg_validate_double_nulls(record)
    return [msg] if msg

    ### To achieve with a single SQL query, the following is the one??
    ### It is too much (and Rails does not support RIGHT JOIN)
    ### and hence 2 SQL queries are used in this method.
    #
    # SELECT t1.id as tid, t2.id as tid2, t1.translatable_type, t1.langcode,
    #        t2.title as title2, p2.note as note2, p1.prefecture_id as pcid1, p2.prefecture_id as pcid2
    #  FROM translations t1
    #  INNER JOIN places p1 ON (t1.translatable_id = p1.id)
    #  RIGHT JOIN translations t2 ON t1.translatable_type = t2.translatable_type
    #  RIGHT JOIN places p2 ON (t2.translatable_id = p2.id)
    #  WHERE t1.translatable_type = 'Place' AND t1.id = 566227874 AND p1.prefecture_id = p2.prefecture_id;
    #
    ### The 1st process of the following is to get prefecture_id in Place from record (Translation):
    ###   record.translatable.prefecture_id
    ### The 2nd process would produce a SQL something similar to
    #
    # SELECT t.id as tid, p.id as pid, t.translatable_type, t.langcode,
    #        t.title, p.note as note, p.prefecture_id as pcid1
    #   FROM translations t
    #   INNER JOIN places p ON translations.translatable_id = places.id
    #   WHERE translations.translatable_type = 'Place' AND places.prefecture_id = :prefectureid AND
    #         translations.id <> :translationid" AND translations.langcode = :lang
    #   {prefectureid: record.translatable.prefecture_id, translationid: record.id, lang: record.langcode}
    #
    ### In Rails console (irb),
    #
    # Translation.joins('INNER JOIN places ON translations.translatable_id = places.id').
    #   where(translatable_type: 'Place').
    #   where(langcode: record.langcode).
    #   where("places.prefecture_id = :prefectureid AND translations.id <> :translationid",
    #          prefectureid: record.translatable.id, translationid: record.id)
    #

    # Gets all the Translation of Place belonging to the same Prefecture but the one for self
    joinscond = "INNER JOIN places ON translations.translatable_id = places.id"
    whereconds = []
    whereconds << ["places.prefecture_id = ?", record.translatable.prefecture_id]
    whereconds << [(record.id ? ['translations.id <> ?', record.id] : nil)]
    alltrans = self.class.select_translations_regex(
      nil,
      nil,
      where: whereconds,
      joins: joinscond,
      langcode: record.langcode
    )

    tit     = record.title
    alt_tit = record.alt_title
    method  = (tit ? :title : :alt_title) # The method Symbol to check out (usually :title, unless nil)
    current = (tit ?  tit   :  alt_tit)   # The method name

    if alltrans.any?{|i| i.send(method) == current}
      klasses = self.class.reflect_on_all_associations(:belongs_to).map{|i| i.klass.name}  # => "Prefecture"
      logger.warning "(#{__method__}) More than one class to belong to from #{self.class}" if klasses.size > 1
      msg = sprintf("%s=%s (%s) already exists in %s for %s in %s.",
                    method.to_s,
                    current.inspect,
                    record.langcode,
                    record.class.name,
                    self.class.name,
                    klasses[0])
      return [msg]
    end
    return []
  end
end
