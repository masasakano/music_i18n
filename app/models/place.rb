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
  include ModuleCountryLayered  # for more_significant_than?

  # define method "mname" et
  include ModuleMname

  # for set_singleton_unknown
  include ModuleSetSingletonUnknown

  # For the translations to be unique (required by BaseWithTranslation).
  MAIN_UNIQUE_COLS = [:prefecture, :prefecture_id]

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" when "The Beatles" is passed.  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = true

  belongs_to :prefecture
  has_one :country, through: :prefecture
  has_many :harami_vids
  has_many :artists, dependent: :restrict_with_exception
  has_many :musics,  dependent: :restrict_with_exception
  has_many :event_items
  has_many :events
  has_many :events_thru_event_items, -> {distinct}, through: :event_items, source: :event

  UnknownPlace = {
    "en" => 'UnknownPlace',
    "ja" => 'どこかの場所',
    "fr" => 'PlaceInconnue',
  }.with_indifferent_access
  #UnknownPlace.default_proc = proc do |hash, key|
  #  (hash.keys.include? key.to_s) ? hash[key.to_s] : nil  # Symbol keys (langcode) are acceptable.
  #end

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

  alias_method :inspect_orig, :inspect if ! self.method_defined?(:inspect_orig) # Preferred to  alias :text_new :to_s
  include ModuleModifyInspectPrintReference

  # Information of "(Prefecture < Country-Code)" is added.
  redefine_inspect(cols_yield: %w(prefecture)){ |pref, _|
    s_pref = pref.title(langcode: 'en', lang_fallback: true)
    country = pref.country
    if country
      s_country = country.iso3166_a3_code
      s_country = country.title if s_country.blank?
    end
    sprintf("(%s < %s)", s_pref, s_country)
  }

  # Sets {Place::REGEXP_IDENTIFY_MODEL} at the first call
  #
  # REGEXP_IDENTIFY_MODEL is a hash with the key of mname and contains the Regexps to identify existing (seeded) Model,
  # used by ModuleMname
  def self.regexp_identify_model
    if !const_defined?(:REGEXP_IDENTIFY_MODEL)
      const_set(:REGEXP_IDENTIFY_MODEL, {
                  default_streaming: /^ハラミ(ちゃん)?自宅|\bHARAMIchan's home\b/i,
                  default_harami_vid: Place.unknown(country: Rails.application.config.primary_country),
                }.with_indifferent_access)
    end
    REGEXP_IDENTIFY_MODEL
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

  # returns a minimal covering place.
  #
  # @example
  #   tocho = places(:tocho)
  #   Place.minimal_covering_place(tocho, tocho)
  #     # => tocho
  #   Place.minimal_covering_place(tocho, tocho, akihabara)
  #     # => prefectures(:tokyo).unknown_place
  #   Place.minimal_covering_place(tocho, tocho, takamatsu_station)
  #     # => countries(:japan).unknown_place
  #   Place.minimal_covering_place(tocho, tocho, liverpool)
  #     # => places(:world)
  #   Place.minimal_covering_place(nil, tocho, tocho)
  #     # => places(:world)
  #
  # @param places [Array<Place, NilClass>] 
  # @return [Place] minimal covering one. Place.unknown is returned if no arguments are given
  def self.minimal_covering_place(*places)
    return Place.unknown if places.empty?

    pla_unk = Place.unknown
    places = places.map{|pla| pla ? pla : pla_unk}.reduce{|covering, pla|
      if covering == pla || covering.encompass?(pla)
        covering
      elsif !covering.unknown? && (pref=covering.prefecture).encompass?(pla)
        pref.unknown_place
      elsif (cntr=covering.country).encompass?(pla)
        cntr.unknown_prefecture.unknown_place
      else
        Place.unknown
      end
    }
  end

  # Similar to #{encompass?} but returns false if self==other
  #
  # Note that if it is compared with an equivalent Object at a child-level, it returns true,
  # whereas comparison with a parent-level returns false.
  #
  #   (cnt=Country["JPN"]).encompass_strictly?(pref=cnt.unknown_prefecture)
  #     # => true
  #   pref.encompass_strictly?(cnt)
  #     # => false
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

  # Returns 3-element Array of 0 or 1.
  #
  # 1st, 2nd, 3rd elements correspond to Country, Prefecture, Place.
  # If one is unknown it is 0, else 1.
  #
  # @return [Array<Integer>]
  def layered_significances
    prefecture.layered_significances[0..1] + [(unknown? ? 0 : 1)]
  end

  # Returns an Array of translation of the ascendants like [self, {Prefecture}, {Country}] 
  #
  # @example
  #   self.title_or_alt_ascendants(langcode: 'en')
  #    # => ["Shijo", "Kyoto", "Japan"]
  #
  # @param langcode: [String, NilClass] like 'ja'
  # @param prefer_alt: [Boolean] if true (Def: false), alt_title is preferably
  #    returned as long as it exists.
  # @return [Array]
  def title_or_alt_ascendants(set_singleton: false, **kwd)
    ret = [title_or_alt(**kwd), prefecture.public_send(__method__, set_singleton: set_singleton, **kwd)].flatten
    return ret if !set_singleton

    set_singleton_unknown(ret[0]) # defined in ModuleSetSingletonUnknown
    ret
  end

  # Returns a String of "Prefecture - Place (Country)" where some may be missing
  #
  # {ModuleCommon#txt_place_pref_ctry} is a wrapper of this.
  # See also {PlacesHelper#show_pref_place_country}
  #
  # @example
  #   self.pref_pla_country_str(langcode: nil, prefer_shorter: false)  # Default option
  #     # => "Liverpool — The Square (the United Kingdom of Great Britain and Northern Ireland)"
  #
  # @param without_country_maybe: [Boolean] if true (Def: false), the country information is not printed unless that is the only information or the country is not in the default country. This is mainly used for HaramiVid.
  # @param langcode: [String, NilClass] like 'ja'
  # @param prefer_alt: [Boolean] if true (Def: false), alt_title is preferably
  #    returned as long as it exists.
  # @return [String]
  def pref_pla_country_str(str_ascendants: nil, without_country_maybe: false, **kwd)
    return pref_pla_country_str_from_ascendants(str_ascendants, langcode: kwd[:langcode]) if str_ascendants.present? && !str_ascendants.first.respond_to?(:unknown?)

    ar = (str_ascendants.present? ? str_ascendants : [self, self.prefecture, self.country].map{|model| model.title_or_alt(**kwd)}).map{|i| definite_article_to_head(i)} # defined in module_common.rb
    ar[1] = "" if prefecture.unknown?
    ar[0] = (unknown? ? "" : '— '+ar[0]+' ')

    with_country = (!without_country_maybe || (ar[1].blank? && unknown?) || !country.primary?)
    _ascendants3_to_str(ar, with_country: with_country)
  end

  # @param with_country: [Boolean] If false (Def: true), Country is not printed.
  # @return [Array]
  def _ascendants3_to_str(arstr_prepared, with_country: true)
    # sprintf '%s %s(%s)', ar[1], ((ar[1] == Prefecture::UnknownPrefecture[I18n.locale] || ar[0].blank?) ? '' : '— '+ar[0]+' '), ar[2]  # old specs
    if with_country
      sprintf '%s %s(%s)', arstr_prepared[1], arstr_prepared[0], arstr_prepared[2]
    else
      sprintf '%s %s',     arstr_prepared[1], arstr_prepared[0]
    end
  end
  private :_ascendants3_to_str

  # Legacy one, where this manages to find whether it is {#unknown?} or not from String.
  #
  # @example
  #   ar = places(:bodokan).place.title_or_alt_ascendants(langcode: I18n.locale, lang_fallback_option: :either, prefer_shorter: true)
  #   self.pref_pla_country_str_from_ascendants(ar, langcode: I18n.locale)
  #     # => "Liverpool — The Square (the United Kingdom of Great Britain and Northern Ireland)"
  #
  # @return [String]
  def pref_pla_country_str_from_ascendants(str_ascendants, langcode: I18n.locale)
    ar = str_ascendants.map{|i| definite_article_to_head(i)} # defined in module_common.rb
    if ((Prefecture::UnknownPrefecture[langcode] == ar[1]) || ar[1].blank?)
      ar[1] = ""
    end
    if ((Place::UnknownPlace[langcode] == ar[0]) || ar[0].blank?)
      ar[0] = ""
    else
      ar[0] = '— '+ar[0]+' '
    end

    _ascendants3_to_str(ar)
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
