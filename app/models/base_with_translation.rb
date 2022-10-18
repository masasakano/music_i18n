# -*- coding: utf-8 -*-

# Abstract base Class for any class that is associated with a Translation class
#
# == Update (or create)
#
# Whether to update or create a record, the first step is to identify
# a potential existing record that matches the record to update/create.
# If the record is found, it will be either updated or raises an error for creation.
#
# Each entry of a child class of this class (e.g., {Artist}, {Place}) has
# a combination of structures of their own entries and multiple {Translation}-s.
# In identifying the existing record(s), the whole structure must be considered.
# The translated {Translation#title} alone is inadequate.  For example,
# {Place} "Perth" in the UK and Australia are completely different entities
# even though their {Translation#title} are identical.
#
#
# === Revised algorithm (Future plan)
#
# Before updating/creating, each subclass must construct unsaved {Translation}.
# To find an existing record, each subclass can pass two set of conditions
# to methods in this parent class:
# a set of exact parameters to identify a record and optionally a set of Translations.
# The method returns an existing record if any or blank record (new).
#
# At the second step, the child class can simply save update and save it.
# Alternatively it can pass all the parameters to update the record, which
# may or may not contain the record used to identify the existing record.
#
#   Prefecture.find_all_by_combined(
#     cond: {iso3166_loc_code: 123, country: Country['Japan', 'en', true]}
#   }
#
#   Artist.find_all_by_combined(
#     cond: {translations: [Translation(<ja: 'ハラミちゃん'>), Translation(<en: 'Haramichan'>), Translation(<en: 'Harami'>)]}
#   }
#
#   Artist.find_all_by_combined(
#     cond: {prefecture: Prefecture['香川県'], translations: [Translation(<ja: '高松駅'>), Translation(<en: 'Takamatsu Station'>)]}
#   }
#
# in the first example, it is the same as {#find_all_by}; in this case,
# any prefecture should be singly and exclusively identified
# with {Country} ID and loc_code.  The condition is "and"-ed.
#
#   your_hash.slice :iso3166_loc_code, :country
#   your_hash.slice(:iso3166_loc_code).merge other_hash.slice(:country)
#
# In the second example, an array of two translations are passed.
# The condition is "or"-ed, only for {BaseWithTranslation#translations}.
# It searches for an {Artist} record whose translation of either in Japanese
# or English matches the given one.  It is "or"-ed because you often don't know which
# record exists and most certainly don't know how many translations the existing
# record has (which would be necessary for the perfect match).
#
# In the third example, it matches the place(s) that is in Kagawa *and* that has the title
# of either or both of '高松駅' and 'Takamatsu Station'.  Note the first condition
# is 'and' and it is "or" only within the translations.
#
# A tip is, if you already have a hash that contains more elements than required,
# just slice it (and/or merge if necessary. Also, for an array of translations,
#   artrans.select{|i| i[:is_orig]}
# may be useful to pick up the one in the original language.
#
# A couple of helper options are available as opts_trans:
#
# * unique_trans_keys [Array] If given, the keys (like [:ruby, :romaji]) is used
#   to identify the {Translation}. Else {Translation.keys_to_identify} is called.
#
# Note that the options for Translation can include
#
# * slim_opts [Hash] Options to trim {Translation}.  Default: {DEF_TRIM_OPTIONS}
#   This determines how to pre-process white spaces in the title.
#
# For more complex conditions, the subclass should find it on their own steam.
#
# Then, at the second step, they create or update the record.
#
#   t_ja = Translation.create langcode: 'ja', title: 'ハラミちゃん'
#   t_ja.art.valid?          # => false  # because no appropriate translatable_(type|id) are given, which is precisely what you are searching for!
#   t_ja.art.saved_changes?  # => false
#   t_ja.art.new_record?     # => true
#   t_ja.art.id              # => nil
#   t_en = Translation.create langcode: 'en', title: 'Harami-chan'
#        # translatable_type or translatable can be omitted, as it is filled later.
#   t_fr = t_en.dup
#   t_fr.langcode = 'fr'     # French translation
#
#   person = Artist.find_by_combined(cond: {translations: [t_ja, t_en]})[0]  # Assuming the first one only
#
# One way:
#
#   if person.empty?  # no existing (Artist) records.
#     person = Artist.create_with_translations!(
#       note: 'Added/updated translations.',
#       translations: {ja: t_ja, en: t_en, fr: t_fr})   # Collision of a translation is possible.
#   else  # To edit an existing Artist record.
#      ActiveRecord::Base.transaction do  # person is not saved if Translation fails to be saved.
#        person.note = 'Added/updated translations.'
#        person.save!
#
#        trans = person.translations
#        en0 = trans.select{|k| k[:la]=='en'}[0]  # The first existing English translation.
#        if en0  # To update
#          en0.title = t_en.title
#          en0.save!
#        else    # To add a new Translation
#          t_en.translatable = person
#          t_en.save!
#        end
#        t_fr.translatable = person
#        if t_fr.valid?   # Validation: to make sure it can be safely saved.
#          t_fr.save!
#        end
#      end
#   end
#
# Another way:
#
#    trans = {ja: t_ja, en: t_en, fr: t_fr}
#    ActiveRecord::Base.transaction do  # person is not saved if Translation fails to be saved.
#      person.note = 'Added/updated translations.'
#      person.save!.with_updated_translations(trans)
#      ## or
#      person.save!.with_translations(trans)
#    end
#
# Note that this routine with_translations() uses a sophisticated algorithm to identify existing translations.
#
#
# A macro to do everything in one go (after {Translation}-s are created):
#
#   trans = {ja: t_ja, en: t_en, fr: t_fr}
#   person = Artist.create_or_update_with_translations(
#     cond: {translations: trans.slice(:ja, :en)},
#     add_prm:  {note: 'Added/updated translations.'},
#     translations: trans)
#
# ---------------------------
#
# In identifying the existing record(s), the whole structure must be considered.
# {Translation#title} is essential, of course. But maybe {Translation#alt_title}, too.
# In addition, the essential information to identify the existing records depends
# on each subclass; it is specified in the array MAIN_UNIQUE_COLS in each subclass.
# For example, "prefecture" is included in MAIN_UNIQUE_COLS in {Place}.
#
# Then, when a record in the DB has prefecture="Somewhere in Australia" *and*
# its {Translation#title} for English is "Perth" (see {BaseWithTranslation.select_by_translations}),
# it is the record (to be updated or that makes a creation attempt fail).
#
# Now, what is the information to be updated?
# The columns that are to be used for identification and those the values of which
# are updated are usually separate (though they may be the same in some cases).
# They can be the values unique to the record, such as the geo-location of the {Place},
# and/or its {Translation}-s.
# 
# The current implmentation is slightly disorganized, admittedly.
# I now think the process to search and find (identify) a record and that
# to update/create it should be separate.  However, that is not the case in the current
# interpretation. Both the processes are treated in a (series of) method in one go;
# the core routine is {BaseWithTranslation.update_or_create_with_translations_core!},
# and even its public wrappers are similar. Basically, they accept the arguments:
#
# hsmain : columns for the main entries unique to the record (eg., geo-location) used for identification/update
# unique_trans_keys : which keys (title, alt_title?) are used to identify a record.
# mainkeys : which keys in hsmain are used to identify the record.
# hs_trans : Translation (used for both identification/update)
#
# Then, in updating, any information that have *not* been used for identification
# in hsmain and hs_trans will be used to update the record; in other words to
# *add* some values in perhaps empty (though potentially existing) fields.
#
# == Relations
#
# The relations between methods are as follows (BWT means a class, "b" is an instance):
#
#   BWT['my_title', ['ja', [FALSE(including_alt_title?)]]] => BaseWithTranslation
#   BWT.create_with_translations!(note: 1950, translations: {ja: [{title: 'イマジン', is_orig: true}]})  # Array is optional
#   BWT.update_or_create_with_translations!(note: 1950, translations: {ja: [{title: 'イマジン', is_orig: true}]})  # Array is optional
#   BWT.create_with_translation!( note: 1950, translation:  {langcode: 'ja', title: 'イマジン', is_orig: true})
#   BWT.update_or_create_with_translation!( note: 1950, translation: {langcode: 'ja', title: 'イマジン', is_orig: true})
#   BWT.create_with_orig_translation!(**kwds)  # similar, but for "original" translation (recommended)
#   BWT.update_or_create_with_orig_translation!(**kwds)
#   BWT.select_translations_regex(:titles, /^Aus/i, where: ['id <> ?', abc.id])
#     # => [Translation, [Translation, ...]]
#   BWT.select_regex(             :titles, /^Aus/i, where: ['id <> ?', abc.id])
#     # => [BWT, [BWT, ...]]
#
#   b.select_translations_regex(  :titles, /^Aus/i, where: ['id <> ?', abc.id])
#     # => [Translation, [Translation, ...]]  (searching only those related to self; in practice, useful only when self has multiple translations in a language)
#   b.title
#   b.ruby
#   b.romaji
#   b.alt_title
#   b.alt_ruby
#   b.alt_romaji
#   b.orig_translation  # Original translation (there should be only 1)
#   b.orig_langcode     # Original language code
#   b.translations_with_lang(langcode=nil)  # Sorted {Translation}-s of a specific (or original) language
#   b.best_translations                          # => {'ja': <Translation>, 'en': <Translation>}
#   b.all_best_titles(attr=:title, safe: false)  # => {'ja': 'イマジン', 'en': 'Imagine'}
#  
#   b.create_translations!(          ja: [{title: 'イマジン'}], en: {title: 'Imagine', is_orig: true})
#   b.update_or_create_translations!(ja: [{title: 'イマジン'}], en: {title: 'Imagine', is_orig: true})
#     # => [Translation, [Translation, ...]]
#   b.with_translations(             ja: [{title: 'イマジン'}], en: {title: 'Imagine', is_orig: true})
#   b.with_updated_translations(     ja: [{title: 'イマジン'}], en: {title: 'Imagine', is_orig: true})
#     # => [BWT, [BWT, ...]]  # calling create, with NO update
#   b.create_translation!(          langcode: en, title: 'Imagine', is_orig: true)
#   b.update_or_create_translation!(langcode: en, title: 'Imagine', is_orig: true)
#     # =>  Translation
#   b.with_translation(             langcode: en, title: 'Imagine', is_orig: true)
#   b.with_updated_translation(     langcode: en, title: 'Imagine', is_orig: true)
#     # =>  BWT  # calling create, with NO update
#   b.with_orig_translation(        langcode: en, title: 'Imagine')
#   b.with_orig_updated_translation(langcode: en, title: 'Imagine')
#     # =>  BWT  # calling create, with NO update
#
# Each subclass should define this constant; a list of the default unique keys
# required to narrows down the selections for searching for the candidates
# to update.  For example, [:country, :country_id] for Prefercture.
#     MAIN_UNIQUE_COLS = []
#
# Each subclass of {BaseWithTranslation} should define this constant; if this is true,
# the definite article in each {Translation} is moved to the tail when saved in the DB,
# such as "Beatles, The" from "The Beatles".  If the translated title
# consists of a word or few words, as opposed to a sentence or longer,
# this constant should be true (for example, {Music#title}).
#     ARTICLE_TO_TAIL = true or false
#
class BaseWithTranslation < ApplicationRecord
  self.abstract_class = true
  after_create :save_unsaved_translations  # callback to create(-only) @unsaved_translations

  include SlimString
  extend  ModuleCommon  # for split_hash_with_keys and update_or_create_by_with_notouch!()
  include ModuleCommon  # for split_hash_with_keys

  class UnsavedTranslationsValidator < ActiveModel::Validator
    # Validate unsaved_translations if defined.
    def validate(record)
      return if record.unsaved_translations.blank?

      if !record.new_record?
        record.errors.add :base, "unsaved_translations has to be blank for an existing entity. Contact the code developer: #{record.inspect}"
        return
      end

      record.unsaved_translations.each do |tra|
        msg = []
        if !tra.valid_main_params? messages: msg
          msg.each do |em|
            record.errors.add :base, em
          end
        end
      end
    end
  end

  validates_with UnsavedTranslationsValidator

  ## Each subclass should define this; list of the default unique keys
  ## required to narrows down the selections for searching for the candidates
  ## to update.  For example, [:country, :country_id] for Prefercture
  # MAIN_UNIQUE_COLS = []

  AVAILABLE_LOCALES = I18n.available_locales  # ko, zh, ...
  LANGUAGE_TITLES = {
    ja: {
      'ja' => '日本語',
      'en' => '英語',
      'fr' => '仏語',
    },
    en: {
      'ja' => 'Japanese',
      'en' => 'English',
      'fr' => 'French',
    },
    fr: {
      'ja' => 'Japonais',
      'en' => 'Anglais',
      'fr' => 'Français',
    },
  }

  # Hash to specify the priority among the available locales
  HS_LOCALE_PRIORITY = AVAILABLE_LOCALES.map.with_index{|lc, i| [lc, i]}.to_h # Index mapping

  alias_method :inspect_orig, :inspect if ! self.method_defined?(:inspect_orig)

  # Unsaved {Translation}-s for a new record which would be created when self is saved.
  attr_accessor :unsaved_translations

  # The {Translation} that has the attribute (e.g., :alt_title) that has
  # the value of the matched String, selected by {Translation.find_by_regex} etc.
  attr_accessor :matched_translation

  # Copy of {Translation#matched_attribute} (e.g., :alt_title).
  # Because the value is not saved in the DB, self must hold this information
  # to reuse.
  attr_accessor :matched_attribute

  # Method (Symbol) to be used to find the matched {Translation}
  # See the Array {Translation::MATCH_METHODS} and method {Translation.find_by_a_title}
  attr_accessor :match_method

  # Initialization of {BaseWithTranslation#unsaved_translations}
  # in{BaseWithTranslation#new} (in any of its child classes).
  def initialize(*rest, **kwd)
    super
    @unsaved_translations ||= []
  end

  # Wrapper of dup to initialize @unsaved_translations
  def dup(*rest, **kwd)
    ret = super
    ret.unsaved_translations ||= []
    ret
  end

  # Displays (the original) Translation information, too.
  #
  # It is either title or alt_title; in the latter case '[alt]' is appended.
  #
  # @return [String]
  def inspect
    trans = translations
    n_trans = (trans.size rescue nil) # Number of total translations
    l_trans = (n_trans ? trans.pluck(:langcode).uniq.size : nil)  # Number of unique languages
    origtr  = (trans.find_by(is_orig: true) rescue nil)
    extra =
      if n_trans && n_trans > 0
        title = 
          if !origtr.respond_to? :title
            # nil
            Translation.sort(trans).pluck(:title, :alt_title).transpose.flatten.compact.first rescue nil
          else
            tit1 = origtr.title
            if tit1
              tit1.inspect
            else
              tit2 = origtr.alt_title
              tit2 ? tit2.inspect+"[alt]" : 'nil'
            end
          end
        "; Translation(id=#{origtr.id rescue 'nil'}/L=#{l_trans}/N=#{n_trans}): #{title} (#{origtr.langcode rescue 'nil'})"
      elsif unsaved_translations && unsaved_translations.size > 0  # It should never be nil, except those of fixtures called through #all??
        unsa = unsaved_translations
        "; Translation(unsaved(n=#{unsa.size})[0]): #{unsa[0].title} (#{unsa[0].langcode rescue 'nil'})"
      else
        "; Translation: None"
      end
    errmsg = (errors.present? ? '; @errors='+errors.messages.inspect : "")
    inspect_orig[0..-2]+extra+errmsg+">"
  end

  # Wrapper of {BaseWithTranslation.select_regex}
  #
  # Returns the first match of {BaseWithTranslation} or nil if no match
  # for the given {#title}.  Note "first" is arbitrary if multiple matches
  # are found.
  #
  # self.[] returns a first one without translations (which may be nil).
  #
  # In short, this method is useful for debugging and testing, but 
  # should not be used in the production code.
  #
  # @param value [Regexp, String] e.g., 'male'
  # @param langcode [String, NilClass] like 'ja'. If nil, all languages
  # @param with_alt [Boolean] if TRUE (Def: False), alt_title is ALSO searched.
  # @return [BaseWithTranslation, NilClass]
  def self.[](value, langcode=nil, with_alt=false)
    return find_all_without_translations.first if value.nil?
    kwd = (with_alt ? :titles : :title)
    select_regex(kwd, preprocess_space_zenkaku(value), langcode: langcode)[0]
  end

  # @return [BaseWithTranslation, NilClass] nil only if there are no records at all.
  # @raise [NoMethodError] if weight is not defined in the sub-class.
  def self.default
    raise NoMethodError if !has_attribute?(:weight)
    # EngageHow.all.order(:weight).first
    self.order(Arel.sql('CASE WHEN weight IS NULL THEN 1 ELSE 0 END, weight')).first # valid in any SQL database systems
  end

  # Find all {BaseWithTranslation} instances that have no associated translations defined
  #
  # @return [Relation] of self
  def self.find_all_without_translations
    sql = sprintf("LEFT JOIN translations ON %s = translations.translatable_id AND translations.translatable_type = '%s'",self.table_name+'.id', self.name) 
    self.joins(sql).where('translations.translatable_id IS NULL')
  end

  # Creates a {BaseWithTranslation} accompanied with multiple {Translation}-s.
  #
  # Wrapper of {BaseWithTranslation#create!} and {#with_translations} (which is
  # similar to {#create_translations!} but returns self) to return {BaseWithTranslation}.
  # Basically the following two are *nearly* equivalent, e.g.,
  #   Music.create_with_translations!(note: 1950, translations: {ja: [{title: 'イマジン'}]})
  #   Music.create!(note: 1950).with_translations!(ja: [{title: 'イマジン'}])
  #
  # If something goes wrong, it raises an Error and the database rolls back
  # so no {BaseWithTranslation} is created (that is the major difference of
  # this method from the combined one (2nd one in the examples above)).
  #
  # The optional parameters are the same as those for {#create!}, plus
  # they must include "translations: Hash", the hash of which is
  # in the form of {#create_translations!}, e.g.,
  #   translations: {strip: true, ja: [{title: 'イマジン'}], en: {title: 'Imagine', is_orig: true}}
  #
  # Note that you probably want to include:  is_orig: true
  # or simply use {#with_orig_translation} instead (so you don't forget it,
  # though you can associate only a single translation).
  #
  # @param hsmain [Hash] The hash parameters to select/update/create the main {BaseWithTranslation}(s) 
  # @param **hs_trans [Hash<Symbol>] to create self and the element of the key keytrans
  #    contain those to pass to {Translation}.new
  # @return [BaseWithTranslation]
  # @param hsmain [Hash] The hash parameters to select the main {BaseWithTranslation}(s)
  #    For example, the {Translation} of {Prefecture} is unique only within
  #    a {Country}.
  # @param unique_trans_keys [Array] If given, the keys (like [:ruby, :romaji]) is used
  #   to identify the {Translation}. Else {Translation.keys_to_identify} is called
  # @param *args [Array<Integer, Symbol>] Only 1 element. If :auto (Default), [:title, :alt_title]
  #   is used to identify an existing {Translation}. If Integer, it is the size
  #   of the Array of the keys for it according to the order of
  #   {Translation::TRANSLATED_KEYS}.
  #   For example, if nkeys==2, and inkeys==[:romaji, :alt_title, :ruby, :naiyo]
  #   [:alt_title, :ruby] is returned.
  # @param **hs_trans [Hash<Symbol>] Hash for multiple {Translation}-s
  #   Must contain the optional key :translations
  #   May include slim_opts (Hash).  Default: {COMMON_DEF_SLIM_OPTIONS}
  # @return [BaseWithTranslation]
  def self.create_with_translations!(hsmain={}, unique_trans_keys=nil, *args, **hs_trans)
    update_or_create_with_translations_core!(:translations, hsmain, unique_trans_keys, nil, false, *args, **hs_trans)
  end

  # update an exisiting {BaseWithTranslation} if exists, or creates one
  #
  # The judgement what matches an existing {BaseWithTranslation} is based on
  # both the unique keys (as given in the second argument uniques) AND
  # the associated {Translation}-s.  The uniqueness of a {Translation} is
  # as usual based on title, alt_title, and langcode.  Therefore,
  # this method assumes no two {Translation}-s in a language associated
  # with any of the existing {Translation}-s are the same.  If the assumption
  # does not hold, this method should not be used.
  #
  # The format of the main arguments of this method is similar to 
  # {ModuleCommon#update_or_create_by_with_notouch!} accompanied with
  # the optional arguments to create/update the associated {Translation}-s.
  #
  # The optional parameters are the same as those for {#create!}, plus
  # they must include "translations: Hash", the hash of which is
  # in the form of {#create_translations!}, e.g.,
  #   translations: {strip: true, ja: [{title: 'イマジン'}], en: {title: 'Imagine', is_orig: true}}
  #
  # @param prms [Hash] The main data for {BaseWithTranslation}
  # @param unique_trans_keys [Array] If given, the keys (like [:ruby, :romaji]) is used
  #   to identify the {Translation}. Else {Translation.keys_to_identify} is called
  # @param mainkeys [Array]  Array of the columns to be used to get an existing model.
  # @param *args [Array<Integer, Symbol>] Only 1 element. If :auto (Default), [:title, :alt_title]
  #   is used to identify an existing {Translation}. If Integer, it is the size
  #   of the Array of the keys for it according to the order of 
  #   {Translation::TRANSLATED_KEYS}.
  #   For example, if nkeys==2, and inkeys==[:romaji, :alt_title, :ruby, :naiyo]
  #   [:alt_title, :ruby] is returned.
  # @param **hs_trans [Hash<Symbol>] Hash for multiple {Translation}-s
  #   Must contain the optional key :translations
  #   May include slim_opts (Hash).  Default: {COMMON_DEF_SLIM_OPTIONS}
  # @return [BaseWithTranslation]
  # @raise [ActiveRecord::RecordInvalid, ActiveModel::UnknownAttributeError] etc
  def self.update_or_create_with_translations!(hsmain={}, unique_trans_keys=nil, mainkeys=nil, *args, **hs_trans)
    update_or_create_with_translations_core!(:translations, hsmain, unique_trans_keys, mainkeys, true, *args, **hs_trans)
  end

  # Sorts the translation part in the argument so the one with
  # is_orig=true comes in the front.
  #
  # @param kwds [Hash] option arguments
  # @return [Hash] in which the translation part is sorted.
  def self.sort_hash_langs_with_is_orig(**kwds)
    keytrans = :translations
    if !kwds.key? keytrans
        raise ArgumentError, "(#{__method__}) #{keytrans.inspect} option is mandatory but is not specified."
    end

    trans_part, opts_create = split_hash_with_keys(kwds, [keytrans])
    opt_trans, trans_all = split_hash_with_keys(trans_part[keytrans], COMMON_DEF_SLIM_OPTIONS.keys) # redundant

    best_lang = find_lang_of_is_orig(trans_all)
    langs_ordered = trans_all.keys.sort{|a, b| ((a == best_lang) ? -1 : 0) <=> ((b == best_lang) ? -1 : 0)}
    trans_ordered = { keytrans => langs_ordered.map{|lc| [lc, trans_all[lc]]}.to_h.merge(opt_trans)}

    opts_create.merge trans_ordered
  end
  private_class_method :sort_hash_langs_with_is_orig

  # @return [Symbol] like :en which has a (Hash to create a) {Translation} with {Translation#is_orig} == true
  def self.find_lang_of_is_orig(hsin)
    hsin.each_pair do |ek, ea_obj|
      if !ea_obj.respond_to? :rotate
        return ek if ea_obj[:is_orig]
        next
      end

      # ea_obj is an Array; the original is in the form of {en: [{title: 'abc'}, {title: 'def'}], ja: ...}
      return ek if ea_obj.any?{|i| i[:is_orig]}
    end
    hsin.keys.first
  end
  private_class_method :find_lang_of_is_orig

  # Creates a {BaseWithTranslation} accompanied with a single {Translation} .
  #
  # Very similar to {BaseWithTranslation#create_with_translation!} except
  # this accepts only a single translation and hence the argument format differs.
  #
  # Wrapper of {BaseWithTranslation#create!} and {#with_translation} (which is
  # similar to {#create_translation!} but returns self) to return {BaseWithTranslation}.
  # Basically the following three are *nearly* equivalent, e.g.,
  #   Music.create_with_translations!(note: 1950, translations: {ja: {title: 'イマジン'}})
  #   Music.create_with_translation!( note: 1950, translation:       {title: 'イマジン', langcode: 'ja'})
  #   Music.create!(note: 1950).with_translation!(title: 'イマジン', langcode: 'ja')
  #
  # If something goes wrong, the former two raise an Error and the database rolls back
  # so no {BaseWithTranslation} is created, whereas the last one does not
  # make the database roll back for the created {BaseWithTranslation},
  # which is the major difference.
  #
  # The optional parameters are the same as those for {#create!}, plus
  # they must include "translation: Hash", the hash of which is
  # in the form of {#create_translation!}, e.g.,
  #   translations: {strip: true, title: 'Imagine', is_orig: true}
  #
  # Note that you probably want to include:  is_orig: true
  # or simply use {BaseWithTranslation#create_with_orig_translation!} instead
  # (so you don't forget it, though you can associate only a single translation).
  #
  # @param hsmain [Hash] The hash parameters to select the main {BaseWithTranslation}(s) 
  #    For example, the {Translation} of {Prefecture} is unique only within
  #    a {Country}.
  # @param unique_trans_keys [Array] If given, the keys (like [:ruby, :romaji]) is used
  #   to identify the {Translation}. Else {Translation.keys_to_identify} is called
  # @param *args [Array<Integer, Symbol>] Only 1 element. If :auto (Default), [:title, :alt_title]
  #   is used to identify an existing {Translation}. If Integer, it is the size
  #   of the Array of the keys for it according to the order of 
  #   {Translation::TRANSLATED_KEYS}.
  #   For example, if nkeys==2, and inkeys==[:romaji, :alt_title, :ruby, :naiyo]
  #   [:alt_title, :ruby] is returned.
  # @param **hs_trans [Hash<Symbol>] Hash for a single {Translation}
  #   Must contain the key :translation
  #   May include slim_opts (Hash).  Default: {COMMON_DEF_SLIM_OPTIONS}
  # @return [BaseWithTranslation]
  def self.create_with_translation!(hsmain={}, unique_trans_keys=nil, *args, **hs_trans)
    update_or_create_with_translations_core!(:translation, hsmain, unique_trans_keys, false, *args, **hs_trans)
  end

  # Same as {BaseWithTranslation.create_with_translation!} but may update
  #
  # Must contain the optional key :translation
  #
  # #see update_or_create_with_translations!
  #
  # @param (see BaseWithTranslation.create_with_translation!)
  # @return [BaseWithTranslation]
  def self.update_or_create_with_translation!(hsmain={}, unique_trans_keys=nil, mainkeys=nil, *args, **hs_trans)
#print "DEBUG:update1st:hsmain=#{hsmain.inspect}, s_trans="; p hs_trans
    update_or_create_with_translations_core!(:translation, hsmain, unique_trans_keys, mainkeys, true, *args, **hs_trans)
  end

  # Same as {BaseWithTranslation#create_with_translation!} but a single original
  # translation only is created.
  #
  # Must contain the optional key :translation
  #
  # @param (see BaseWithTranslation.create_with_translation!)
  # @return [BaseWithTranslation]
  def self.create_with_orig_translation!(hsmain={}, unique_trans_keys=nil, *args, **hs_trans)
    update_or_create_with_translations_core!(:orig_translation, hsmain, unique_trans_keys, nil, false, *args, **hs_trans)
  end

  # Same as {BaseWithTranslation.create_with_orig_translation!} but may update
  #
  # Must contain the optional key :translation
  #
  # @param (see BaseWithTranslation.create_with_translation!)
  # @return [BaseWithTranslation]
  def self.update_or_create_with_orig_translation!(hsmain={}, unique_trans_keys=nil, mainkeys=nil, *args, **hs_trans)
#print "DEBUG:orig:hs_trans:"; p [hsmain, hs_trans]
    update_or_create_with_translations_core!(:orig_translation, hsmain, unique_trans_keys, mainkeys, true, *args, **hs_trans)
  end

  # Core routine for 
  # {BaseWithTranslation.update_or_create_with_translation!},
  # {BaseWithTranslation.update_or_create_with_translations!},
  # {BaseWithTranslation.create_with_translation!}, and
  # {BaseWithTranslation.create_with_translations!}
  #
  # #see update_or_create_with_translations!
  #
  # @param keytrans [Symbol] One of :translation, :translations and :orig_translation
  # @param hsmain [Hash] The hash parameters to select the main {BaseWithTranslation}(s) 
  #    For example, the {Translation} of {Prefecture} is unique only within
  #    a {Country}.
  # @param unique_trans_keys [Array] If given, the keys (like [:ruby, :romaji]) is used
  #   to identify the {Translation}. Else {Translation.keys_to_identify} is called
  # @param mainkeys [Array]  Array of the columns to be used to get an existing model.
  # @param updated [Boolean] TRUE if updated as opposed to create only (Def: false)
  # @param *args [Array<Integer, Symbol>] Only 1 element. If :auto (Default), [:title, :alt_title]
  #   is used to identify an existing {Translation}. If Integer, it is the size
  #   of the Array of the keys for it according to the order of 
  #   {Translation::TRANSLATED_KEYS}.
  #   For example, if nkeys==2, and inkeys==[:romaji, :alt_title, :ruby, :naiyo]
  #   [:alt_title, :ruby] is returned.
  # @param **hs_trans [Hash<Symbol>] to create self and the element of the key keytrans
  #    contain those to pass to {Translation}.new
  #   May include slim_opts (Hash).  Default: {COMMON_DEF_SLIM_OPTIONS}
  # @return [BaseWithTranslation]
  def self.update_or_create_with_translations_core!(keytrans, hsmain={}, unique_trans_keys=nil, mainkeys=nil, updated=false, *args, **hs_trans)

    raise(ArgumentError, 'Contact the code developer') if ![:translation, :translations, :orig_translation].include? keytrans
    mainkeys ||= (const_defined?(:MAIN_UNIQUE_COLS) ? self::MAIN_UNIQUE_COLS : [])  # Without self, raised: NameError: uninitialized constant BaseWithTranslation(abstract)::MAIN_UNIQUE_COLS
    msg = "(#{__method__}) Translation(s) #{hs_trans.inspect} is strange. Contact the code developer."
    msg2= "(#{__method__}) Contact the code developer. Key :langcode(Symbol) is mandatory but not defined in "
    trans =
      case keytrans
      when :orig_translation, :translation
        hs = (((:orig_translation == keytrans) ? {is_orig: true} : {}).merge(hs_trans[:translation])) || raise(ArgumentError, msg)
        {hs[:langcode].to_sym => hs} rescue raise(ArgumentError, msg2+hs_trans.inspect) # Error when !hs[:langcode]
      when :translations
        hs_trans[keytrans] || raise(ArgumentError, msg)
      else
        raise ArgumentError, "(#{__method__}) Symbol keytrans is strange (#{keytrans.inspect}). Contact the code developer."
      end
#print "DEBUG:corecore:(#{keytrans.inspect}):[,in_hs]:"; p [hsmain,hs_trans]

    keytrans = :translation if keytrans == :orig_translation  # The argument key name is :translation (or :translations)
    if !hs_trans.key? keytrans
      raise ArgumentError, "(#{__method__}) #{keytrans.inspect} option is mandatory but is not specified."
    end
    if !trans.first[0]   # if hs[:langcode] does not exist
      raise ArgumentError, "(#{__method__}) No langcode key in #{hs_trans.inspect}."
    end

    if updated
      ## Extract the columns to be used to get an existing model if any.
      unique_cols, updating_cols = split_hash_with_keys(hsmain, mainkeys)

      existings = select_by_translations(unique_cols, unique_trans_keys, *args, **trans)
#print "DEBUG:exi: exi=";p existings

      if existings.count > 1 
#print "DEBUG:exi: unique_cols=#{unique_cols.inspect}, unique_trans_keys=#{unique_trans_keys.inspect}, args=#{args.inspect}, trans=";p trans
        msg = "More than 1 #{self.name}-s (Total: #{existings.size}) exist #{existings.inspect} for the given translations #{trans.inspect}"
        logger.error msg+".  existings="+existings.inspect
        raise MultiTranslationError::AmbiguousError, msg
      end
    end

    obj = nil
    method = ('with_' + (updated ? 'updated_' : '') + 'translations').to_sym
    ActiveRecord::Base.transaction do
      obj, msg_opts2pass =
        if updated && !existings.empty? 
          # logger.info "(#{__FILE__}:#{__method__}) for update: hsmain=#{hsmain.inspect}, mainkeys=#{mainkeys}" if updating_cols.empty?
          # logger.info "(#{__FILE__}:#{__method__}) for update: updating_cols is empty." if updating_cols.empty?
#puts "DEBUG:core:UPDATE:(#{__FILE__}:#{__method__}) for update: hsmain.keys=#{hsmain.keys.inspect}, mainkeys=#{mainkeys}, hsmain=#{hsmain.inspect}" if updating_cols.empty?
#print "DEBUG:core:UPDATE: [unique_cols, updating_cols]=";p [unique_cols, updating_cols]
          if updating_cols.empty?
            [existings[0], nil]
          else
            existings[0].update!(**updating_cols)
            [existings[0],         "update!(#{updating_cols.inspect})"]
            # NOTE: In Ruby 2.7, update!(updating_cols) raises a warning (i.e., without '**' in the arg).
            #     : In Ruby 3.0, update!(updating_cols) *is* the correct way because
            #     : activerecord-6.1.4/lib/active_record/persistence.rb accepts a Hash object
            #     : as opposed to keyword arguments (to support Ruby 1.8?).
            #     : This case of update!(**updating_cols) would raise ArgumentError
            #     : when updating_cols is empty. But then, it should not be called when empty anyway.
          end
        else
          [self.create!(**hsmain), "create!(#{hsmain.inspect})"]
        end

      begin
        obj.send(method, **trans)
      rescue #=> err
        armsg = ["Failed to create translations with param=#{trans.inspect}"]
        armsg << "hence #{msg_opts2pass} for #{self.name} rolls back." if msg_opts2pass
        logger.error armsg.join(" ")
#print "DEBUG:upfd-in_hs:"; p hs_trans
#print "DEBUG:upfd:"; puts armsg.join(" ")
        raise
      end
    end
    obj
  end
  private_class_method :update_or_create_with_translations_core!


  # The matched String to be used to select or generate self.
  #
  # The arguments are the same as {BaseWithTranslation.select_translations_regex},
  # and ultimately {Translation.select_regex}.
  #
  # @example
  #   sex.matched_string(%i(title ruby romaji), /n/, langcode: 'en') # => 'not known'
  #   sex.set_matched_trans_att(%i(title ruby romaji), /n/, langcode: 'en')
  #     # This set {#matched_translation}, {#matched_attribute} for self. Then,
  #   sex.matched_string  # => 'not known'
  #
  # @param kwd [Symbol, String, Array<String>, NilClass] (title|alt_title|ruby|alt_ruby|romaji|alt_romaji|titles|all)
  #    or Array of Symbol|String to evaluate. Note :titles is the alias
  #    for [:title, :alt_title], and :all means all the 6 columns.
  #    If nil, this parameter, as well as value, is not used.
  # @param value [Regexp, String, NilClass] e.g., 'male' and /male\z/
  # @param att: [Symbol, NilClass] e.g., :alt_title. Usually read from @matched_attribute or generated from kwd and value, but you can specify it explicitly.
  # @param *args: [Array]
  # @param **restkeys: [Hash] 
  # @return [String, NilClass] nil if not found
  def matched_string(kwd=nil, value=nil, *args, att: nil, **restkeys)
    trans = matched_translation
    att ||= matched_attribute
    return trans.matched_string(att: att) if trans && att

    raise MultiTranslationError::AmbiguousError, "(kwd, value) must be explicitly specified in #{self.class.name}##{__method__} because matched_attribute has not been defined. Note Translation was likely created by Translation.select_regex as opposed to by Translation.find_by_regex, which would set matched_attribute." if [kwd, value].compact.empty?
    if !trans
      trans = find_translation_by_regex(kwd, value, *args, **restkeys)
      return trans.matched_string
    end

    return trans.matched_string(kwd, value)
  end

  # Set {#matched_translation} and {#matched_attribute}.
  #
  # See {#matched_string} for the arguments.
  #
  # @example
  #   sex.set_matched_trans_att(%i(title ruby romaji), /n/, langcode: 'en')
  #
  # @param *args: [Array]
  # @param **restkeys: [Hash] 
  # @return [Array] [{#matched_translation}, {#matched_attribute}]
  def set_matched_trans_att(*args, **restkeys)
    trans = find_translation_by_regex(*args, **restkeys)
    self.matched_translation = trans
    self.matched_attribute   = trans.matched_attribute
    [matched_translation, matched_attribute]
  end

  # Asign matched_translation based on the strong candidate
  #
  # The model should have been selected based on the given 
  # title_str (or similar)
  #
  # @param model [BaseWithTranslation]
  # @return self
  def assign_matched_translation(title_str)
    tra = nil
    [title_str, /\A#{Regexp.quote title_str}\z/i].each do |str_or_re|
      tra = find_translation_by_regex(:titles, str_or_re)
      break if tra
    end
    tra ||= (best_translations['ja'] || best_translations['en'] || best_translations['en'].first) 
    if !tra.matched_attribute
      # NOTE: this happens basically when tra is from best_translations rather than 
      # find_translation_by_regex(), which happens when no Translation
      # matches the given title_str, i.e., when the DB entry has
      # been manually modified since the first creation.
      tra.matched_attribute = (!tra.title.blank? ? :title : :alt_title)
    end
    self.matched_translation = tra
    self.matched_attribute   = tra.matched_attribute
    self
  end

  # Wrapper of {Translation.find_all_by_a_title}
  #
  # To find the first {Translation} that matches a String and maybe
  # other conditions in {#translations}.
  # That with (is_orig: true) would come first.
  #
  # @example
  #   Artist.find_all_by_a_title(:alt_title, 'the Proclaimers')
  #    # => matches Artist having "Proclaimers, The" in Translation
  #
  # See {Translation.find_all_by_a_title} for options.
  #
  # @param kwd [Symbol, String, Array<String>, NilClass] (title|alt_title|ruby|alt_ruby|romaji|alt_romaji|titles|all)
  #    or Array of Symbol|String to evaluate. Note :titles is the alias
  #    for [:title, :alt_title], and :all means all the 6 columns.
  #    If nil, this parameter, as well as value, is not used.
  # @param *args: [Array] key, value (e.g., :titles, 'Lennon')
  # @param uniq: [Boolean] If true, the returned Array is uniq-ed based on <BaseWithTranslation#id>
  # @param **transkeys: [Hash] e.g., match_method_upto: :optional_article_ilike, langcode: 'en'. See {Translation.find_all_by_a_title} for detail.
  # @return [Array<BaseWithTranslation>] Can be empty. For each element, {BaseWithTranslation#matched_translation}, {BaseWithTranslation#match_method} and {BaseWithTranslation#matched_attribute} are set.
  def self.find_all_by_a_title(kwd, *args, uniq: false, **transkeys)
    rela = Translation.send(__method__,
      kwd, *args,
      translatable_type: self.name,
      **transkeys
    )

    ret = rela.map{|trans|
      trans.set_matched_method_attribute(kwd, rela)
      ret = trans.translatable
      ret.matched_translation = trans
      ret.matched_attribute   = trans.matched_attribute
      ret.match_method        = trans.match_method
      ret
    }

    uniq ? ret.uniq : ret  # equality based on BaseWithTranslation#id
  end

  # Wrapper of {Translation.find_by_a_title}
  #
  # To find the first {Translation} that matches a String and maybe
  # other conditions in {#translations}.
  # That with (is_orig: true) would come first.
  #
  # @example
  #   Artist.find_by_a_title(:alt_title, 'the Proclaimers')
  #    # => matches Artist having "Proclaimers, The" in Translation
  #
  # See {Translation.find_by_a_title} for options.
  #
  # @param *args: [Array] key, value (e.g., :titles, 'Lennon')
  # @param **restkeys: [Hash] e.g., match_method_upto, langcode
  # @return [BaseWithTranslation, NilClass] {BaseWithTranslation#matched_translation} and {BaseWithTranslation#match_method} and {BaseWithTranslation#matched_attribute} are set
  def self.find_by_a_title(*args, **restkeys)
    trans = Translation.send(__method__,
      *args,
      translatable_type: self.name,
      **restkeys
    )
    return nil if !trans
    ret = trans.translatable
    ret.matched_translation = trans
    ret.matched_attribute   = trans.matched_attribute
    ret.match_method        = trans.match_method
    ret
  end

  # Wrapper of the standard self.find_all_by, considering {Translation}
  #
  # Note the returned Array of this method, unless the given optional
  # argument "uniq" is true, may contain more than one
  # BaseWithTranslation with the same id (namely, same DB entry)
  # each of which must have different {BaseWithTranslation#matched_translation},
  # {BaseWithTranslation#match_method}
  # and/or {BaseWithTranslation#matched_attribute}.
  #
  # For example, if {Translation#title} is identical for "ja" and "en",
  # the return consists of 2 {BaseWithTranslation}-s.
  # Or, if the given argument "titles" is an Array of "ja" and "en" titles,
  # and if either match existing Translations of "ja" and "en",
  # the return consists of 2 {BaseWithTranslation}-s.
  #
  # If you do not care about which word among the given "titles" matches
  # what {Translation} in which attribute (alt_title, romaji, etc),
  # specify "uniq: true" in the argument.
  #
  # Whether uniq is true or false, the returned Array is sorted
  # according to {Translation#is_orig} of the associated Translation
  # so that the first comes {BaseWithTranslation} with
  # {BaseWithTranslation#matched_translation}#is_orig of true.
  #
  # @param titles [Array<String>] Array of "title"-s of the singer (maybe in many languages) to search for.
  # @option kwd [Symbol, String, Array<String>, NilClass] (title|alt_title|ruby|alt_ruby|romaji|alt_romaji|titles|all)
  #    or Array of Symbol|String to evaluate. Note :titles is the alias
  #    for [:title, :alt_title], and :all means all the 6 columns.
  #    If nil, this parameter, as well as value, is not used.
  # @param id: [Integer, NilClass] ID of the BaseWithObject to get, if any.
  #    Users should usually use {#Artist.find_by_id} instaed.
  # @param place: [Place, NilClass] If the caller class requires {Place},
  #    this routine will filter the candidates based on it immediately
  #    before the callback block; the caller can, instead, do their
  #    own processing in the callback block while not providing non-nil "place"
  #    in the argument to this method.
  # @param uniq: [Boolean] If true, the returned Array is uniq-ed based on <BaseWithTranslation#id>
  # @param **transkeys: [Hash] e.g., match_method_upto, langcode. Passed to {Translation.find_all_by_a_title} for detail.
  # @return [Array] maybe empty.
  #   It is sorted according to is_orig so that {BaseWithTranslation} that has the {Translation}
  #   with {Translation#is_orig} of true comes first.
  #   {BaseWithTranslation#match_method} and {BaseWithTranslation#matched_attribute} are set
  #   in each element and so {BaseWithTranslation#matched_string} can be used.
  # @yield [BaseWithTranslation] a candidate artist is given as the block parameter.
  #   The block (iterator) must ends (or next) with false if the candidate
  #   does NOT satisfiy the condition.
  def self.find_all_by_title_plus(titles, kwd=:titles, *args, uniq: false, id: nil, place: nil, **transkeys)

    return self.find_by_id(id) if id

    # Gets an Array of the matched BaseWithTranslations. Note there can be duplication
    # about BaseWithTranslation#id in which their BaseWithTranslation#matched_translation
    # may or may not be the same.
    # For example, maybe given (title[0]==title[0]) holds or
    # Translations for "ja" and "en" may be the same.
    allcands = titles.map{|et|
      self.find_all_by_a_title(kwd, et, *args, uniq: uniq, **transkeys) # Array
    }.sum([])
    # Now, each element of allcands has the singleton method matched_translation

    logger.debug "More than one different BaseWithTranslations remain as the candidates." if allcands.map(&:id).uniq.size != 1
    # This can happen because there can be multiple BaseWithTranslations with
    # same translations but in different countries (like UK and US), Genres, etc.

    # Here, we narrow down the candidates, where the caller can provide a callback.
    # Chances are no candidates will remain as a result.
    allcands = allcands.select{|obj|  ## filter out those that are inconsistent.
      next false if place && !place.not_disagree?(obj.place, allow_nil: true)
      yield obj if block_given?
    }

    indices_sorted = allcands.map.with_index{|x,i| [x,i]}.sort{|a,b| a[0].matched_translation <=> b[0].matched_translation || 0}.map{|j| j[1]}  # Translation#<=> would return nil when parents (=translatable) differ
    ret = indices_sorted.map{|i| allcands[i]}
    uniq ? ret.uniq : ret  # equality based on BaseWithTranslation#id
  end

  # Find or initialize a model.
  #
  # After that, any null columns that are specified by the caller
  # are filled, though unsaved, yet.
  # Translations are unchange or not created at all.
  #
  # @param mainprms: [Hash] {birth_day: 31} etc
  # @param titles [Array<String>] Array of "title"-s of the singer (maybe in many languages) to search for.
  # @param **opts: [Hash] e.g., match_method_upto, langcode. Passed to {Translation.find_all_by_a_title} for detail.
  # @param prms_to_find: [Hash] Similar to mainprms, but those that are NOT used in updating/initializing but only in identifying/findin
  # @return [BaseWithTranslation]
  #   If found, a single Artist is returned, where
  #   {BaseWithTranslation#match_method} and {BaseWithTranslation#matched_attribute} are set
  #   and so {BaseWithTranslation#matched_string} can be used, and where
  #   the parameters are updated but *unsaved*.
  #   If not found, a new (unsaved) record of {BaseWithTranslation} is returned.
  #   Either way, {Translation} are NOT updated.
  def self.updated_by_title_plus_or_initialized(
        mainprms,
        titles,
        *args,
        prms_to_find: {},
        **opts)

    model = self.find_all_by_title_plus(
      titles,
      *args,
      **(mainprms.merge(prms_to_find).merge(opts))
    ).first || self.new

#print "DEBUG:base:m:";p mainprms
#print "DEBUG:base:p:";p prms_to_find
    mainprms.each_pair do |ek, ev|
      begin
        model.send(ek.to_s+'=', ev) if model.send(ek).blank?  # if the existing is null
      rescue ActiveModel::UnknownAttributeError => er
        msg = "ERROR(#{self.name}.#{__method__}): provided mainprms="+mainprms.inspect+" Contact the code devloper."
        logger.error msg
        warn msg
        raise
      end
    end
    model
  end

  # Returns an Array of {BaseWithTranslation} with the specified title (or alt_title)
  #
  # So far, both {Translation#title} and {Translation#alt_title} are considered.
  #
  # This is a wrapper of {Translation.of_title}.
  #
  # In the future, more sophisticated algorithm may be implemented.
  #
  # @example
  #   Music.of_title('How?', scoped: Artist[/Lennon/].musics).first
  #    # => Music[/\AHow\?\z/] # by John Lennon
  #
  # @param title [String]
  # @param exact: [Boolean] if true, only the exact match (after {SlimString}) is considered.
  # @param case_sensitive: [Boolean] if true, only the exact match is considered.
  # @param scoped: [#pluck, #map] Array (or Relation) of {BaseWithTranslation}-s
  # @param **kwd [Hash] most notably, :exact, :case_sensitive, :langcode and :translatable_type
  # @return [Array<Translation>] maybe empty
  #
  # @todo Consider sort based on Levenshtein distances for more fuzzy matches
  def self.of_title(title, scoped: nil, **kwd)
    scope2pass = (scoped ? scoped.map(&:translations).flatten : scoped)
    Translation.of_title(title, scoped: scope2pass, **kwd).map(&:translatable).uniq
  end

  # Wrapper of {BaseWithTranslation.find_translation_by_regex}, but returning
  # a {BaseWithTranslation}, searching {Translation}, from its title etc
  #
  # @param *args [Array<Symbol, String, Array<String>, Regexp>] Symbol, String|Regexp. See {Translation.select_regex}. 
  # @param **restkeys: [Hash] Any other (exact) constraints to pass to {Translation}
  #    For example,  is_orig: true
  # @return [BaseWithTranslation, NilClass]
  def self.find_by_regex(*args, **restkeys)
    trans = find_translation_by_regex(*args, **restkeys)
    return nil if !trans
    ret = trans.translatable
    ret.matched_translation = trans
    ret.matched_attribute   = trans.matched_attribute
    ret
  end

  # Wrapper of {BaseWithTranslation.select_translations_regex}, but returning
  # an Array (not Translation::ActiveRecord_Relation) of {BaseWithTranslation},
  # searching {Translation}, from its title etc
  #
  # Note that the result is not "sorted", as there is
  # no general way to know whether the result is actually sotable.
  #
  # @param *args [Array<Symbol, String, Array<String>, Regexp>] Symbol, String|Regexp. See {Translation.select_regex}. 
  # @param **restkeys: [Hash] Any other (exact) constraints to pass to {Translation}
  #    For example,  is_orig: true
  # @return [Array<BaseWithTranslation>]
  def self.select_regex(*args, **restkeys)
    select_translations_regex(*args, **restkeys).map{|i| i.translatable}.uniq
  end

  # Wrapper of {Translation.find_by_regex}, returning {Translation}-s of only this class
  #
  # @param *args: [Array]
  # @param **restkeys: [Hash] 
  # @return [Translation]
  def self.find_translation_by_regex(*args, **restkeys)
    Translation.find_by_regex(*args, translatable_type: self.name, **restkeys)
  end

  # Wrapper of {Translation.select_regex}, returning {Translation}-s of only this class
  #
  # Search {Translation} to find matching {BaseWithTranslation}-s.
  # If the given value is String, SQL is used to search the match (efficient).
  # If Regexp, Ruby engine is used (hence more resource intensive).
  #
  # @example
  #   Country.select_translations_regex(:alt_title, /^Aus/i, where: ['id <> ?', abc.id])
  #
  # @param *args: [Array]
  # @param **restkeys: [Hash] 
  # @return [Translation::ActiveRecord_Relation, Array<Translation>]
  def self.select_translations_regex(*args, **restkeys)
    Translation.select_regex(*args, translatable_type: self.name, **restkeys)
  end

  # Wrapper of {Translation.select_regex}
  #
  # To find those that satisfies with String, Regexp, and/or other conditions.
  # in {#translations}.
  #
  # @example
  #   x.select_translations_regex(:alt_title, /^Aus/i, where: ['id <> ?', abc.id])
  #
  # @param *args: [Array]
  # @param **restkeys: [Hash] 
  # @return [Array<Translation>]
  def select_translations_regex(*args, **restkeys)
    Translation.select_regex(
      *args,
      translatable_type: self.class.name,
      translatable_id:   self.id,
      **restkeys
    )
  end

  # Wrapper of {Translation.find_by_regex}
  #
  # To find the first {Translation} that satisfies String, Regexp, and/or other conditions.
  # in {#translations}.
  #
  # @example
  #   x.find_translation_by_regex(:alt_title, /^Aus/i, where: ['id <> ?', abc.id])
  #
  # @param *args: [Array]
  # @param **restkeys: [Hash] 
  # @return [Translation, NilClass]
  def find_translation_by_regex(*args, **restkeys)
    Translation.find_by_regex(
      *args,
      translatable_type: self.class.name,
      translatable_id:   self.id,
      **restkeys
    )
  end


  # Wrapper of {Translation.find_translation_by_a_title}
  #
  # To find the first {Translation} that matches a String and maybe
  # other conditions in {#translations}.
  # That with (is_orig: true) would come first.
  #
  # @example
  #   artist.find_by_a_title(:titles, 'the Proclaimers')
  #    # => matches "Proclaimers, The" in Translation
  #
  # See {Translation.find_by_a_title} for options.
  #
  # @param *args: [Array] key, value (e.g., :titles, 'Lennon')
  # @param **restkeys: [Hash] e.g., match_method_upto, langcode
  # @return [Translation, NilClass] {Translation#match_method} is set
  def find_translation_by_a_title(*args, **restkeys)
    Translation.find_by_a_title(
      *args,
      translatable_type: self.class.name,
      translatable_id:   self.id,
      **restkeys
    )
  end

  # Select all {BaseWithTranslation} based on a single {Translation} and its own parameters.
  #
  # It works as kind of a wrapper of {BaseWithTranslation.find_all_by_translation};
  # however, it is implemented in a completely different way by calling SQL directly.
  #
  # The best way to get {Translation}-s would be
  #   Country.select_by_translation(trim: true, langcode: 'ja', title: '日本')[0].translations
  #
  # @example with constraint
  #   ctry = Country['Australia', 'en', true]
  #   p1 = Prefecture.select_by_translation({country: ctry}, langcode: 'en', title: 'Perth')[0]
  #
  # @param hsmain [Hash] The hash parameters to select the main {BaseWithTranslation}(s) 
  # @param unique_trans_keys [Array] If given, the keys (like [:ruby, :romaji]) is used
  #   to identify the {Translation}. Else {Translation.keys_to_identify} is called
  # @param *args [Array<Integer, Symbol>] Only 1 element. If :auto (Default), [:title, :alt_title]
  #   is used to identify an existing {Translation}. If Integer, it is the size
  #   of the Array of the keys for it according to the order of 
  #   {Translation::TRANSLATED_KEYS}.
  #   For example, if nkeys==2, and inkeys==[:romaji, :alt_title, :ruby, :naiyo]
  #   [:alt_title, :ruby] is returned.
  # @param inprms [Hash<Symbol>] Should contain at least one of title, alt_tile, ruby etc,
  #   in addiotn to langcode.
  #   May include slim_opts (Hash).  Default: {COMMON_DEF_SLIM_OPTIONS}
  # @return [BaseWithTranslation::ActiveRecord_Relation]
  # @raise [RuntimeError]
  def self.select_by_translation(hsmain={}, unique_trans_keys=nil, *args, **inprms)
    #opts, main_trans = split_hash_with_keys(inprms, COMMON_DEF_SLIM_OPTIONS.keys) # In case it contains options like :strip
    select_by_translations(
      hsmain,
      unique_trans_keys,
      *args,
      **(opt_trans.merge({inprms.langcode.to_sym => main_trans}))
      #**(opt_trans.merge({main_trans.langcode.to_sym => main_trans}))
    )
  end

  # Returns Relation of {BaseWithTranslation} that have one of the {Translation}-s.
  #
  # If the conditions are sufficient, there should be at most 1 object.
  #
  # Input Hash (inprms) is like (n.b., it may contain the keys like "strip"?),
  #   {
  #     en: [ {title: 'T1'}, {title: 'T2', is_orig: true, langcode: 'en'} ],
  #     ja:   {title: 'J1'},
  #   }
  #
  # @example return
  #    Prefecture.joins("INNER JOIN translations "+
  #                     "ON translations.translatable_id = prefectures.id AND"+
  #                        "translations.translatable_type = 'Prefecture'").
  #               where(country: cnty).
  #               where("translations.langcode = ? AND translations.title = ?, 'en', 'Abc').
  #               distinct
  #
  # @param hsmain [Hash] The hash parameters to select the main {BaseWithTranslation}(s) 
  #    For example, the {Translation} of {Prefecture} is unique only within
  #    a {Country}.
  # @param unique_trans_keys [Array] If given, the keys (like [:ruby, :romaji]) is used
  #   to identify the {Translation}. Else {Translation.keys_to_identify} is called
  # @param *args [Array<Integer, Symbol>] Only 1 element. If :auto (Default), [:title, :alt_title]
  #   is used to identify an existing {Translation}. If Integer, it is the size
  #   of the Array of the keys for it according to the order of 
  #   {Translation::TRANSLATED_KEYS}.
  #   For example, if nkeys==2, and inkeys==[:romaji, :alt_title, :ruby, :naiyo]
  #   [:alt_title, :ruby] is returned.
  # @param inprms [Hash<Symbol>] Should contain at least one of title, alt_tile, ruby etc,
  #   in addiotn to langcode.
  #   May include slim_opts (Hash).  Default: {COMMON_DEF_SLIM_OPTIONS}
  # @return [BaseWithTranslation::ActiveRecord_Relation]
  # @raise [RuntimeError]
  def self.select_by_translations(hsmain={}, unique_trans_keys=nil, *args, **inprms)
    raise RuntimeError, "Contact the code developer. uk=(#{unique_trans_keys.inspect})" if !unique_trans_keys.nil? && unique_trans_keys.blank?

#print "DEBUG:plural: unique_trans_keys=#{unique_trans_keys.inspect}, args=#{args.inspect}, inprms=";p inprms
    trtbl = Translation.table_name
    joins_str = sprintf(
      "INNER JOIN %<tr>s ON %<tr>s.translatable_id = %<my>s.id and %<tr>s.translatable_type = '%<klas>s'",
      tr: trtbl,
      my: self.table_name,
      klas: self
    )
#print "DEBUG:plural: joins_str=";p joins_str

    ret = self.joins(joins_str)
    ret = ret.where(**hsmain) if !hsmain.blank?
#print "DEBUG:plural: hsmain=";p hsmain
#print "DEBUG:plural: build=";p build_or_where_translations(unique_trans_keys, *args, **inprms)
    ret = ret.where(*(build_or_where_translations(unique_trans_keys, *args, **inprms)))
#print "DEBUG:plural: exp2=";p ret.distinct.explain
    ret.distinct
  end

  # Select an array of {BaseWithTranslation} according to the translations
  # of the titles of its associated model-record.
  #
  # For example, {Music} depends on {Artist} and {Engage}.
  # A {Music} is only unique with {Artist} and {Engage} (and year?)
  # in addition to its own title. This method provides a way
  # to get a specific {Music} based on its {#titles} AND
  # those of {Artist} etc.
  #
  # Internally, this method
  #
  # (1) calls {BaseWithTranslation.select_by_translations} for self, then
  # (2) calls {BaseWithTranslation.select_by_translations} for the associated models where the title-condition is {#title} or {#alt_title} but with no language constraint ("any")
  #
  # Procedure 1 may return multiple candidates. They are further filtered in
  # procedure 2.  Ideally, this method should return an array of 0 or 1 {BaseWithTranslation}
  # though it may return more than 1, as, for example, a {Translation} associated with
  # a different object may have the French title as the English title of that of interest.
  #
  # Note that it would be possible to call {Translation.select_regex} instead;
  # it would be more flexible, accepting Regexp, but be much less efficient,
  # given {BaseWithTranslation.select_by_translations} uses an advanced SQL.
  #
  # @param hsmain [Hash] The hash parameters to select the main {BaseWithTranslation}(s) 
  #    For example, the {Translation} of {Prefecture} is unique only within
  #    a {Country}.
  # @param unique_trans_keys [Array] If given, the keys (like [:ruby, :romaji]) is used
  #   to identify the {Translation}. Else {Translation.keys_to_identify} is called
  # @param *args [Array<Integer, Symbol>] Only 1 element. If :auto (Default), [:title, :alt_title]
  #   is used to identify an existing {Translation}. If Integer, it is the size
  #   of the Array of the keys for it according to the order of 
  #   {Translation::TRANSLATED_KEYS}.
  #   For example, if nkeys==2, and inkeys==[:romaji, :alt_title, :ruby, :naiyo]
  #   [:alt_title, :ruby] is returned.
  # @param translations: [Hash<Symbol<Hash>>] translations of {BaseWithTranslation} (NOT those of the associated); e.g., {en: {titles: 'Some name'}}
  # @param **others: [Hash<Symbol<String>>] The keys must be in a form of "artist_title"
  #   when {BaseWithTranslation} has_many (or has_one) relation with {Artist} and the value
  #   is either String or Regexp; e.g., {artist_title: 'Beatles', engage_title: 'Singer'}
  # @return [Array<BaseWithTranslation>]
  # @raise [RuntimeError]
  def self.select_by_associated_titles(*args, translations: {}, **others)
    #raise ArgumentError, "(#{__method__}): translations is empty" if translations.blank?
    ret_cands =
      if translations.empty?
        self.all
      else
        select_by_translations(*args, translations: translations)
      end

    # To give constraints, get candidate self-objects
    hs_conds = {}
    others.each_pair do |ea_tkey, ea_val|
      mat = /(.*)_title\z/.match ea_tkey.to_s
      raise "Invalid option {#{ea_tkey.inspect} => #{ea_val.inspect}} with no such association." if !mat
      model_snake = mat[1]
      model_class = model_snake.camelize.constantize

      possible_snakes = reflections.select{|a, r| %i(has_one has_many).include? r.macro}.values.map{|v| v.name.to_s.singularize}
#print "DEBUG:byassc: (#{model_snake.inspect}, class=#{model_class.name})"; p possible_snakes
      if !possible_snakes.include? model_snake.to_s
        msg = sprintf "Option %s is invalid (no such associated model).", {ea_tkey => ea_val}.inspect
        warn msg
        logger.warn "(#{__method__}): "+msg+"  Skips."
        next
      end

      tr = {any: {titles: ea_val}}
      hs_conds[model_snake] = model_class.select_by_translations(**tr)  # Associated-class instances
#print "DEBUG:byassc:snake:"; p hs_conds[model_snake]

      ## NOTE: the following does not return, e.g., Music objects, but Translation objects,
      ##  though you could do  pluck(:translatable_id)
      # hs_conds[model_snake] = Translation.select_regex(:titles, ea_val, translatable_type: model_snake.camelize) # langcode: nil
    end
#print "DEBUG:byassc:ret_cands:"; p ret_cands
#print "DEBUG:byassc:ret_cands:m:"; p ret_cands[0].musics
#print "DEBUG:byassc:hs_conds:"; p hs_conds

    # Excludes the candidates that do not satisfy the translation-conditions of the associated models
    ret_cands.select{ |final_cand|
      passed = true
      hs_conds.each_pair do |model_snake, models|
        self_models = models.map{|i| i.send(self.name.underscore.pluralize)}.flatten.uniq
        if !self_models.include? final_cand
          passed = false
          break model_snake
        end
      end
      passed
    }
  end



  # Builds a long string of the WHERE clause to select one of the {Traslation}-s.
  #
  # The parameters are prefixed with the word 'translations'.
  #
  # Input Hash (inprms) is like (n.b., it may contain the keys like "strip"?),
  #   {
  #     en: [ {title: 'T1'}, {title: 'T2', is_orig: true, langcode: 'en'} ],
  #     ja:   {title: 'J1'},
  #   }
  #
  # @example return
  #   ["translations.langcode = ? AND translations.title = ? OR "+
  #    "translations.langcode = ? AND translations.alt_title = ?",
  #    'en', 'Abc', 'ja', 'あいう']
  #
  # @param unique_trans_keys [Array] If given, the keys (like [:ruby, :romaji]) is used
  #   to identify the {Translation}. Else {Translation.keys_to_identify} is called
  # @param *args [Array<Integer, Symbol>] Only 1 element. If :auto (Default), [:title, :alt_title]
  #   is used to identify an existing {Translation}. If Integer, it is the size
  #   of the Array of the keys for it according to the order of 
  #   {Translation::TRANSLATED_KEYS}.
  #   For example, if nkeys==2, and inkeys==[:romaji, :alt_title, :ruby, :naiyo]
  #   [:alt_title, :ruby] is returned.
  # @param **inprms [Hash<Symbol>] Like {en: [{title: 'Iran', is_orig: true}]}
  #    Multiple translations can be included.
  #   May include slim_opts (Hash).  Default: {COMMON_DEF_SLIM_OPTIONS}
  # @return [Array<String, Object>] Array that can be directry fed to ActiveRecord_Relation.where()
  def self.build_or_where_translations(unique_trans_keys=nil, *args, **inprms)
    #opts, alltrans = split_hash_with_keys(trans_part[keytrans], COMMON_DEF_SLIM_OPTIONS.keys) # In case it contains options like :strip
    trtbl = Translation.table_name
    arwhere = []
    arprm   = []
    flattened_translations_hash(**inprms).each do |ea_tr| 
      artmp = []
      candkeys = ea_tr.keys.map{|i| (i == :titles) ? [:title, :alt_title] : i}.flatten
      defkeys = (unique_trans_keys || Translation.keys_to_identify(candkeys, *args)+[:titles])
      ea_tr.select{ |k, v| defkeys.include?(k) || 'langcode' == k.to_s}.each_pair do |ek, ev|
#print "DEBUG:build_or: "; p [ek, ev]
        if ek == :titles
          # :titles means (:title "OR" :alt_title)
          artmp.push sprintf('(%s.title = ? OR %s.alt_title = ?)', trtbl, trtbl)
          arprm.push ev, ev
#print "DEBUG:build_or: artmp="; p artmp
        else
          artmp.push sprintf('%s.%s = ?', trtbl, ek.to_s)
          arprm.push ev
        end
      end
      arwhere.push artmp.join(' AND ')
    end

    arprm.unshift arwhere.join(' OR ')
    arprm
  end
  private_class_method :build_or_where_translations

  # Original translation Hash is flattened to an Array
  #
  # Input Hash is like, where 'any' means any language.
  #   { en: [ {title: 'T1'}, {title: 'T2', is_orig: true, langcode: 'en'} ],
  #     ja:   {title: 'J1'},
  #     any:  {titles: 'Something'} }
  #
  # Output Array is like,
  #   [ {langcode: 'en', title: 'T1'},
  #     {langcode: 'en', title: 'T2', is_orig: true},
  #     {langcode: 'ja', title: 'J1'},
  #     {titles: 'Something'} ]
  #
  # @param inhs [Hash<Symbol>]
  # @return [Array<Hash<Symbol>>]
  def self.flattened_translations_hash(**inhs)
    arret = []
    inhs.each_pair do |lc, ea_obj|
      ea_obj = [ea_obj] if ea_obj.respond_to?(:each_pair)
      ea_obj.each do |ea_hs|
        arret.push(((lc.to_s == 'any') ? {} : {langcode: lc.to_s}).merge ea_hs)
      end
    end
    arret
  end
  private_class_method :flattened_translations_hash


  # Wrapper of {BaseWithTranslation.find_all_translations_by_mains} to return {BaseWithTranslation}-s
  #
  # Similar to {BaseWithTranslation.select_regex} but with a slightly
  # different interface.
  #
  # This method finds all the {BaseWithTranslation.select_regex} that
  # are associated with {Translations} that satisfy the given conditions.
  # In other words, no filtering based on any parameters of the
  # {BaseWithTranslation} is applied.
  #
  # If an exact set of title, alt_title, and language is specified,
  # the returned Array should contain at most 1 element, IF {Translation}
  # determines the uniqueness of the {{BaseWithTranslation} .
  #
  # @param *args [Array<Integer, Symbol>] Only 1 element. If :auto (Default), [:title, :alt_title]
  #   is used to identify an existing {Translation}. If Integer, it is the size
  #   of the Array of the keys for it according to the order of 
  #   {Translation::TRANSLATED_KEYS}.
  #   For example, if nkeys==2, and inkeys==[:romaji, :alt_title, :ruby, :naiyo]
  #   [:alt_title, :ruby] is returned.
  # @param inprms [Hash] Should contain at least one of title, alt_tile, ruby etc, in addiotn
  #   to langcode and translatable_type (or translatable to specify the exact counterpart)
  # @return [Array<BaseWithTranslation>]
  # @raise [RuntimeError]
  def self.find_all_by_translation(*args, **inprms)
    find_all_translations_by_mains(*args, **inprms).map{|i| i.translatable}.uniq
  end

  # Find {Translation}-s from the main parameters
  #
  # This is very similar to {BaseWithTranslation.select_translations_regex},
  # except
  #
  # (1) this does not accept Regexp,
  # (2) the conditions are more AND than OR,
  # (3) some parameters in inprms can be ignored.
  #
  # @param *args [Array<Integer, Symbol>] Only 1 element. If :auto (Default), [:title, :alt_title]
  #   is used to identify an existing {Translation}. If Integer, it is the size
  #   of the Array of the keys for it according to the order of 
  #   {Translation::TRANSLATED_KEYS}.
  #   For example, if nkeys==2, and inkeys==[:romaji, :alt_title, :ruby, :naiyo]
  #   [:alt_title, :ruby] is returned.
  # @param inprms [Hash] Should contain at least one of title, alt_tile, ruby etc, in addiotn
  #   to langcode and translatable_type (or translatable to specify the exact counterpart)
  # @return [Translation::ActiveRecord_Relation]
  # @raise [RuntimeError]
  def self.find_all_translations_by_mains(*args, **inprms)
    Translation.find_all_by_mains(*args, translatable_type: self.name, **inprms)
  end


  # Returns the Array of sorted langcodes in order of priority
  #
  # A user-specified langcode if any, {Translation#is_orig}, and
  # {BaseWithTranslation::AVAILABLE_LOCALES}, and any other langcodes
  # that the given Hash has are all considered.
  #
  # @example
  #   Country.sorted_langcodes(first_lang: nil,  hstrans: cntr.best_translations)
  #     #=> ['en', 'ja', 'fr']
  #   Country.sorted_langcodes(first_lang: 'it', hstrans: cntr.best_translations)
  #     #=> ['it', 'en', 'ja', 'fr', 'kr'] (providing hstrans has 'kr' with is_orig=false)
  #
  # @param first_lang: [String, NilClass] user-specified langcode that has the highest priority
  # @param hstrans: [Hash<String => Translation>] Returns of {#best_translations}
  # @return [Array<String>]
  def self.sorted_langcodes(hstrans: , first_lang: nil)
    first_lang = first_lang.to_s if first_lang
    def_locales = AVAILABLE_LOCALES.map{|i| i.to_s}
    ([first_lang]+hstrans.keys).compact.uniq.sort{ |a,b|
      if    a == first_lang
        -1
      elsif b == first_lang
         1
      elsif hstrans[a].is_orig
        -1
      elsif hstrans[b].is_orig
         1
      else
         (def_locales.index(a) || Float::INFINITY) <=> 
         (def_locales.index(b) || Float::INFINITY)
      end
    }
  end


  ###################################
  # Instance methods
  ###################################

  # Gets the best-scored [title, alt_title]
  #
  # Note the alorithm is implemented specifically for this method,
  # instead of calling {#get_a_title}, to avoid too many queries to the DB.
  #
  # @example Suppose no translations for Italian exist. Forces the return to be Italian.
  #   place1.titles(langcode: 'it', lang_fallback_option: :never)
  #     # => [nil, nil]
  #
  # @example Same and no alt_title for Japanese exists. Fallback works and Japanese has a priority due to i18n settings.
  #   place1.titles(langcode: 'it', lang_fallback_option: :either)
  #     # => ['ローマ', nil]
  #
  # @param langcode: [String, NilClass] like 'ja'
  # @param lang_fallback_option: [Symbol] (:both|:either|:never) if :both,
  #    (lang_fallback: true) is passed to both {#title} and {#alt_title}.
  #    If :either, if either of {#title} and {#alt_title} is significant,
  #    the other may remain nil. If :never, [nil, nil] may be returned
  #    (which is also the case where no tranlsations are found in any languages).
  # @return [Array<String, String>] if there are no translations for the langcode, [nil, nil]
  def titles(langcode: nil, lang_fallback_option: :never)
    raise ArgumentError, "(#{__method__}) Wrong option (lang_fallback_option=#{lang_fallback_option}). Contact the code developer."  if !(%i(both either never).include? lang_fallback_option)

    hstrans = best_translations
    arret = [nil, nil]

    # Fallback
    sorted_langs = self.class.sorted_langcodes(first_lang: langcode, hstrans: hstrans)
    sorted_langs.each do |ecode|
      artmp = (hstrans[ecode] && hstrans[ecode].titles)
      if !artmp
        return arret if lang_fallback_option == :never
        next
      end
      arret.each_index do |i|
        arret[i] ||= artmp[i]
      end
      return arret if lang_fallback_option == :never ||
                       arret.all?{|i| !i.blank?} || # both title and alt_title defined for the specified langcode
                      (arret.any?{|i| !i.blank?} && lang_fallback_option == :either)
    end
    arret
  end

  # Returns the best-scored title or alt_title
  #
  # If neither is found, an empty string "" is returned.
  #
  # @param langcode: [String, NilClass] like 'ja'
  # @param lang_fallback_option: [Symbol] (:both|:either|:never) if :both,
  #    (lang_fallback: true) is passed to both {#title} and {#alt_title}.
  #    If :either, if either of {#title} and {#alt_title} is significant,
  #    the other may remain nil. If :never, [nil, nil] may be returned
  #    (which is also the case where no tranlsations are found in any languages).
  # @param prefer_alt: [Boolean] if true (Def: false), alt_title is preferably
  #    returned as long as it exists.
  # @return [String]
  def title_or_alt(langcode: nil, lang_fallback_option: :either, prefer_alt: false)
    cands = titles(langcode: langcode, lang_fallback_option: lang_fallback_option)
    cands.reverse! if prefer_alt
    cands.compact.first || ""
  end

  # Core method for title, alt_title, alt_ruby, etc
  #
  # @param method [Symbol] one of %i(title alt_title ruby alt_ruby romaji alt_romaji)
  # @param langcode: [String, NilClass] like 'ja'
  # @param lang_fallback: [Boolean] if true, when no translation is found
  #    for the specified language, that of another language is returned
  #    unless none exists.
  # @return [String, NilClass] nil if there are no translations for the langcode
  def get_a_title(method, langcode: nil, lang_fallback: false)
    ret = (translations_with_lang(langcode)[0].public_send(method) rescue nil)
    return ret if ret || !lang_fallback

    ## Falback after no translations are found for the specified language.
    hstrans = best_translations
    hstrans.each_pair do |ek, ev|
      ret = ev.public_send(method)
      return ret if !ret.blank?
    end
    nil
  end
  private :get_a_title

  # Gets the best-score title
  #
  # @param langcode: [String, NilClass] like 'ja'
  # @param lang_fallback: [Boolean] if true, when no translation is found
  #    for the specified language, that of another language is returned
  #    unless none exists.
  # @return [String, NilClass] nil if there are no translations for the langcode
  def title(**kwd)
    get_a_title(__method__, **kwd)
  end

  # Gets the best-score ruby
  #
  # @param langcode: [String, NilClass] like 'ja'
  # @return [String, NilClass] nil if there are no translations for the langcode
  def ruby(**kwd)
    get_a_title(__method__, **kwd)
  end

  # Gets the best-score romaji
  #
  # @param langcode: [String, NilClass] like 'ja'
  # @return [String, NilClass] nil if there are no translations for the langcode
  def romaji(**kwd)
    get_a_title(__method__, **kwd)
  end

  # Gets the best-score alt_title
  #
  # @param langcode: [String, NilClass] like 'ja'
  # @return [String, NilClass] nil if there are no translations for the langcode
  def alt_title(**kwd)
    get_a_title(__method__, **kwd)
  end

  # Gets the best-score alt_ruby
  #
  # @param langcode: [String, NilClass] like 'ja'
  # @return [String, NilClass] nil if there are no translations for the langcode
  def alt_ruby(**kwd)
    get_a_title(__method__, **kwd)
  end

  # Gets the best-score alt_romaji
  #
  # @param langcode: [String, NilClass] like 'ja'
  # @return [String, NilClass] nil if there are no translations for the langcode
  def alt_romaji(**kwd)
    get_a_title(__method__, **kwd)
  end

  # Gets the original {Translation}, meaning the original word(s)
  #
  # @example to get the language of the original word
  #   obj.orig_translation.langcode  # => 'ja'
  #   # == obj.orig_langcode
  #
  # @return [Translation, Nilclass] nil if no {Translation} has {Translation#is_orig}==true 
  def orig_translation
    translations.where(is_orig: true)[0]
  end
  alias_method :original_translation, :orig_translation if ! self.method_defined?(:original_translation)

  # Gets the language-code of the original {Translation}, meaning the original word(s)
  #
  # @return [String, NilClass]
  def orig_langcode
    tra = orig_translation
    tra && tra.langcode
  end
  alias_method :original_langcode, :orig_langcode if ! self.method_defined?(:original_langcode)

  # Gets the sorted {Translation}-s of a specific language
  #
  # The highest-rank one (lowest in score) comes first (index=0).
  #
  # @param langcode [String, NilClass] if nil, the same as the entry of is_orig==TRUE
  # @return [ActiveRecord::AssociationRelation, Array]
  def translations_with_lang(langcodearg=nil, langcode: nil)  # langcode given both in the main argument and option to be in line with {#titles} etc.
    begin
      langcode = (langcodearg || langcode || orig_translation.langcode).to_s
    rescue NoMethodError
      if self.id  # If not, self may be a new one and certainly has no translations.
        msg = "(#{__method__}) Failed to determine langcode for self=#{self.inspect} ; continue with a random language."
        logger.warn msg
        # warn msg
      end
      return Translation.sort(translations)
    end

    if !AVAILABLE_LOCALES.include? langcode.to_sym
      logger.warn "(#{__method__}) langcode=#{langcode} unavailable in the environment (available=#{I18n.available_locales.inspect})."
      # MultiTranslationError::UnavailableLocaleError
    end

    Translation.sort(translations.where(langcode: langcode.to_s))
  end

  # Gets Hash of best {Translation}-s with keys of langcodes
  #
  # @return [Hash] like {'ja': <Translation>, 'en': <Translation>}
  def best_translations
    hsret = {}
    translations.each do |ea_t|
      hsret[ea_t.langcode] ||= []
      hsret[ea_t.langcode].push(ea_t)
    end
    hsret.each_key do |ea_k|
      hsret[ea_k] = Translation.sort(hsret[ea_k])[0]
    end
    hsret
  end

  # Creates {Translation}-s which are assciated to self.
  #
  # The argument must be a Hash with keys of langcodes, e.g.,
  #   a.create_translations!(ja: [{title: 'イマジン'}], en: {title: 'Imagine', is_orig: true})
  #
  # See {#create_translation!} for the options.
  #
  # @param slim_opts [Hash] Options to trim {Translation}.  Default: {COMMON_DEF_SLIM_OPTIONS}
  #   convert_spaces: [Boolean] if True (Default), all blanks+returns are converted to ASCII spaces.
  #   convert_blanks: [Boolean] if True (Default), all blanks (spaces or tabs) are converted to ASCII spaces.
  #   strip: [Boolean] if True (Default), all strings are stripped with initial and trailing spaces.
  #   trim: [Boolean] if True (Default), all multiple spaces are trimmed to a single space.
  # @param unique_trans_keys [Array] If given, the keys (like [:ruby, :romaji]) is used
  #   to identify the {Translation}. Else {Translation.keys_to_identify} is called
  # @param **kwds [Hash<Symbol, Hash, Array<Hash>>] to pass to {Translation}.new
  # @return [Array<Translation>]
  def create_translations!(slim_opts={}, unique_trans_keys=nil, **kwds) ## convert_spaces: true, convert_blanks: true, strip: true, trim: true, **kwds)  ###############
    update_or_create_translations_core(:create!, slim_opts, unique_trans_keys, **kwds)
  end

  # Same as {#create_translations!} but it may update! instead of create!
  #
  # @param (see BaseWithTranslation#create_translations!)
  # @param slim_opts [Hash] Options to trim {Translation}.  Default: {COMMON_DEF_SLIM_OPTIONS}
  # @param unique_trans_keys [Array] If given, the keys (like [:ruby, :romaji]) is used
  #   to identify the {Translation}. Else {Translation.keys_to_identify} is called
  # @return [Array<Translation>]
  def update_or_create_translations!(slim_opts={}, unique_trans_keys=nil, **kwds)
    update_or_create_translations_core(:update_or_create_by!, slim_opts, unique_trans_keys, **kwds)
  end

  # Core routine for {#create_translations!} and {#update_or_create_translations!}
  #
  # @param method [Symbol] Either :create! or :update_or_create_by!
  # @param slim_opts [Hash] Options to trim {Translation}.  Default: {COMMON_DEF_SLIM_OPTIONS}
  # @param unique_trans_keys [Array] If given, the keys (like [:ruby, :romaji]) is used
  #   to identify the {Translation}. Else {Translation.keys_to_identify} is called
  # @param **kwds [Hash<Symbol>] to pass to {Translation}.new
  # @return [Array<Translation>]
  def update_or_create_translations_core(method, slim_opts={}, unique_trans_keys=nil, **kwds)
    #hscommon, outkwds = split_hash_with_keys(kwds, COMMON_DEF_SLIM_OPTIONS.keys)
    #hscommon = COMMON_DEF_SLIM_OPTIONS.merge hscommon
    if kwds.empty?
      raise ArgumentError, "(#{__method__}) Argument is empty."
    end
    
    arret = []
    kwds.each_pair do |ek, ev|
      (ev.respond_to?(:rotate!) ? ev : [ev]).each do |ea_hs_lang|
#begin
        hstmp = ea_hs_lang.merge({langcode: ek.to_s})
#rescue
#  print "DEBUG:core1:kwds=";p kwds
#  raise
#end
        arret.push update_or_create_translation_core(method, slim_opts, unique_trans_keys, **hstmp)
      end
    end
    arret
  end
  private :update_or_create_translations_core


  # Creates {Translation}-s which are assciated to self.
  #
  # Wrapper of {#create_translations!} to return self
  #
  # The argument must be a Hash with keys of langcodes, e.g.,
  #   a.create_translations(ja: [{title: 'イマジン'}], en: {title: 'Imagine', is_orig: true})
  #
  # @param **kwds [Hash<Symbol, Hash, Array<Hash>>] to pass to {Translation}.new
  # @return [self]
  def with_translations(**kwds)
    create_translations!(**kwds)
    self.reload  # Without reload, {#translations} may return nil.
  end

  # Same as {#with_translations} but may update the record.
  #
  # @param **kwds [Hash<Symbol>] to pass to {Translation}.new
  # @return [self]
  def with_updated_translations(**kwds)
    update_or_create_translations!(**kwds)
    self.reload  # Without reload, {#translations} may return nil.
  end


  # Creates a {Translation} which is assciated to self.
  #
  # The argument must be a Hash with keys of langcodes, e.g.,
  #   a.create_translation!(langcode: en, title: 'Imagine', is_orig: true)
  #
  # Keywords langcode and title must be specified at least.
  # title can be nil, as long as at least one of the other 5 keywords
  # (alt_title, ruby, alt_ruby, romaji, alt_romaji) is non-blank.
  #
  # Note that you probably want to include for the first one:  is_orig: true
  #
  # @param convert_spaces: [Boolean] if True (Default), all blanks+returns are converted to ASCII spaces.
  # @param convert_blanks: [Boolean] if True (Default), all blanks (spaces or tabs) are converted to ASCII spaces.
  # @param strip: [Boolean] if True (Default), all strings are stripped with initial and trailing spaces.
  # @param trim: [Boolean] if True (Default), all multiple spaces are trimmed to a single space.
  # @param **kwds [Hash<Symbol>] to pass to {Translation}.new
  # @return [Translation]
  def create_translation!(**kwds)
    update_or_create_translation_core(:create!, **kwds)
  end


  # Same as {#create_translation!} but it may update! instead of create!
  #
  # @param (see BaseWithTranslation#create_translation!)
  # @return [Translation]
  def update_or_create_translation!(**kwds)
    update_or_create_translation_core(:update_or_create_by!, **kwds)
  end


  # Core routine for {#create_translation!} and {#update_or_create_translation!}
  #
  # @param method [Symbol] Either :create! or :update_or_create_by!
  # @param slim_opts [Hash] Options to trim {Translation}.  Default: {COMMON_DEF_SLIM_OPTIONS}
  # @param unique_trans_keys [Array] If given, the keys (like [:ruby, :romaji]) is used
  #   to identify the {Translation}. Else {Translation.keys_to_identify} is called
  # @param **kwds [Hash<Symbol>] to pass to {Translation}.new
  # @return [Translation]
  def update_or_create_translation_core(method, slim_opts={}, unique_trans_keys=nil, **kwds)
    raise "(#{__method__}) Contact the code developer... kwds=#{kwds.inspect}" if kwds.keys.any?{|i| COMMON_DEF_SLIM_OPTIONS.keys.include? i}
    %i(title langcode).each do |ek|
      if !kwds.key? ek
        raise ArgumentError, "(#{__method__}) #{ek.to_s} is mandatory but is unspecified."
      end
    end

    if kwds[:langcode].blank?
      warn "(#{__method__}) langcode is given blank, which should not be: kwds=#{kwds.inspect}"
      logger.warn "(#{__method__}) langcode is blank, which should not be: self=#{self.inspect}, kwds=#{kwds.inspect}"
    end

    hs = {
      translatable_type: self.class.name,
      translatable_id: (self.id || self.reload.id),
      slim_opts: slim_opts,
      #skip_preprocess_callback: !slim_opts.empty?,
    }

    Translation.send(method, **(hs.merge(kwds)))
  end
  private :update_or_create_translation_core


  # Creates a {Translation} which is assciated to self.
  #
  # Wrapper of {#create_translation} to return self
  #
  # Note that you probably want to include for the first one:  is_orig: true
  # or simply use {#with_orig_translation} instead (so you don't forget it).
  #
  # @param **kwds [Hash<Symbol>] to pass to {Translation}.new
  # @return [self]
  def with_translation(**kwds)
    create_translation!(**kwds)
    self.reload
  end

  # Same as {#with_translation} but may update the record.
  #
  # @param **kwds [Hash<Symbol>] to pass to {Translation}.new
  # @return [self]
  def with_updated_translation(**kwds)
    update_or_create_translation!(**kwds)
    self.reload
  end


  # Creates a {Translation} with (is_orig: true) which is assciated to self.
  #
  # Wrapper of {#create_translation!} to return self.
  #
  # Note that if is_orig option is explicitly given, it has a priority.
  #
  # Two optional parameters title (which can be nil) and langcode are mandatory.
  #
  # @example For a child class, Country
  #   Country.create!.with_orig_translation(title: 'New Zealand', lang: 'en')
  #
  # @param **kwds [Hash<Symbol>] to pass to {Translation}.new
  # @return [self]
  def with_orig_translation(**kwds)
    create_translation!(**({is_orig: true}.merge(kwds)))
    self.reload
  end

  # Same as {#with_orig_translation} but may update the record.
  #
  # @param **kwds [Hash<Symbol>] to pass to {Translation}.new
  # @return [self]
  def with_orig_updated_translation(**kwds)
    update_or_create_translation!(**({is_orig: true}.merge(kwds)))
    self.reload
  end


  # Returns the Hash of the best translated_words of all languages
  #
  # @param attr [String, Symbol] method name
  # @param safe: [Boolean] if true, this returns '' instead of nil.
  # @return [Hash] key(langcode) => word (maybe nil)
  def all_best_titles(attr=:title, safe: false)
    AVAILABLE_LOCALES.map{ |ec|
      val = send(attr, langcode: ec.to_s) 
      val = '' if !val && safe
      [ec.to_s, val]
    }.to_h
  end

  # Get an object based on the given "name" (title etc)
  #
  # Where a potential definite article is considered.
  #
  # @param name [String
  # @return [BaseWithTranslation, NilClass] nil if no match
  def self.find_by_name(name)
    name2chk = preprocess_space_zenkaku(name, **COMMON_DEF_SLIM_OPTIONS)
    re, rootstr, the = definite_article_with_or_not_at_tail_regexp(name2chk) # in ModuleCommon

    db_style_str     = rootstr + (the.empty? ? "" : ', ' + the)
    db_style_str_cap = rootstr + (the.empty? ? "" : ', ' + the.capitalize)

    alltrans = self.select_translations_regex(:titles, re)
    return nil if alltrans.empty?

    alltrans.sort{|a,b|
      if    a.titles.include? db_style_str
        -1
      elsif b.titles.include? db_style_str
        1
      elsif a.titles.include? db_style_str_cap
        -1
      elsif b.titles.include? db_style_str_cap
        1
      elsif a.titles.map{|i| i.downcase}.include? db_style_str.downcase
        -1
      elsif b.titles.map{|i| i.downcase}.include? db_style_str.downcase
        1
      elsif a.titles.map{|i| definite_article_stripped(i)}.include? rootstr
        -1
      elsif b.titles.map{|i| definite_article_stripped(i)}.include? rootstr
        1
      elsif a.titles.map{|i| definite_article_stripped(i).downcase}.include? rootstr.downcase
        -1
      elsif b.titles.map{|i| definite_article_stripped(i).downcase}.include? rootstr.downcase
        1
      else
        0
      end
    }.first.translatable
  end

  # Returns an Array of combined {#title} and {#alt_title} for auto-complete
  #
  # Definite articles are considered.
  #
  # @return [Array<String>]
  def self.titles_for_form
    alltitles = Translation.where(translatable_type: self.name).pluck(:title, :alt_title).flatten.select{|i| !i.blank?}
    alltitles.map{|i|
      root, the = partition_root_article(i)
      if the.empty?
        root
      else
        [the+" "+root, root, root+", "+the]
      end
    }.flatten.uniq
  end

  ######################
  
  # Logs a warning if is_orig is undefined in any of them.
  #
  # @param ar_trans [ActiveRecord::Associations::CollectionProxy] practially an Array
  # @param mend: [Boolean] If true, and if the DB record is simply fixable, do so.
  # @return [Symbol, NilClass] nil if perfect. Symbol if a problem is found.
  def _check_and_log_is_orig(mend: true)
    originals = translations.select{|i| i.is_orig}

    if originals.size == 1
      tra = originals[0]
      return if tra.weight == 0

      logger.warn "Updated weight=(#{tra.weight.inspect}) to 0 because is_orig is true for "+tran_inspect_msg(tra)+" in Table: #{originals[0].class.table_name}"
      if mend
        tra.weight = 0
        tra.save!
      end
      return :weight_nonzero
    end

    if originals.size == 0
      logger.warn "No translation is original for "+tran_inspect_msg(ar_trans[0])+" in Table: #{originals[0].class.table_name}"
      return :non_is_orig
    end

    if originals.size > 1
      # More than 1 original.
      return :multiple_is_orig
    end

    raise # should not come
  end

  # after_create callback/hook
  #
  # When self is a new record, {Translation} cannot be associated
  # before self is saved and id is assigned.  This after_create callback
  # offers a scheme to handle it; this callback saves "unsaved-translations"
  # stored in {BaseWithTranslation#unsaved_translations}.
  #
  # If one of {Translation} fails to be saved, it raises an Exception
  # (in {Translation#save!}), hence none of self and {Translation}-s
  # are saved to the DB, either, because the DB rollbacks before
  # the final commit happens after this callback
  # (remember this callback comes before the after_commit callback).
  #
  # Note it does mean even self.save (as opposed to save!) may raise
  # a validation Exception.
  #
  # @raise [ActiveRecord::RecordInvalid]
  def save_unsaved_translations
    return if new_record? || changed?

    # This should be redundant as self.translations for new_record
    # should always return an empty relation [].
    translations.each do |ea_t|
      ea_t.save! if ea_t.new_record? || ea_t.changed?
    end

    return if @unsaved_translations.blank?
    n_trans = @unsaved_translations.size
    @unsaved_translations.reverse.each_with_index do |translation, i|
      translation.translatable = self
      is_valid = translation.valid?
      if !is_valid
        #msg = sprintf('Translation(%s): %s', (n_trans-i).ordinalize, translation.errors.full_messages.inspect)
        #self.errors.add :base, msg
        prefix = sprintf('Translation(%s): ', (n_trans-i).ordinalize)
        transfer_errors(translation, prefix: prefix)  # defined in ModuleCommon
      end
    end

    raise ActiveRecord::RecordInvalid.new(self) if self.errors.size > 0
    #raise ActiveRecord::RecordInvalid, self.errors.full_messages.map(&:to_s).join(";") if !ar.empty?  # NOTE: bizzarly raises: NoMethodError: undefined method `errors' for ...:String

    @unsaved_translations.reverse.each do |translation|
      translation.save!
      @unsaved_translations.pop
    end
  end

  private

    # @param tra [BaseWithTranslation]
    # @return [String]
    def tran_inspect_msg(tra)
      "(ID=#{tra.id}, lc=#{tra.langcode.inspect}) title=#{tra.title.inspect}"
    end


    ## before_validation callback, which may be defined in a child Class ({HaramiVid}, {Music})
    def add_default_place
      self.place = ((self.class.const_defined?(:DEF_PLACE) && self.class::DEF_PLACE) || Place.unknown || Place.first) if !self.place
    end

    ## before_validation callback, which may be defined in a child Class ({Music})
    def add_default_genre
      self.genre = (Genre.unknown || Genre.first) if !self.genre
    end
end
