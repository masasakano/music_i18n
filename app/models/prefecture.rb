# coding: utf-8

# == Schema Information
#
# Table name: prefectures
#
#  id                                                           :bigint           not null, primary key
#  end_date                                                     :date
#  iso3166_loc_code(ISO 3166-2:JP (etc) code (JIS X 0401:1973)) :integer
#  note                                                         :text
#  orig_note(Remarks by HirMtsd)                                :text
#  start_date                                                   :date
#  created_at                                                   :datetime         not null
#  updated_at                                                   :datetime         not null
#  country_id                                                   :bigint           not null
#
# Indexes
#
#  index_prefectures_on_country_id        (country_id)
#  index_prefectures_on_iso3166_loc_code  (iso3166_loc_code) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (country_id => countries.id) ON DELETE => cascade
#
class Prefecture < BaseWithTranslation
  include ModuleCountryLayered  # for more_significant_than?

  # define method "mname" et
  include ModuleMname

  # For the translations to be unique (required by BaseWithTranslation).
  MAIN_UNIQUE_COLS = [:country_id, :iso3166_loc_code]
  #MAIN_UNIQUE_COLS = [:country, :country_id, :iso3166_loc_code]

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" when "The Beatles" is passed.  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = true

  before_destroy :assess_destroy

  belongs_to :country
  has_many :places, dependent: :destroy # However, see {#assess_destroy}; in short, as long as there are non-unknown child Places, it cannot be destroyed unless force_destroy==true. Also, raise ActiveRecord::RecordNotDestroyed if any of the child places have Music or Artist.
  has_many :artists,     through: :places, dependent: :restrict_with_exception # as per place.rb
  has_many :musics,      through: :places, dependent: :restrict_with_exception # as per place.rb
  has_many :harami_vids, through: :places
  validates_uniqueness_of :iso3166_loc_code, allow_nil: true

  # If true, children Places are cascade-destroyed.  Otherwise, self is not
  # destroyed unless {Place.unknown} is the sole child {Place}.
  attr_accessor :force_destroy

  # iso3166_a3_code of Countries whose Prefectures are complete. Their Prefectures cannot be destroyed in default.
  COUNTRIES_WITH_COMPLETE_PREFECTURES = %w(JPN)

  UnknownPrefecture = {
    'en' => 'UnknownPrefecture',
    'ja' => 'どこかの都道府県',
    'fr' => 'ComtéInconnu',
  }.with_indifferent_access
  UnknownPrefecture.default_proc = proc do |hash, key|
    (hash.keys.include? key.to_s) ? hash[key.to_s] : nil  # Symbol keys (langcode) are acceptable.
  end

  alias_method :inspect_orig, :inspect if ! self.method_defined?(:inspect_orig) # Preferred to  alias :text_new :to_s
  include ModuleModifyInspectPrintReference

  # Information of "(Country-Code)" is added.
  redefine_inspect(cols_yield: %w(country), yield_nil: true){ |country, _, self_record|
    if country
      s_country = country.iso3166_a3_code
      s_country = country.title(langcode: 'en', lang_fallback: true) if s_country.blank?
    else
      s_country = 'nil'
    end
    sprintf("(%s), force_destroy: %s", s_country, self_record.force_destroy.inspect)
  }

  # Sets {Prefecture::REGEXP_IDENTIFY_MODEL} at the first call
  #
  # REGEXP_IDENTIFY_MODEL is a hash with the key of mname and contains the Regexps to identify existing (seeded) Model,
  # used by ModuleMname
  def self.regexp_identify_model
    if !const_defined?(:REGEXP_IDENTIFY_MODEL)
      const_set(:REGEXP_IDENTIFY_MODEL, {
                  london: [/ロンドン|\bLondon\b/, {where: {"prefectures.country_id" => Country["GBR"].id}}],  # (at the time of writing) you can directly find it with Prefecture.find_by(iso3166_loc_code: 12000007)
                  paris:  [/\bParis\b/,           {langcode: 'fr', where: {"prefectures.country_id" => Country["FRA"].id}}], # in French language
                }.with_indifferent_access)
    end
    REGEXP_IDENTIFY_MODEL
  end

  # Modifying {BaseWithTranslation.[]}
  #
  # So it also accepts iso3166_loc_code (Integer)
  # as the first parameter. Also, it accepts {Country}, given
  # in any of 2nd-4th arguments, which is highly desirable to be given.
  #
  # @example for Japan (Country-Code=392 or JPN)
  #   Prefecture[13, Country[392]]  # => Tokyo-to (iso3166_loc_code: 13)
  #   Prefecture[/東京/, Country[392]] # "'東京'" (String) would fail because it is "東京都"
  #   Prefecture['Tokyo', 'en', Country['JPN']]
  #   Prefecture['Kagawa', 'en', true, Country[392]] # b/c Kagawa is alt_title in English! (whereas Tokyo is title)
  #   Prefecture[/香川/, Country[392]] # => 香川県 (iso3166_loc_code: 37)
  #
  # @param value [Regexp, String] e.g., 'Tokyo'
  # @param langcode [String, NilClass, Country] like 'ja'. If nil, all languages
  # @param with_alt [Boolean, Country] if TRUE (Def: False), alt_title is ALSO searched.
  # @param cntry [Country]
  # @return [BaseWithTranslation, NilClass]
  def self.[](value, langcode=nil, with_alt=false, cntry=nil)
    ## Adjusts the arguments
    if langcode.respond_to?(:prefectures)
      cntry = langcode
      langcode = nil
    elsif with_alt.respond_to?(:prefectures)
      cntry = with_alt
      with_alt = false
    end

    wherecnt = cntry ? {country: cntry} : {}
    if value.respond_to?(:infinite?)
      self.where(**({iso3166_loc_code: value}.merge(wherecnt))).first
    elsif wherecnt.empty?
      super(value, langcode, with_alt)
    elsif value.nil?
      find_all_without_translations.where(**wherecnt).first
    else
      kwd = (with_alt ? :titles : :title)
      select_regex(kwd, value, langcode: langcode).select{|i| i.country == cntry}.first
    end
  end

  # Unknown Prefecture in the given country (or somewhere in the world)
  #
  # @example anywhere in the world
  #    Prefecture.unknown
  #
  # @example unknown prefecture in Japan
  #    Prefecture.unknown(country: 'JPN')
  #
  # @param country: [Country, NilClass, String] String as the registered English name.
  # @param prefecture: [Prefecture, NilClass, String] String as the registered Prefecture name.
  # @return [Prefecture]
  def self.unknown(country: nil)
    if country
      country = Country[country] if !country.respond_to? :prefectures  # else, country as given
    else
      country = Country.unknown
    end
    select_by_translations({country: country}, **({en: {title: UnknownPrefecture['en']}})).first
  end

  # Returns true if self is one of the unknown prefectures
  def unknown?
    title(langcode: 'en') == UnknownPrefecture['en']
  end

  # Unknown {Place} belonging to self
  #
  # @return [Place]
  def unknown_place
    places.joins(:translations).where("translations.langcode='en' AND translations.title = ?", Place::UnknownPlace['en']).first
  end

  # Unknown {Prefecture} belonging to self
  #
  # @return [Prefecture]
  def unknown_sibling
    self.country.unknown_prefecture
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
  # For example, Prefecture["Kagawa", "en"] encompasses
  #
  # * Prefecture["Kagawa", "en"]
  # * any {Place} in Prefecture["Kagawa", "en"]
  #
  # Or, {Prefecture.unknown(country: 'JPN')} encompasses any {Prefecture} and {Place} in Japan.
  # Or, {Prefecture.unknown} encompasses any {Prefecture} and {Place}.
  #
  # @param other [Place, Prefecture, Country]
  # @raise [TypeError] if other is none of {Country}, {Prefecture}, {Place}
  def encompass?(other)
    errmsg = "(#{self.class.name}.#{__method__}) Contact the code developer. Argument has to one of Country, Prefecture, Place. but #{other.class.name}: other=#{other.inspect}"
    raise TypeError, errmsg if !other.respond_to? :unknown?
    if other == self
      true
    elsif other.respond_to? :prefectures
      false  # other is Country
    elsif unknown? && self.country.encompass?(other)
      true  # self is Prefecture.unknown? and other is either Prefecture or Place
    elsif other.respond_to? :prefecture_id
      # other is Place (self is not "unknown")
      # NOTE: if self is Kagawa, and the prefecture of other (Place) is unknown?, this returns false.
      other.prefecture == self
    elsif other.respond_to? :country_id
      # other is Prefecture and is not self (and self is not "unknown")
      # NOTE: if self is Kagawa, and if other satisfies Prefecture.unknown?, this returns false.
      false
    else
      raise TypeError, errmsg  # Other has the method :unknown? but not Country-Place-type.
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
    raise TypeError, "(#{self.class.name}.#{__method__}) Contact the code developer. Argument has to one of Country, Prefecture, Place. but #{other.class.name}: other=#{other.inspect}" if !other.respond_to? :unknown?

    if other == self
      true
    elsif other.respond_to?(:prefectures)
      # other is Country
      self.country.unknown? || self.country == other || other.unknown?
    elsif other.respond_to?(:prefecture)
      # other is Place
      (self.country.encompass?(other) || other.country.unknown?) && other.prefecture.unknown? || (self == other.prefecture && other.unknown?)
    else
      # other is Prefecture AND not identical to self
      (self.country.encompass?(other) || other.country.unknown?) && (self.unknown? || other.unknown?)
      # Note that
      # (1) JPN>Tokyo is     covered_by Unknown>UnknownPrefecture
      # (2) JPN>Tokyo is NOT covered_by Unknown>Tokyo
    end
  end

  # Returns 3-element Array of 0 or 1.
  #
  # 1st, 2nd, 3rd elements correspond to Country, Prefecture, Place.
  # If one is unknown it is 0, else 1.
  #
  # @return [Array<Integer>]
  def layered_significances
    [country.layered_significances.first, (unknown? ? 0 : 1), 0]
  end

  # Returns an Array of translation of the ascendants like [self, {Country}] 
  #
  # @example
  #   self.title_or_alt_ascendants(langcode: 'ja')
  #    # => ["Kyoto", "Japan"]
  #
  # @param langcode: [String, NilClass] like 'ja'
  # @param prefer_alt: [Boolean] if true (Def: false), alt_title is preferably
  #    returned as long as it exists.
  # @return [Array]
  def title_or_alt_ascendants(**kwd)
    [title_or_alt(**kwd), country.title_or_alt(**kwd)]
  end

  # Adds Place(UnknownPlaceXxx) after the first Translation creation of Prefecture
  #
  # Called by an after_create callback in translation.rb
  def after_first_translation_hook
    hstrans = best_translations
    hs2pass = {}
    Place::UnknownPlace.each_pair do |lc, ea_title|
      # lc = 'en' if !Place::UnknownPlace.keys.include?(lc)
      # # cname = (ev.title || ev.alt_title)  # Country name
      hs2pass[lc] = {
        title: ea_title,
        langcode: lc,
        is_orig:  (hstrans.key?(lc) && hstrans[lc].respond_to?(:is_orig) ? hstrans[lc].is_orig : nil),
        weight: 0,
      }
    end

    Place.create_with_translations!({prefecture: self}, **({translations: hs2pass}))
  end


  # Validates if a {Translation} is unique within the parent ({Country})
  #
  # Fired from {Translation}
  def validate_translation_callback(record)
    validate_translation_unique_within_parent(record)
  end


  # true if it can be destroyed (if with a sufficient privilege)
  #
  # {#destroy} is executed by the Controller only when
  #
  # 1. {#force_destroy} is set true (n.b., there is no circumstances where this is used at the time of writing),
  #    * In this case, all associated Places and Translations would be cascade-destroyed
  # 2. self has only zero or one child ({Place.unknown})
  #    * This should not happen over the web interface but could happen with manualmanipulations
  #      when a new {Prefecture} is just created with no associated {Translation}
  #      because the associated {Place.unknown} is created (automatically with
  #      {#after_first_translation_hook}) only when the first {Translation} is
  #      assigned to the new {Prefecture}.
  #
  # This method assesses it.
  #
  # If it is not destroyable, a message is added to {#errors}, unless +with_msg: false+ is specified (n.b., I cannot think of any cases where the option is absolutely necessary in fact, though errors are certainly *unnecessary* in some cases like in Views).
  #
  # Note that when self has only 1 {Place} child, it should be in principle
  # {Place.unknown} but there is no database-level restriction to
  # guarantee it and hence the child {Place} could be something else.
  # This routine does not check {Place#unknown}
  #
  # All places in a country in {COUNTRIES_WITH_COMPLETE_PREFECTURES} should
  # not be easily destroyed. However, model does not care about it and
  # the control is delegated to the Controller.
  #
  # @param with_msg [Boolean] if true (Def), an error message is added.
  def destroyable?(with_msg: true)
    return true if force_destroy

    #countries = COUNTRIES_WITH_COMPLETE_PREFECTURES.map{|i| Country[i]}.compact
    return true if (places.size <= 1)

    # errors.add :base, "Destroy failed. Prefecture has significant non-unknown child Places. Delete them first." if with_msg
    errors.add :base, "Destroy failed. Prefecture has significant non-unknown child Places. Delete them first. #{places.inspect}" if with_msg
    false
  end

  # Returns true if the set of all Prefectures that belong to the same {Country} is complete.
  def all_prefectures_fixed?
    COUNTRIES_WITH_COMPLETE_PREFECTURES.map{|i| Country[i]}.compact.any?{|i| i == country}
  end

  private

  # Callback to assess if {#destroy} can be executed
  #
  # abort +destroy+ with {#errors} set if {#destroyable?} is false.
  #
  def assess_destroy
    if destroyable?
      return true
    else
      throw :abort
    end
  end

end
