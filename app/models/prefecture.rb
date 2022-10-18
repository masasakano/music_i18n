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
  include Translatable
  belongs_to :country
  has_many :places, dependent: :destroy
  validates_uniqueness_of :iso3166_loc_code, allow_nil: true

  # For the translations to be unique.
  MAIN_UNIQUE_COLS = [:country, :country_id, :iso3166_loc_code]

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" from "The Beatles".  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = true

  UnknownPrefecture = {
    'ja' => 'どこかの都道府県',
    'en' => 'UnknownPrefecture',
    'fr' => 'ComtéInconnu',
  }
  UnknownPrefecture.default_proc = proc do |hash, key|
    (hash.keys.include? key.to_s) ? hash[key.to_s] : nil  # Symbol keys (langcode) are acceptable.
  end

  # Information of "(Country-Code)" is added.
  # @return [String]
  def inspect
    s_country = country.iso3166_a3_code
    s_country = country.title(langcode: 'en', lang_fallback: true) if s_country.blank?
    super.sub(/, country_id: \d+/, '\0'+sprintf("(%s)", s_country))
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
  # @return [Place]
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
    #        t2.title as title2, p2.note as note2, p1.country_id as pcid1, p2.country_id as pcid2
    #  FROM translations t1
    #  INNER JOIN prefectures p1 ON (t1.translatable_id = p1.id)
    #  RIGHT JOIN translations t2 ON t1.translatable_type = t2.translatable_type
    #  RIGHT JOIN prefectures p2 ON (t2.translatable_id = p2.id)
    #  WHERE t1.translatable_type = 'Prefecture' AND t1.id = 566227874 AND p1.country_id = p2.country_id;
    #
    ### The 1st process of the following is to get country_id in Prefecture from record (Translation):
    ###   record.translatable.country_id
    ### The 2nd process would produce a SQL something similar to
    #
    # SELECT t.id as tid, p.id as pid, t.translatable_type, t.langcode,
    #        t.title, p.note as note, p.country_id as pcid1
    #   FROM translations t
    #   INNER JOIN prefectures p ON translations.translatable_id = prefectures.id
    #   WHERE translations.translatable_type = 'Prefecture' AND prefectures.country_id = :countryid AND
    #         translations.id <> :translationid" AND translations.langcode = :lang
    #   {countryid: record.translatable.country_id, translationid: record.id, lang: record.langcode}
    #
    ### In Rails console (irb),
    #
    # Translation.joins('INNER JOIN prefectures ON translations.translatable_id = prefectures.id').
    #   where(translatable_type: 'Prefecture').
    #   where(langcode: record.langcode).
    #   where("prefectures.country_id = :countryid AND translations.id <> :translationid",
    #          countryid: record.translatable.id, translationid: record.id)
    #

    # Gets all the Translation of Prefecture belonging to the same Country but the one for self
    joinscond = "INNER JOIN prefectures ON translations.translatable_id = prefectures.id"
    whereconds = []
    whereconds << ["prefectures.country_id = ?", record.translatable.country_id]
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
      klasses = self.class.reflect_on_all_associations(:belongs_to).map{|i| i.klass.name}  # => "Country"
      logger.warning "(#{__method__}) More than one class to belong to from #{self.class}" if klasses.size > 1
      obj_grand_parent = (record.translatable.country || klasses[0]) 
      msg = sprintf("%s=%s (%s) already exists in %s for %s in %s(%s).",
                    method.to_s,
                    current.inspect,
                    record.langcode,
                    record.class.name,
                    self.class.name,
                    (obj_grand_parent.respond_to?(:gsub) ? obj_grand_parent : obj_grand_parent.class.name),
                    (obj_grand_parent.titles.compact[0].inspect rescue '"No titles"')
                   )
      return [msg]
    end
    return []
  end

end
