# coding: utf-8

# == Country
#
# * encompass?
# * covered_by?
# * equivalent?
#
# Concept of inclusiveness is defined as follows.
#
# The relations are expressed with
#
# * {#equivalent}
# * {#separate_from}
# * {#equivalent}
# * {#covered_by}
# * {#covered_by_strictly}
# * {#encompass}
# * {#encompass_strictly}
# * {#narrower_than}
#
# with use of
#
# * {#widest_significant}
# * {#narrowest_significant}
#
# Here is the description:
#
# * If the two areas are equal (=) they are {#equivalent} to each other.
#   If a {Place} is {#unknown?}, it is {#equivalent} to its {Prefecture} and so on.
#   As such {Place.unknown} is treated just as its {Prefecture} because that is the best information available.
#   For example, {Place.unknown} in {Prefecture.unknown} in {Country.unknown} {#encompass} anywhere in the world though
#   {#encompass}(ignore_world: true) nowhere in the world.
# * If an entity or one or more of its ancestor areas is {#unknown?}, it has 0 to 2 {#equivalent} entities.
#   Among those, the uppermost hierarchy
#   is {#widest_significant}; e.g., {#widest_significant} of {Prefecture.unknown} in {Country}['JPN'] is
#   {Country}['JPN']. {#widest_significant} of {Country.unknown} in {Country}['JPN'] is
# * The first entity of itself or its ancestor is not {#unknown?} the first one is {#narrowest_significant}
# * If two entities are definitely in separate regions, they are {#separate_from} each other.
#   For example, {Prefecture} in China is {#separate_from} {Country} Japan.
#   Conversely, if there is a chance they are not completely separate, it is not.
#   For example, a {Prefecture.unknown} in {Country.unknown} is not {#separate_from} {Place} of Asakusa.
#   However, a {Prefecture}(Kagawa) in {Country.unknown} is {#separate_from} {Place} of Asakusa in {Prefecture}(Tokyo)
#   because Asakusa is not in {Prefecture}(Kagawa) regardless of its {Country}.
# * If two areas are not {#separate_from} each other, one of them is {#covered_by} the other and the other {#encompass}
#   the one. Vice versa holds if they are {#equivalent} to each other but neither is unknown. If they are {#equivalent}
#   to each other but one of them is unknown, the Place/Prefecture/Country relation in {#widest_significant} and then
#   {#narrowest_significant} determines which one holds;
#   e.g., {Country}(Japan) {#encompass} {Prefecture.unknown} in Japan. Or, {Prefecture}(Tokyo) is
#   {#covered_by} {Prefecture.unknown} in {Country}(Japan).
# * When one is {#covered_by}(ignore_world: true) the other, the one is {#narrower_than} the other.
#
#
#
# For s0 = {Prefecture}['Tokyo']
# and p0 = {Place}['Asakusa'] in s0  (Asakusa < Tokyo < JPN)
# p0 is NOT separate_from s0, and vice versa (s0 is NOT).
# p0 is NOT separate_from {Country}['JPN'] or {Country.unknown}.
# p0 is covered_by s0
#
# For p1 = {Place.unknown}(prefecture: s0)  (Unknown < Tokyo < JPN)
# p1 is NOT separate_from p0 or {Country}['JPN'], and vice versa (p0 is NOT).
# p1 is equivalent to s0 ({Prefecture}(Tokyo)), hence is also covered by s0.
# p1 is covered by strictly {Country}['JPN'] and {Prefecture}['Tokyo'].
# p1 encompass p0 maybe, but NOT strictly.
# p1 is NOT covered by p0
# p0 is covered by p1 maybe, but NOT strictly.
# p0 does NOT encompass p1.
# p1 is narrower_than s0(Tokyo)
# p0 is narrower_than p1
#
# For s2 = {Prefecture.unknown}(country: {Country}['JPN'])
# and p2 = {Place.unknown}(prefecture: s2)
# s2 or p2 is NOT separate_from {Country}['JPN']
# both s2 and p2 are equivalent (though not equal(=)) to {Country}['JPN'], hence is covered by stryctly it.
# p2 is covered by s2.
# s2 is NOT covered by p2.
#
# For p3 = {Place}['Tanaka'] in {Prefecture} s2,
# p3 are covered_by {Country}['JPN'] but not equivalent.
#
# For s4 = {Prefecture.unknown}(country: {Country.unknown}) and
# p4 = {Place.unknown}(prefecture: s4)
# both s4 and p4 are equivalent (though not equal(=)) to {Country.unknown}, hence is covered by it.
#
# If a p1 = {Place}(unknown) belongs to {Prefecture}(),
# p1 is equivalent to {Prefecture}(Tokyo), hence is covered by it.
#
# * 
# * covered_by?
# World
#
#
#
# == Schema Information
#
# Table name: countries
#
#  id                                                   :bigint           not null, primary key
#  end_date                                             :date
#  independent(Independent in ISO-3166-1)               :boolean
#  iso3166_a2_code(ISO-3166-1 Alpha 2 code, JIS X 0304) :string
#  iso3166_a3_code(ISO-3166-1 Alpha 3 code, JIS X 0304) :string
#  iso3166_n3_code(ISO-3166-1 Numeric code, JIS X 0304) :integer
#  iso3166_remark(Remarks in ISO-3166-1, 2, 3)          :text
#  note                                                 :text
#  orig_note(Remarks by HirMtsd)                        :text
#  start_date                                           :date
#  territory(Territory name in ISO-3166-1)              :text
#  created_at                                           :datetime         not null
#  updated_at                                           :datetime         not null
#  country_master_id                                    :bigint
#
# Indexes
#
#  index_countries_on_country_master_id  (country_master_id)
#  index_countries_on_iso3166_a2_code    (iso3166_a2_code) UNIQUE
#  index_countries_on_iso3166_a3_code    (iso3166_a3_code) UNIQUE
#  index_countries_on_iso3166_n3_code    (iso3166_n3_code) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (country_master_id => country_masters.id) ON DELETE => restrict
#
class Country < BaseWithTranslation
  include Translatable
  include Rails.application.routes.url_helpers

  belongs_to :country_master, optional: true  # e.g., Country.unknown does not have a Parent.
  has_many :prefectures, dependent: :destroy
  validates_uniqueness_of :iso3166_n3_code, allow_nil: true

  # For the translations to be unique.
  MAIN_UNIQUE_COLS = %i(iso3166_a2_code iso3166_a3_code iso3166_n3_code)

  # This should be updated later!!!
  #
  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" from "The Beatles".  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = false  # should be true, ideally...

  UnknownCountry = {
    'ja' => '世界',
    'en' => 'World',
    'fr' => 'Monde',
  }
  UnknownCountry.default_proc = proc do |hash, key|
    (hash.keys.include? key.to_s) ? hash[key.to_s] : nil  # Symbol keys (langcode) are acceptable.
  end

  class << self
    alias_method :bracket_orig, :[] if ! self.method_defined?(:bracket_orig)
  end

  # Modifying {BaseWithTranslation.[]}
  #
  # So it also accepts iso3166_n3_code (Integer) or iso3166_a2_code (String) or
  # iso3166_a3_code (String) as the first (and only) parameter.
  #
  # @example for UK
  #   Country['GB']
  #   Country['GBR']
  #   Country[826]
  #
  # @param value [Regexp, String] e.g., 'male'
  # @param langcode [String, NilClass] like 'ja'. If nil, all languages
  # @param with_alt [Boolean] if TRUE (Def: False), alt_title is ALSO searched.
  # @return [BaseWithTranslation, NilClass]
  def self.[](value, langcode=nil, with_alt=false)
    if value.respond_to?(:infinite?)
      self.find_by(iso3166_n3_code: value)
    elsif value.respond_to?(:gsub) && /\A([A-Z]{2,3})\z/ =~ value
      kwd = (($1.size == 2) ? :iso3166_a2_code : :iso3166_a3_code)
      self.find_by(kwd => value)
    else
      super(value, langcode, with_alt)
    end
  end

  # Returns the unknown {Country}
  #
  # @return [Country]
  def self.unknown
     self[UnknownCountry['en'], 'en']
  end

  # Returns true if self is one of the unknown country
  def unknown?
    title(langcode: 'en') == UnknownCountry['en']
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
  # For example, Country["Japan", "en"] encompasses
  #
  # * Country["Japan", "en"]
  # * any Prefecture in Country["Japan", "en"]
  # * any Place in any prefecture in Country["Japan", "en"]
  #
  # but nothing else.
  # Or, {Country.unknown} encompasses any {Country}, {Prefecture}, {Place}
  #
  # @param other [Place, Prefecture, Country]
  # @raise [TypeError] if other is none of {Country}, {Prefecture}, {Place}
  def encompass?(other)
    raise TypeError, "(#{self.class.name}.#{__method__}) Contact the code developer. Argument has to one of Country, Prefecture, Place. but #{other.class.name}: other=#{other.inspect}" if !other.respond_to? :unknown?
    if other == self
      true
    elsif unknown?
      true  # self is Country["World", "en"] 
    elsif other.respond_to? :country
      # other is Prefecture
      # NOTE: if self is Japan, and other is Prefecture.unknown (in World), this returns false.
      other.country == self
    elsif other.respond_to? :prefecture
      encompass?(other.prefecture)
    else
      false
    end
  end

  # True if self is or is a part of other.
  #
  # The inverse function of {#encompass_strictly?}
  # In short, this returns TRUE only if other is {Country.unknown}()
  # and !self.{#unknown?}  Else FALSE.
  #
  # @param other [Place, Prefecture, Country]
  # @raise [TypeError] if other is none of {Country}, {Prefecture}, {Place}
  def covered_by?(other)
    raise TypeError, "(#{self.class.name}.#{__method__}) Contact the code developer. Argument has to one of Country, Prefecture, Place. but #{other.class.name}: other=#{other.inspect}" if !other.respond_to? :encompass?
    other.encompass_strictly?(self)
  end

  # True if self is or MAY BE a part of other.
  #
  # This is more permissive than {#covered_by?} in terms of handling of
  # "unknown".  For example, if self is Country['UK'],
  #
  #   self.covered_by_permissively?(Country.unknown)  # => true
  #   self.covered_by?(Country.unknown)               # => false
  #
  # @param other [Place, Prefecture, Country]
  # @raise [TypeError] if other is none of {Country}, {Prefecture}, {Place}
  def covered_by_permissively?(other)
    raise TypeError, "(#{self.class.name}.#{__method__}) Contact the code developer. Argument has to one of Country, Prefecture, Place. but #{other.class.name}: other=#{other.inspect}" if !other.respond_to? :unknown?

    if !other.respond_to?(:prefectures)
      false
    elsif self == other || self.unknown? || other.unknown?
      true
    else
      false
    end
  end

  # Adds Prefecture(UnknownPrefectureXxx) after the first Translation creation of Country
  #
  # Called by an after_create callback in {Translation}
  #
  # @return [Prefecture]
  def after_first_translation_hook
    hstrans = best_translations
    hs2pass = {}
    Prefecture::UnknownPrefecture.each_pair do |lc, ea_title|
      # lc = 'en' if !Prefecture::UnknownPrefecture.keys.include?(lc)
      # # cname = (ev.title || ev.alt_title)  # Country name
      hs2pass[lc] = {
        title: ea_title,
        langcode: lc,
        is_orig:  (hstrans.key?(lc) && hstrans[lc].respond_to?(:is_orig) ? hstrans[lc].is_orig : nil),
        weight: 0,
      }
    end

    Prefecture.create_with_translations!({country: self}, translations: hs2pass)
  end

  # Validates translation immediately before it is added.
  #
  # Called by a validation in {Translation}
  #
  # @param record [Translation]
  # @return [Array] of Error messages, or empty Array if everything passes
  def validate_translation_callback(record)
    msg = msg_validate_double_nulls(record)
    return [msg] if msg

    tit     = record.title
    alt_tit = record.alt_title

    options = {}

    # All the Translation of Country but the one for self
    wherecond = []
    wherecond.push ['id <> ?', record.id] if record.id  # All the Translation of Country but the one for self (except in create)
    options[:langcode] = record.langcode if record.langcode
    alltrans = self.class.select_translations_regex(nil, nil, where: wherecond, **options)

    method  = (tit ? :title : :alt_title)
    current = (tit ?  tit   :  alt_tit)

    if alltrans.any?{|i| i.send(method) == current}
      msg = sprintf("%s=%s (%s) already exists in %s for %s.",
                    method.to_s,
                    current.inspect,
                    record.langcode,
                    record.class.name,
                    self.class.name)
      return [msg]
    end
    return []
  end

  # Return a HTML link to {CountryMaster} if exists. Maybe an emtpy string.
  #
  # @return [String] it is "html_safe"-ed.
  def link_to_master(**opts)
    master = country_master
    return "" if !master

    tit_master = master.slice(*(%i(name_ja_full name_ja_short name_en_full name_en_short))).values.map{|i| i.blank? ? '' : i}
    tit_self   = %w(ja en).map{ |elc| %i(title alt_title).map{|method| send(method, langcode: elc)}}.flatten.map{|i| i.blank? ? '' : i}
    is_consistent = tit_master.zip(tit_self).all?{|ec| ec[0].blank? || (ec[0] == ec[1])}

    ActionController::Base.helpers.link_to((is_consistent ? 'Same' : 'Differ'), country_master_path(master), **opts).html_safe
  end
end
