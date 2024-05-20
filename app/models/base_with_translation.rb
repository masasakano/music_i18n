# -*- coding: utf-8 -*-

# Abstract base Class for any class that is associated with a Translation class
#
# == Usage
#
# The child model of this class should define two constants of
# +MAIN_UNIQUE_COLS+ and +ARTICLE_TO_TAIL+ (see farther down for detail) like this:
#
#   class MyChildKlass < BaseWithTranslation
#     MAIN_UNIQUE_COLS = []
#     ARTICLE_TO_TAIL = true
#
# They can also define the following to bypass the validation by Translation
# to check the identicalness of title and alt_title and raise an alert:
#     ALLOW_IDENTICAL_TITLE_ALT = true/false
#
# Add the following if the class should not allow multiple identical title/alt_title .
# As a counter-example, Music does NOT include this (famously there are two songs, "M").
#
#     def validate_translation_callback(record)
#       validate_translation_neither_title_nor_alt_exist(record)  # defined in ModuleCommon included in this file.
#     end
#
# Alternatively, add the following to validate the uniquness of translations 
# against its parent (like Place and Prefecture; +Place.unknown+ have many identical titles for different {Prefecture}).
#
#     # Validates if a {Translation} is unique within the parent
#     #
#     # Fired from {Translation}
#     #
#     # @param record [Translation]
#     def validate_translation_callback(record)
#       validate_translation_unique_within_parent(record)
#     end
#
# To Create with the UI is tricky.  You would want a Translation as an input
# (n.b., for Update, it can be simply handled by the Transation model).
# This means +params+ to give to the Model contains unusual parameters,
# which would mess up Rails +permit+, especially with authorization (with CanCanCan).
# Consult EventGroup Controller and views for how to do it. Both Controller and
# Views should be carefully adjusted.  There are several helper methods.
#
# == Methods of title, langcode etc
#
# The writer methods for the 8 keys defined in {Translation::TRANSLATION_PARAM_KEYS} 
# are accepted in the child classes of this class, but only on new (create).
# With these you can initialize or create a record in a form of
#
#   Sex.create!(iso5218: 99, title: "new gender", langcode: "en", is_orig: nil)
#   Sex.new(    iso5218: 99, title: "新しい性",   langcode: "ja", ruby: "アタラシイセイ")
#
# which creates or initialize, respectively, a {Sex} record with a single {Translation}.
# There are several points to be aware of.
#
# * If any of the Translation-related paramters is specified, +langcode+
#   (locale) and at least either (or both) of +title+ and +alt_title+ are mandatory.
#   Usually, +is_orig+ is recommended.  Or, specify none of them.
# * Specifying them is allowed only at the timing of initialization.
# * For this reason, these parameters cannot be specified in +updaete+ or +update!+
# * In other words, the form like +self.title="ABC"+ is practically never used.
#   The writer methods are defined for the sole purpose of making the +new+ method to recognize them.
# * The corresponding reader methods like +title+ are either not defined
#   or defined to mean something different. For example, the reader +langcode+ is not defined.
#   +title+ access (multiple) associated Translation-s and choose one. 
# * Although the direct reader methods mean differently (or undefined like +is_orig+),
#   the keywords of "title" etc can be still used for +new+ controllers because
#   the raeder methods actually read +@unsaved_translations+ (see below) instead of
#   Rails-associated Translation.  However, never use the keywords for anything but +new+ views
#   and never try to read them in Controllers (except in the arguments of methods of +new+ and +create+).
# * +weight+ is not included in the key (because some children models have their own +weight+ defined).
# * In initialization (with +new+), the Translation is stored as an unsaved Translation
#   in the first element of an Array +unsaved_translations+. Technically, you can
#   specify them with Rails' standard association like +translations << Translation.new+
#   at the same time, but we do not recommend it because we have implemented direct assignment of
#   +title+ etc at initialization with +new+ and +create+, which does not work well
#   with the default association scheme (see {#put_a_title} for detail).
# * If both +unsaved_translations+ and Rails' association of {Translation} are
#   specified for a {#new_record?}, the former has a priority.  If only the latter is
#   specified, I think it would still work OK, though not tested.
# * To add a +weight+ to Translation or modify other parameters during initialization,
#   do so with +unsaved_translations+ like this:
#      sex = Sex.new(iso5218: 99, title: "新しい性", langcode: "ja")
#      sex.unsaved_translations.weight = 100
#      sex.unsaved_translations.alt_title = "新性"
# * {Translation}-s in +unsaved_translations+ are *not* +valid?+ unlike
#   those of Rails' associations.  But they are automatically and expectedly
#   saved +after_create+.
# * +unsaved_translations+ should never be defined for a saved record.
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
# Checking the translated {Translation#title} alone is inadequate.  For example,
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
#     person1 = Artist.create_with_translation!(
#        sex: Sex.find(0), note: 'With added/updated translations.',
#       translation: {title: 'p1-title--jaaa', langcode: 'ja', is_orig: true, weight: 1000})
#     person2 = Artist.create_with_translations!(
#       {sex: Sex.find(0), note: 'With added/updated translations.'},
#       translations: {ja: {title: 'p2-title--jaaa', is_orig: false}, en: {title: 'p2-title--ennn', is_orig: true}})
#     person3 = Artist.create!(sex: Sex.find(0), note: "My-note").with_translation(title: 'p3-title--jaaa', langcode: 'ja', is_orig: true)
#     person4 = Artist.create!(sex: Sex.find(0), note: "My-note").with_translations(ja: {title: 'p4-title--jaaa', langcode: 'ja', is_orig: true})
#     person5 = Artist.new(sex: Sex.find(0), note: 'ABC'};
#       person5.unsaved_translations << Translation.new(title: 'p5-title--jaaa', langcode: 'ja', is_orig: true);
#       person5.save!
#   else  # To edit an existing Artist record.
#      ActiveRecord::Base.transaction(requires_new: true) do  # person is not saved if Translation fails to be saved.
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
#    ActiveRecord::Base.transaction(requires_new: true) do  # person is not saved if Translation fails to be saved.
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
# implementation. Both the processes are treated in a (series of) method in one go;
# the core routine is {BaseWithTranslation.update_or_create_with_translations_core!},
# and even its public wrappers are similar. Basically, they accept the arguments:
#
# * hsmain : columns for the main entries unique to the record (eg., geo-location) used for identification/update
# * unique_trans_keys : which keys (title, alt_title?) are used to identify a record.
# * mainkeys : which keys in hsmain are used to identify the record.
# * hs_trans : Translation (used for both identification/update)
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
#   b.titles(langcode: nil, lang_fallback_option: :never, str_fallback: nil)
#   b.title_or_alt(prefer_alt: false, langcode: nil, lang_fallback_option: :either, str_fallback: "", article_to_head: true)
#   b.title(langcode: nil, lang_fallback: false, str_fallback: nil) # See below re fallback
#   b.ruby
#   b.romaji
#   b.alt_title
#   b.alt_ruby
#   b.alt_romaji
#   b.orig_translation  # Original translation (there should be only 1)
#   b.orig_langcode     # Original language code
#   b.translations_with_lang(langcode=nil)  # Sorted {Translation}-s of a specific (or original) language
#   b.best_translations                          # => {'ja': <Translation>, 'en': <Translation>}
#   b.all_best_titles(attr=:title, safe: false)  # => {'ja': 'イマジン', 'en': 'Imagine'} (with_indifferent_access)
#  
#   b.create_translations!(          ja: [{title: 'イマジン'}], en: {title: 'Imagine', is_orig: true})
#   b.update_or_create_translations!(ja: [{title: 'イマジン'}], en: {title: 'Imagine', is_orig: true})
#     # => [Translation, [Translation, ...]]
#   b.with_translations(             ja: [{title: 'イマジン'}], en: {title: 'Imagine', is_orig: true})
#   b.with_updated_translations(     ja: [{title: 'イマジン'}], en: {title: 'Imagine', is_orig: true})
#     # => [BWT, [BWT, ...]]  # calling create, with NO update
#   b.create_translation!(          langcode: 'en', title: 'Imagine', is_orig: true)
#   b.update_or_create_translation!(langcode: 'en', title: 'Imagine', is_orig: true)
#     # =>  Translation
#   b.with_translation(             langcode: 'en', title: 'Imagine', is_orig: true)
#   b.with_updated_translation(     langcode: 'en', title: 'Imagine', is_orig: true)
#     # =>  BWT  # calling create, with NO update
#   b.with_orig_translation(        langcode: 'en', title: 'Imagine')
#   b.with_orig_updated_translation(langcode: 'en', title: 'Imagine')
#     # =>  BWT  # calling create, with NO update
#
#   # Filtered by both Artist and Music names
#   Artist[/Lennon/, "en"].musics.joins(:translations).where("translations.title": "Imagine").first
#     # =>  Music "Imagine" by John Lennon.
#
# === fallback
#
# Language priority and fallback are not trivial.
#
# The core alrorithm to determine the priority is #{BaseWithTranslation.sorted_langcodes}.
# In short,
#
# 1. Caller-specified (NOT WEB-browser's implicit request)
# 2. Translation with +is_orig+ of true, if there is any
# 3. Hard-coded order in this app.
#
# Notice the priorities of 1 and 2.
# In many of the methods in this class, the following options are available.
#
# * +langcode+: highest-priority locale (usually String).
#   * In default, it is a hard-coded one, hence NOT user-specified.  You may specify +langcode: I18n.locale+
# * +fallback+ or +lang_fallback+ or +lang_fallback_option+: controls how fallback is handled.
#   * For methods that return a single value (but +title_or_alt+), either of the formers (Boolean) is specified. Default is false (no fallback!).
#   * For the others, the latter (Symbol) is specified. Default is +:either+, meaning only one of them follows +lang_fallback=true+ and the other just follows it.
# * +str_fallback+: What object is returned when everything fails.
#   * Default is nil for most of them, but an empty string "" for +titles+ and +title_or_alt+
#
# In short, if you simply want the (best-translation) String for any language
# but preferably the user's choice, specify one of the following:
#
#   b.title_or_alt(langcode: I18n.locale)
#   b.title_or_alt(langcode: I18n.locale, prioritize_orig: true)
#   b.title_or_alt_tuple_str(langcode: I18n.locale)  # => "The Beatles (ザ・ビートルズ)"
#
# which returns at least one String (n.b., either title or alt_title should be defined
# for at least one language in normal circumstances and therefore this should usually
# returnn a non-empty String; strictly speaking, +Translation::UniqueCombiValidator+
# allows for a single object with both title and alt_title being nil per Parent class
# and so it might happen). In default, nil is never returned (Default +str_fallback+ is +""+).
# You may also specify +prefer_alt: true+ in some cases like Country.
#
# If you do want +title+ only, you are recommended to add +lang_fallback+ option
# (otherwise, it may be nil):
#
#   b.title(langcode: I18n.locale, lang_fallback: true)
#
# Note that a {Translation} is required to have *EITHER* +title+ or +alt_title+,
# meaning it may not have +title+ but +alt_title+ only.
#
# === unsaved_translations
#
# This class implements {#unsaved_translations} which basically retains
# for a new record ({#new_record?} == true) an Array of unsaved {Translation}-s
# with +translatable_type+ (and id) being nil.  It should be an empty Array
# for the existing record, though.
#
# Selected translation-related methods are available for a new record regardless of
# whether significant {#unsaved_translations} are defined or not, including
#
# * {#title}
# * {#alt_title}  (but NOT {#title_or_alt})
# * {#alt_ruby}
# * {#orig_translation}
# * {#orig_langcode}
# * {#best_translation}  (but NOT {#best_translations})
# * {#translations_with_lang}
# * {#best_translation_is_orig}
#
# They are of particular use with simple_form becaseu simple_form requires a model
# to have a method for the best use, such as, highlighting the exact forms with erroneous inputs.
#
# === Troubleshooting
#
# * If a link-String like "ja/artists/123" is visible on the website, this may be because of
#   the lack of the link String; e.g., the link String in +link_to(a.title, new_b_path)+
#   may be nil, in which case output String of +new_b_path()+ is displayed!
#
# === Essential settings in Child classes
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

  include Translatable  # Key relation - polymorphic with Translation; defined in /app/models/concerns/translatable.rb
  include SlimString
  extend  ModuleCommon  # for split_hash_with_keys and update_or_create_by_with_notouch!()
  include ModuleCommon  # for split_hash_with_keys

  # Custome exception
  #
  # A way to define recommended by a person in Stackoverflow:
  # <https://stackoverflow.com/a/47115392/3577922>
  class MissingRequirementError < StandardError; end

  class UnsavedTranslationsValidator < ActiveModel::Validator
    # Validate unsaved_translations if defined.
    def validate(record)
      return if record.unsaved_translations.blank?

      if !record.new_record?
        msg_base = "unsaved_translations has to be blank for an existing entity. Contact the code developer: #{record.inspect}"
        Rails.logger.error "ERROR: "+msg_base
        msg =
          if ModuleWhodunnit.whodunnit && ModuleWhodunnit.whodunnit.an_admin?
            "[admin-message] "+msg_base
          else
            "internal error re #{record.class.name}#unsaved_translations. Contact the code developer."
          end
        record.errors.add :base, msg
        return
      end

      record.unsaved_translations.each do |tra|
        kwdmsgs = []
        if !tra.valid_main_params?(kwd_messages: kwdmsgs)
          kwdmsgs.each do |em|
            record.errors.add em[0], em[1]
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

  AVAILABLE_LOCALES = I18n.available_locales  # :ko, :zh, ...
  LANGUAGE_TITLES = {
    ja: {
      'ja' => '日本語',
      'en' => '英語',
      'fr' => '仏語',
    }.with_indifferent_access,
    en: {
      'ja' => 'Japanese',
      'en' => 'English',
      'fr' => 'French',
    }.with_indifferent_access,
    fr: {
      'ja' => 'Japonais',
      'en' => 'Anglais',
      'fr' => 'Français',
    }.with_indifferent_access,
  }.with_indifferent_access

  # Hash to specify the priority among the available locales
  HS_LOCALE_PRIORITY = AVAILABLE_LOCALES.map.with_index{|lc, i| [lc, i]}.to_h # Index mapping

  alias_method :inspect_orig, :inspect if ! self.method_defined?(:inspect_orig)

  # Unsaved {Translation}-s for a new record which would be created when self is saved.
  #attr_accessor :unsaved_translations
  attr_reader :unsaved_translations

  # @param ary [Array<Translation>]
  def unsaved_translations=(ary)
    if !ary.respond_to?(:each) || !ary.respond_to?(:[]) || ary[0] && !ary[0].respond_to?(:title)
      # This should never happen.  Putting this for coding safety.
      raise "ERROR(#{__method__}): unsaved_translations must be an Array of Translation-s. Contact the code developer. ary=(#{ary.inspect})"
    end
    @unsaved_translations = ary
  end

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
  # L and N means the numbers of the unique languages and total translations, respectively.
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
  # +self.[]+ returns a first one without translations (which may be nil).
  #
  # In short, this method is useful for debugging and testing, but 
  # should not be used in the production code.
  #
  # In practice,
  #   Artist[/^ハラミちゃん/, 'ja', true)
  # is equivalent to either of the two:
  #   Artist.select_regex(:titles, /^ハラミちゃん/, langcode: 'ja').first
  #   Artist.select_translations_regex(:titles, /^ハラミちゃん/, langcode: 'ja').first.translatable
  #
  # Note that +sql_regexp+ option is not given to {BaseWithTranslation.select_regex},
  # which means this uses the Ruby Regexp (not efficient) and runs 2 SQL queries.
  #
  # The following is more efficient, runs only 1 SQL query, though the Regexp must be compatible
  # with the PostgreSQL format (e.g., the lookbehind option etc would not work?):
  #   Artist.select_regex(:titles, /^ハラミちゃん/, langcode: 'ja', sql_regexp: true).distinct.first
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

  # Returns a single default Object of the class, only if there is such a thing
  #
  # Valid only for the classes that have the +weight` attribute like {Genre} and {EngageHow}.
  #
  # @return [BaseWithTranslation, NilClass] nil only if no records at all are found.
  # @raise [NoMethodError] if weight is not defined in the sub-class.
  def self.default
    raise NoMethodError if !has_attribute?(:weight)
    # EngageHow.all.order(:weight).first
    self.order(Arel.sql('CASE WHEN weight IS NULL THEN 1 ELSE 0 END, weight')).first # valid in any SQL database systems
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

  # Find all {BaseWithTranslation} instances that have no associated translations defined
  #
  # @return [Relation] of self
  def self.find_all_without_translations
    sql = sprintf("LEFT JOIN translations ON %s = translations.translatable_id AND translations.translatable_type = '%s'",self.table_name+'.id', self.name) 
    self.joins(sql).where('translations.translatable_id IS NULL')
  end

  # Creates a {BaseWithTranslation} accompanied with multiple {Translation}-s.
  #
  # Very similar to {BaseWithTranslation#create_with_translation!} except
  # this accepts multiple translations and hence the argument format differs.
  #
  # Wrapper of {BaseWithTranslation#create!} and {#with_translations} (which is
  # similar to {#create_translations!} but returns self) to return {BaseWithTranslation}.
  # Basically the following two are *nearly* equivalent, e.g.,
  #   Music.create_with_translations!(note: 1950, translations: {ja: [{title: 'イマジン'}]})
  #   Music.create!(note: 1950).with_translations(ja: [{title: 'イマジン'}])
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
  # @param reload [Boolean] If true (Def), self is reloaded after Creation.
  #   One more DB query is incurred, but recommended!
  # @param **hs_trans [Hash<Symbol>] Hash for multiple {Translation}-s
  #   Must contain the optional key :translations
  #   May include slim_opts (Hash).  Default: {COMMON_DEF_SLIM_OPTIONS}
  # @return [BaseWithTranslation]
  def self.create_with_translations!(hsmain={}, unique_trans_keys=nil, *args, reload: true, **hs_trans)
    ret = update_or_create_with_translations_core!(:translations, hsmain, unique_trans_keys, nil, false, *args, **hs_trans)
    ret.reload if reload
    ret
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
  # @param hsmain [Hash] The main data for {BaseWithTranslation}
  # @param unique_trans_keys [Array] If given, the keys (like [:ruby, :romaji]) is used
  #   to identify the {Translation}. Else {Translation.keys_to_identify} is called
  # @param mainkeys [Array]  Array of the columns to be used to get an existing model.
  # @param *args [Array<Integer, Symbol>] Only 1 element. If :auto (Default), [:title, :alt_title]
  #   is used to identify an existing {Translation}. If Integer, it is the size
  #   of the Array of the keys for it according to the order of 
  #   {Translation::TRANSLATED_KEYS}.
  #   For example, if nkeys==2, and inkeys==[:romaji, :alt_title, :ruby, :naiyo]
  #   [:alt_title, :ruby] is returned.
  # @param reload [Boolean] If true (Def), self is reloaded after Creation.
  #   One more DB query is incurred, but recommended!
  # @param **hs_trans [Hash<Symbol>] Hash for multiple {Translation}-s
  #   Must contain the optional key :translations
  #   May include slim_opts (Hash).  Default: {COMMON_DEF_SLIM_OPTIONS}
  # @return [BaseWithTranslation]
  # @raise [ActiveRecord::RecordInvalid, ActiveModel::UnknownAttributeError] etc
  def self.update_or_create_with_translations!(hsmain={}, unique_trans_keys=nil, mainkeys=nil, *args, reload: true, **hs_trans)
    ret = update_or_create_with_translations_core!(:translations, hsmain, unique_trans_keys, mainkeys, true, *args, **hs_trans)
    ret.reload if reload
    ret
  end

  # Creates a {BaseWithTranslation} accompanied with a single {Translation} .
  #
  # Very similar to {BaseWithTranslation#create_with_translations!} except
  # this accepts only a single translation and hence the argument format differs.
  #
  # Wrapper of {BaseWithTranslation#create!} and {#with_translation} (which is
  # similar to {#create_translation!} but returns self) to return {BaseWithTranslation}.
  # Basically the following three are *nearly* equivalent, e.g.,
  #   Music.create_with_translations!(note: 1950, translations: {ja: {title: 'イマジン'}})
  #   Music.create_with_translation!( note: 1950, translation:       {title: 'イマジン', langcode: 'ja'})
  #   Music.create!(note: 1950).with_translation(title: 'イマジン', langcode: 'ja')
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
  # @param *args [Array<Integer, Symbol>] Up to 2 elements.
  #   The first is mainkeys [Array], Array of the columns to be used to get an existing model.
  #   The second is this; If :auto (Default), [:title, :alt_title]
  #   is used to identify an existing {Translation}. If Integer, it is the size
  #   of the Array of the keys for it according to the order of 
  #   {Translation::TRANSLATED_KEYS}.
  #   For example, if nkeys==2, and inkeys==[:romaji, :alt_title, :ruby, :naiyo]
  #   [:alt_title, :ruby] is returned.
  # @param reload [Boolean] If true (Def), self is reloaded after Creation.
  #   One more DB query is incurred, but recommended!
  # @param **hs_trans [Hash<Symbol>] Hash for a single {Translation}
  #   Must contain the key :translation
  #   May include slim_opts (Hash).  Default: {COMMON_DEF_SLIM_OPTIONS}
  # @return [BaseWithTranslation]
  def self.create_with_translation!(hsmain={}, unique_trans_keys=nil, *args, reload: true, **hs_trans)
    ret = update_or_create_with_translations_core!(:translation, hsmain, unique_trans_keys, false, *args, **hs_trans)
    ret.reload if reload   # For some reason, the (optional) argument is not recognized...
    ret
  end

  # Same as {BaseWithTranslation.create_with_translation!} but may update
  #
  # Must contain the optional key :translation
  #
  # #see update_or_create_with_translations!
  #
  # @param (see BaseWithTranslation.create_with_translation!)
  # @return [BaseWithTranslation]
  def self.update_or_create_with_translation!(hsmain={}, unique_trans_keys=nil, mainkeys=nil, *args, reload: true, **hs_trans)
    ret = update_or_create_with_translations_core!(:translation, hsmain, unique_trans_keys, mainkeys, true, *args, **hs_trans)
    ret.reload if reload
    ret
  end

  # Same as {BaseWithTranslation#create_with_translation!} but a single original
  # translation only is created.
  #
  # Must contain the optional key :translation
  #
  # @param (see BaseWithTranslation.create_with_translation!)
  # @return [BaseWithTranslation]
  def self.create_with_orig_translation!(hsmain={}, unique_trans_keys=nil, *args, reload: true, **hs_trans)
    ret = update_or_create_with_translations_core!(:orig_translation, hsmain, unique_trans_keys, nil, false, *args, **hs_trans)
    ret.reload if reload
    ret
  end

  # Same as {BaseWithTranslation.create_with_orig_translation!} but may update
  #
  # Must contain the optional key :translation
  #
  # @param (see BaseWithTranslation.create_with_translation!)
  # @return [BaseWithTranslation]
  def self.update_or_create_with_orig_translation!(hsmain={}, unique_trans_keys=nil, mainkeys=nil, *args, reload: true, **hs_trans)
    ret = update_or_create_with_translations_core!(:orig_translation, hsmain, unique_trans_keys, mainkeys, true, *args, **hs_trans)
    ret.reload if reload
    ret
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

      if existings.count > 1 
        msg = "More than 1 #{self.name}-s (Total: #{existings.size}) exist #{existings.inspect} for the given translations #{trans.inspect}"
        logger.error msg+".  existings="+existings.inspect
        raise MultiTranslationError::AmbiguousError, msg
      end
    end

    obj = nil
    method = ('with_' + (updated ? 'updated_' : '') + 'translations').to_sym
    ActiveRecord::Base.transaction(requires_new: true) do  # "requires_new" option necessary for testing.
      obj, msg_opts2pass =
        if updated && !existings.empty? 
          # logger.info "(#{__FILE__}:#{__method__}) for update: hsmain=#{hsmain.inspect}, mainkeys=#{mainkeys}" if updating_cols.empty?
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
        raise
      end
    end
    obj
  end
  private_class_method :update_or_create_with_translations_core!

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

    mainprms.each_pair do |ek, ev|
      begin
        model.send(ek.to_s+'=', ev) if model.send(ek).blank?  # if the existing is null
      rescue ActiveModel::UnknownAttributeError #=> er
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
    if !ret
      msg = "ERROR(BaseWithTranslation##{__method__}): Translation is an orphan pointing to a non-existing polymorphic belongs_to: #{trans.inspect}"
      logger.error(msg)
      raise msg
    end
    ret.matched_translation = trans
    ret.matched_attribute   = trans.matched_attribute
    ret
  end

  # Wrapper of {BaseWithTranslation.select_translations_regex}, but returning
  # a BaseWithTranslation::ActiveRecord_Relation or Array of {BaseWithTranslation},
  # searching {Translation} for the specified title etc.
  #
  # For the complete arguments and options, consult {Translation.select_regex}
  # Importantly, the returned value depend on how you specify +sql_regexp+ option
  # (and whether you give Regexp or String).  Although the default of +sql_regexp+
  # is false, it is recommended to give true in a vast majority of cases
  # for the sake of performance and also to make the result sortable in tables with the grids.
  #
  # Note that the result is not "sorted", as there is
  # no general way to know whether the result is actually sotable.
  #
  # @note
  #  Elements of the returned Relation from {Translation.select_regex} may be nil
  #  only when {Translation#translatable_id} does not have the corresponding
  #  {BaseWithTranslation}; it should never happen because such {Translation} must
  #  have been destroyed whenever {BaseWithTranslation} is destroyed. However,
  #  if the records are destroyed through direct DB manipulation like DB-migration,
  #  it can happen!  This method sanitizes such elements, leaving ERROR in Logfile.
  #
  # @example
  #   Artist.select_regex(:titles, /^ハラミちゃん/, langcode: 'ja', sql_regexp: true).distinct.first
  #
  # @param *args [Array<Symbol, String, Array<String>, Regexp>] Symbol, String|Regexp. See {Translation.select_regex}. 
  # @param debug_return_sql [Boolean] Debug option (Def: false). If true, returns a SQL-string or Hash (see {Translation.self.select_regex_rubyregex} for detail), instead of Array
  # @param **restkeys: [Hash] Any other (exact) constraints to pass to {Translation}
  #    For example,  is_orig: true
  # @return [BaseWithTranslation::ActiveRecord_Relation, Array<BaseWithTranslation>] Note this returns SQL-string or Hash if debug_return_sql is true
  def self.select_regex(*args, debug_return_sql: false, **restkeys)
    rela = select_translations_regex(*args, debug_return_sql: false, **restkeys)
    if rela.respond_to?(:to_sql)
      _select_regex_sql(rela.to_sql, debug_return_sql: debug_return_sql)
    else
      _select_regex_ruby(*args, debug_return_sql: debug_return_sql, **restkeys)
    end
  end


  # {BaseWithTranslation.select_regex} for String or Regexp with +sql_regexp: true+ inputs.
  #
  # @param rela [String] SQL string output of Translation::ActiveRecord_Relation (initiated by {Translation}). See {BaseWithTranslation.select_regex}.
  # @param debug_return_sql [Boolean] Debug option (Def: false). If true, returns a SQL-string, instead of ActiveRecord_Relation
  # @return [BaseWithTranslation::ActiveRecord_Relation] Note this returns SQL-string if debug_return_sql is true
  def self._select_regex_sql(rela_sql, debug_return_sql: false)
    ret = self.joins(:translations).where(_extract_where_clause(rela_sql))
    (debug_return_sql ? ret.to_sql : ret)
  end
  private_class_method :_select_regex_sql


  # {BaseWithTranslation.select_regex} for Regexp with +sql_regexp: false+ (Default) input.
  #
  # @param debug_return_sql [Boolean] Debug option (Def: false). If true, returns a Hash (see {Translation.self.select_regex_rubyregex} for detail) for the SQL to derive Translation (NOT BaseWithTranslation), instead of Array
  # @return [Array<BaseWithTranslation>] Note this returns SQL-string or Hash if debug_return_sql is true
  def self._select_regex_ruby(*args, debug_return_sql: false, **restkeys)
    rela = select_translations_regex(*args, debug_return_sql: debug_return_sql, **restkeys)
    return rela if debug_return_sql

    rela.map{|tr|
      if (j=tr.translatable)
        j
      else
        s = sprintf(
          'WARNING: Translation (ID=%s: translatable_type="%s" translatable_id=%d) has no live counterpart and is a zombie Translation. Clean it.',
          tr.id, tr.translatable_type, tr.translatable_id
        )
        logger.warn s
        j
      end
    }.uniq.compact
  end
  private_class_method :_select_regex_ruby

  # Returns the WHERE clause part in String, which can be fed to +where+ directly.
  #
  # @note This method can handle a SQL statement with a simple JOIN (with a simple arithmatics) and/or ORDER, but not much more!
  #
  # @param sql_str [String] String of a SQL (result of .to_sql)
  # @return [String] WHERE clause
  def self._extract_where_clause(sql_str)
    sql_str.
      sub(/ order by ["][^"][^ ]+ (?:ASC|DESC)\Z/i, "").
      sub(/\Aselect [^ ]+ from [^ ]+ /i, "").
      sub(/\A(?:(?:inner|left|right|outer) join ["][^ ]+" on "[^ ]+" [^a-z]+ [^ ]+( and "[^ ]+" [^a-z]+ [^ ]+)* )*where /i, "")
  end
  private_class_method :_extract_where_clause

  # Wrapper of {Translation.find_by_regex}, returning {Translation}-s of only this class
  #
  # @param *args: [Array]
  # @param **restkeys: [Hash] 
  # @return [Translation]
  def self.find_translation_by_regex(*args, **restkeys)
    Translation.find_by_regex(*args, translatable_type: self.name, **restkeys)
  end

  # Wrapper of {Translation.select_partial_str}, returning {Translation}-s of only this class
  #
  # Using SQL directly.
  #
  # @param *args: [Array]
  # @param **restkeys: [Hash] 
  # @return [Translation::ActiveRecord_Relation]
  def self.select_translations_partial_str(*args, **restkeys)
    Translation.select_partial_str(*args, translatable_type: self.name, **restkeys)
  end

  # Wrapper of {BaseWithTranslation.select_translations_partial_str}, returning models
  #
  # Using SQL directly.
  #
  # @example Returning Translations containing "procla" excluding IDs of 5 or 8.
  #    Artist.select_partial_str(:titles, ['Procla', 'Lenno']).where.not("translations.id": [5, 8])
  #
  # @param *args: [Array]
  # @param **restkeys: [Hash] 
  # @return [BaseWithTranslation::ActiveRecord_Relation]
  def self.select_partial_str(*args, **restkeys)
    rela = select_translations_partial_str(*args, **restkeys)
    _select_regex_sql(rela.to_sql).distinct  #, debug_return_sql: debug_return_sql)  # see _select_regex_sql for debugging.
  end

  # Returns Relation of {BaseWithTranslation} that have one of the {Translation}-s.
  #
  # Input Hash (inprms) is like (n.b., it may contain the keys like "strip"?),
  #   {
  #     en: [ {title: 'T1'}, {title: 'T2', is_orig: true, langcode: 'en'} ],
  #     ja:   {title: 'J1'},
  #   }
  #
  # It works as kind of a wrapper of {BaseWithTranslation.find_all_by_translation};
  # however, it is implemented in a completely different way by calling SQL directly.
  #
  # == Algorithm example
  #
  #    Prefecture.joins("INNER JOIN translations "+
  #                     "ON translations.translatable_id = prefectures.id AND"+
  #                        "translations.translatable_type = 'Prefecture'").
  #               where(country: cnty).
  #               where("translations.langcode = ? AND translations.title = ?, 'en', 'Abc').
  #               distinct
  #
  # @example to get BaseWithTranslation
  #    Sex.select_by_translations(en: {title: 'male'}).first  # => Sex[1]
  #
  # @example to get all Translation-s (in one SQL)
  #    Country.select_by_translations(ja: {langcode: 'ja', title: '日本国'})[0].translations.pluck(:title, :alt_title)
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
  # @param debug_return_sql [Boolean] Debug option (Def: false). If true, returns a SQL-string.
  # @param inprms [Hash<Symbol>] Should contain at least one of title, alt_tile, ruby etc,
  #   in addiotn to langcode for each key (like :en).
  #   May include slim_opts (Hash).  Default: {COMMON_DEF_SLIM_OPTIONS}
  # @return [BaseWithTranslation::ActiveRecord_Relation]
  # @raise [RuntimeError]
  def self.select_by_translations(hsmain={}, unique_trans_keys=nil, *args, debug_return_sql: false, **inprms)
    raise RuntimeError, "Contact the code developer. uk=(#{unique_trans_keys.inspect})" if !unique_trans_keys.nil? && unique_trans_keys.blank?

    trtbl = Translation.table_name
    joins_str = sprintf(
      "INNER JOIN %<tr>s ON %<tr>s.translatable_id = %<my>s.id and %<tr>s.translatable_type = '%<klas>s'",
      tr: trtbl,
      my: self.table_name,
      klas: self
    )

    ret = self.joins(joins_str)
    ret = ret.where(**hsmain) if !hsmain.blank?
    ret = ret.where(*(build_or_where_translations(unique_trans_keys, *args, **inprms)))
    ret = ret.distinct
    (debug_return_sql ? ret.to_sql : ret)
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
      if !possible_snakes.include? model_snake.to_s
        msg = sprintf "Option %s is invalid (no such associated model).", {ea_tkey => ea_val}.inspect
        warn msg
        logger.warn "(#{__method__}): "+msg+"  Skips."
        next
      end

      tr = {any: {titles: ea_val}}
      hs_conds[model_snake] = model_class.select_by_translations(**tr)  # Associated-class instances

      ## NOTE: the following does not return, e.g., Music objects, but Translation objects,
      ##  though you could do  pluck(:translatable_id)
      # hs_conds[model_snake] = Translation.select_regex(:titles, ea_val, translatable_type: model_snake.camelize) # langcode: nil
    end

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
        if ek == :titles
          # :titles means (:title "OR" :alt_title)
          artmp.push sprintf('(%s.title = ? OR %s.alt_title = ?)', trtbl, trtbl)
          arprm.push ev, ev
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


  # Find all BaseWithTranslation with exact title and/or alt_title etc.
  #
  # Returning Relation.
  # When multiple Translation-s are given, they are "OR" conditions.
  #
  # For the main parameters, they are all "AND" conditions.
  # You often cannot save a new BaseWithTranslation with only one of the Translation-s
  # identical to an existing one (n.b., some BaseWithTranslation-s accept those in some conditions
  # like same-name Artists with different birthdays).
  #
  # This script is used in seeding (to identify the existing records based on Translation-s)
  # to avoid failing identifications and trying to save a new one with one of Translation-s
  # identical to an existing one, resulting in ActiveRecord::RecordInvalid.
  #
  # @example
  #   ChannelOwner.find_all_by_exact_translations(
  #     [{langcode: :ja, title: "変わったかもしれない"},
  #      {langcode: :en, title: "Comletely agrees"}],
  #     sex: "male")  # mandatory "main" parameters if any
  #
  # @param args [Array<Hash>] Hash of {Translation} parameters such as :title, :langcode
  # @param inprms [Hash] main mandagtory parameters unique to {BaseWithTranslation}
  # @return [BaseWithTranslation::ActiveRecord_Relation]
  def self.find_all_by_exact_translations(*args, **inprms)  # , dump_sql: false
    rela_base = self.joins(:translations)
    rela_base = rela_base.where(**inprms) if !inprms.empty?
    rela = rela_base

    transs = [args].flatten.map{|ehs| ehs.map{|ek, ev| ["translations."+ek.to_s, ev]}.to_h}
    transs.each_with_index do |hs_trans, ei|
      if 0 == ei
        rela = rela.where(**hs_trans)
      else
        rela = rela.or(rela_base.where(**hs_trans))
      end
    end
    # puts rela.to_sql if dump_sql  # for debugging
    rela.distinct
  end

  # Wrapper of self.find_all_by_exact_translations 
  # returning an Array of Hash for Translation that do not match the OR coditions.
  #
  # Used for seeding.
  # One or more of the original translations (in seeding) may change by an admin with UI
  # in real applications, which may be inconvenient.  So, this method detects such inconsistencies.
  #
  # Basically, the "OR" condition for the translations for a BaseWithTranslation:
  # should be applicable to a single translation; e.g., if an exact "ja"
  # gives a BaseWithTranslation, then the other langcodes like "en" should
  # returns the same.  If not, there is an inconsistency.
  #
  # This method accepts an Array of Hash for Tranlsation attributes like :title and :langcode,
  # and returns the same-structure Array with the given Hash, except the elements (hashes) that are consistent
  # are nullified, so that the caller should know which ones are wrong.
  #
  # @example
  #   ChannelOwner.find_all_inconsistent_translations(
  #     [{langcode: :ja, title: "変わったかもしれない"},
  #      {langcode: :en, title: "Comletely agrees"}],
  #     sex: "male")
  #    # => [{langcode: :ja, title: "変わったかもしれない"}, nil]
  #    #  The second element is nullified because it is consistent with the expectation,
  #    #  i.e., ChannelOwner with only the EN translation is found and its JA translation must have been altered or deleted.
  #
  # @param rela_base [BaseWithTranslation::ActiveRecord_Relation]
  # @param args [Array<Hash>] Hash of {Translation} parameters such as :title, :langcode
  # @param inprms [Hash] main mandagtory parameters unique to {BaseWithTranslation}
  # @return [Array<Hash>]
  def self.find_all_inconsistent_translations(*args, **inprms)  # , dump_sql: false
    arhs = args.flatten
    or_ids = find_all_by_exact_translations(*args, **inprms).ids

    ar_and_ids = []
    arhs.each do |ehs|
      ar_and_ids << find_all_by_exact_translations(ehs, **inprms).ids
    end

    arhs.map.with_index{|eh, ei|
      (or_ids == ar_and_ids[ei]) ? nil : eh
    }
  end

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


  # Returns the Array of sorted langcodes (String) in order of priority
  #
  # A user-specified langcode if any, {Translation#is_orig}, and
  # {BaseWithTranslation::AVAILABLE_LOCALES}, and any other langcodes
  # that the given Hash has are all considered.
  #
  # The default priority is
  #
  # 1. Caller-specified (NOT WEB-browser's implicit request)
  # 2. Translation with +is_orig+ of true, if there is any
  # 3. Hard-coded order in this app.
  #
  # where (1) and (2) are swapped if +prioritize_orig+ is true.
  # This is useful, when, for example, you want to select "Queen" over "クイーン" for
  # an artist (group), providing it is the original language,
  # whereas you may prefer "犬" to "dog" for a general noun,
  # for which no "original" language can be defined.
  #
  # In the real world, it is more complicated; for example, you may want
  # to choose the alphabet spelling in English for American Artists,
  # whereas you may not wish the same for the Greek alphabet spelling
  # in Greek for Greek artists or Thai characters for Thai artists.
  # How about Chinese artist names?  Do you prefer simplified Chinese characters,
  # traditional ones, Japanese kanjis, or Japanese katakanas, or even alphabet letters?
  #
  # @example
  #   Country.sorted_langcodes(first_lang: nil,  hstrans: cntr.best_translations)
  #     #=> ['en', 'ja', 'fr']
  #   Country.sorted_langcodes(first_lang: 'it', hstrans: cntr.best_translations)
  #     #=> ['it', 'en', 'ja', 'fr', 'kr'] (providing hstrans has 'kr' with is_orig=false)
  #     # NOTE: hstrans may not include Translation in "it".  This method does not care
  #     #       in default unless +remove_invalid: true+ is specified.
  #
  # @param hstrans: [Hash<String => Translation>] Returns of {#best_translations}
  # @param first_lang: [String, NilClass] user-specified langcode that has the highest priority
  # @param prioritize_orig: [Boolean] If true, is_orig has a higher priority than first_lang (Def: false)
  # @param remove_invalid: [Boolean] If true (Def: false), langcode-s that do not have Translation are removed in the returne Array. {Place#title_or_alt_ascendants}, which is widely used in the app, depends on this default setting. Specifically, the option +lang_fallback_option: :never+ would not work well if +remove_invalid+ here was true (because the method's behaviour of potentially returning nil depends on it?).
  # @return [Array<String>]
  def self.sorted_langcodes(hstrans: , first_lang: nil, prioritize_orig: false, remove_invalid: false)
    first_lang = first_lang.to_s if first_lang
    def_locales = AVAILABLE_LOCALES.map{|i| i.to_s}
    hsind = 
      if prioritize_orig
        { user: 1, orig: 0, sys: 2 }
      else
        { user: 0, orig: 1, sys: 2 }
      end
    
    # Convert to Array [Orig?, User? (or reverse), System-No, lcode] and perform simple sort
    ([first_lang]+hstrans.keys).compact.uniq.map{ |lcode|
      next nil if remove_invalid && !hstrans[lcode].respond_to?(:is_orig)
      ar = []
      ar[hsind[:user]] = ((first_lang.to_s == lcode) ? 0 : 1)
      ar[hsind[:orig]] = ((hstrans[lcode].respond_to?(:is_orig) && hstrans[lcode].is_orig) ? 0 : 1)
      ar[hsind[:sys]]  = (def_locales.index(lcode) || Float::INFINITY)
      ar[3] = lcode
      ar
    }.compact.sort.map{|i| i[3]}
  end
    ### Original, more intuitive sorting algorithm
    #
    #uniqqed = ([first_lang]+hstrans.keys).compact.uniq
    #if prioritize_orig
    #  uniqqed.sort{ |a,b|
    #  ....}
    #else
    #  uniqqed.sort{ |a,b|
    #    if    a == first_lang
    #      -1
    #    elsif b == first_lang
    #       1
    #    elsif hstrans[a].is_orig
    #      -1
    #    elsif hstrans[b].is_orig
    #       1
    #    else
    #       (def_locales.index(a) || Float::INFINITY) <=> 
    #       (def_locales.index(b) || Float::INFINITY)
    #    end
    #  }
    #end

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

  ################################################
  # instant methods
  ################################################

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
    tra ||= (best_translations['ja'] || best_translations['en'] || best_translations.first) 
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

  # Wrapper of {BaseWithTranslation.select_translations_partial_str}, excepting {Translation}s of self
  #
  # @param *args: [Array]
  # @param **restkeys: [Hash] should not include the key +not_clause+, unless you know what you're doing!!
  # @return [Translation::ActiveRecord_Relation]
  def select_translations_partial_str_except_self(*args, **restkeys)
    ids = translations.pluck(:id)
    if !restkeys.key?(:not_clause) || restkeys[:not_clause].blank?
      restkeys.merge!({not_clause: {id: ids}})
      # Users should not specify/use not_clause option for this method.
    end
    self.class.select_translations_partial_str(*args, **restkeys)
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

  # Wrapper of {#select_translations_partial_str_except_self}, returning String (title)
  #
  # titles for self are excluded for the candidates.
  #
  # Note the displayed langcode may be empty, if {Translation#is_orig} is true
  # for none of the associated Translations.
  #
  # @param *args: [Array]
  # @param display_id [Boolean] If true (Def: false), locale and ID are also printed at the tail.
  # @param **restkeys: [Hash] 
  # @return [Array<String>]
  def select_titles_partial_str_except_self(*args, display_id: false, **restkeys)
    select_translations_partial_str_except_self(*args, **restkeys).map{|i| i.translatable}.uniq.map{|em|
      self.class.base_with_translation_with_id_str(em, print_id: display_id)
    }
  end

  # @param model [BaseWithTranslation]
  # @param print_id [Boolean] If true (Def: true), locale and ID are also printed at the tail. Else, just {#title_or_alt} in the original language (NOT in User's language).
  # @return [String] to be displayed like "Queen [en] [ID=888]"
  def self.base_with_translation_with_id_str(model, print_id: true)
    tit = model.title_or_alt
    tail = (print_id ? sprintf(" [%s] [ID=%s]", tit.lcode, model.id) : "")  # tit.lcode == model.orig_langcode in most cases (for Artist, Music etc), but chances are orig_langcode may remain undefined.
    tit + tail
  end

  # Decomposing a "Model+lcode+ID" string
  #
  # In +update+ (not +edit+) after auto-complete for a Model, a string query
  # for the model's Translation candidate is passed. So, we need to retrieve the model based on it.
  # In principle, there may be no models or multiple models.
  # Autocomplete helps to identify it uniqlely by appending the locale (langcode)
  # and ID at the end of the query string, although users can editi them technically
  # if they insist. Now the Controller for update must identify the model
  # sending a query to DB. This method does preparation for it.
  #
  # Basically, the reverse of {BaseWithTranslation.base_with_translation_with_id_str}
  #
  # Specifically, a search string after autocomplete may be like
  #   "Queen [en] [123]"
  # which includes the language and its {BaseWithTranslation} model ID.
  # This method separates them to enable a subsequent DB query.
  #
  # @example
  #    searched, lcode, model_id = BaseWithTranslation.resolve_base_with_translation_with_id_str(strin)
  #
  # @param str [String] e.g., "Queen [en] [ID=888]"
  # @return [Array<String, String, Integer>] e.g., ["Queen", "en", 123] (Search-String, Locale, ID).
  #    The second and third arguments would be nil if failing to match.
  def self.resolve_base_with_translation_with_id_str(str)
    #re_locales = I18n.available_locales.map(&:to_s).join("|")
    lcode = nil
    model_id = nil
    search_str = str.sub(/(?:\s*\[([a-z]{2})\]\s*)(?:\[ID=(\d+)*\]\s*)\z/m){ lcode = $1; model_id = $2; "" }
    model_id = (model_id.blank? ? nil : model_id.to_i)  # nil or Integer
    [search_str, lcode, model_id] 
  end

  # Returns candidate BaseWithTranslation-s from auto-completed string. 
  #
  # At least one candidate, and usually only one, should be found unless the user deliberately alters the string.
  #
  # If nothing is found, an empty Array is returned.
  #
  # @param search_word [String]
  # @return [Array<BaseWithTranslation>]
  # @raise [ActiveRecord::RecordNotFound] if a String containing the completely-wrong ID is passed,
  #    which should never happen with auto-complete or with a standard manual input in UI.
  def candidate_bwts_from_ac_str(search_word)
    search_str, lcode, model_id = BaseWithTranslation.resolve_base_with_translation_with_id_str(search_word)
    return [self.class.find(model_id)] if model_id

    self.select_translations_partial_str_except_self(
      :titles, search_str, langcode: lcode
    ).map{|i| i.translatable}.uniq
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

  # Gets the best-scored [title, alt_title]
  #
  # Note the alorithm is implemented specifically for this method,
  # instead of calling {#get_a_title}, to avoid too many queries to the DB.
  #
  # Note that singleton method String#lcode is defined for each of the returned String title/alt_title
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
  # @param lang_fallback_option: [Symbol] (:both|:either|:never(Def)) if :both,
  #    (lang_fallback: true) is passed to both {#title} and {#alt_title}.
  #    If :either, if either of {#title} and {#alt_title} is significant,
  #    the other may remain nil. If :never, +[nil, str_fallback]+ may be returned
  #    (which is also the case where no tranlsations are found in any languages).
  #    NOTE the similar option in {#get_a_title} differs in name: +lang_fallback+.
  #    NOTE also the same-name option in {#title_or_alt} differs in meaning.
  # @param str_fallback [String, NilClass] similar to that of {#get_a_title}. If none is found,
  #   and if this is non-nil, the second element of the returned Array is
  #   this value, like +[nil, "NONE"]+. Default is nil.
  # @param prioritize_orig: [Boolean] If true, is_orig has a higher priority than first_lang (Def: false)
  # @param **kwds [Hash] passed to {Translation#titles} as they are; in practice, +article_to_head+
  # @return [Array<String, String>] if there are no translations for the langcode, +[nil, Option(str_fallback)]+.  Singleton method of +lcode+ is available.
  def titles(langcode: nil, lang_fallback_option: :never, str_fallback: nil, prioritize_orig: false, **kwd)
    raise ArgumentError, "(#{__method__}) Wrong option (lang_fallback_option=#{lang_fallback_option}). Contact the code developer."  if !(%i(both either never).include? lang_fallback_option)

    hstrans = best_translations
    arret = [nil, str_fallback]

    # Fallback
    sorted_langs = self.class.sorted_langcodes(first_lang: langcode, hstrans: hstrans, prioritize_orig: prioritize_orig, remove_invalid: false) # ["ja", "en"] etc.
    sorted_langs.each do |ecode|
      artmp = (hstrans[ecode] && hstrans[ecode].titles(**kwd))
      if !artmp
        return arret if lang_fallback_option == :never
        next
      end
      artmp.each do |str|
        next if !str
        str.instance_eval{singleton_class.class_eval { attr_accessor "lcode" }}
        str.lcode = ecode  # Define Singleton method String#lcode
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
  # @note An edge case is not tested (+base_with_translation_test.rb+) where Translations have
  #  (title, alt_title)=(ja)['あ', 'い'], (en)[nil, "abc"]
  #  and ja is for +is_orig=true+ and +title_or_alt(langcode: 'en')+
  #  is requested. Does it return 'あ' or "abc"?
  #
  # @example prefer_alt
  #    Country.third.title_or_alt(prefer_alt: true)  # => e.g., "North Korea", as opposed to "the Republic of..."
  #
  # @example lang_fallback_option of never
  #    Place.third.title_or_alt(langcode: "kr", lang_fallback_option: :never)  # => ""
  #    Place.third.title_or_alt(langcode: "kr", lang_fallback_option: :never, str_fallback: nil)  # => nil
  #
  # @example lang_fallback_option of both
  #    Place.third.title_or_alt(langcode: "kr", lang_fallback_option: :both)  # => never ""
  #
  # @param prefer_alt: [Boolean] if true (Def: false), alt_title is preferably
  #    returned as long as it exists.
  # @param lang_fallback_option: [Symbol] (:both|:either(Def)|:never) Similar to {#titles} but has a different meaning. If :both,
  #    +(lang_fallback: true)+ is passed to both {#title} and {#alt_title}.
  #    If :either (Default), if either of {#title} and {#alt_title} is significant,
  #    the other may remain nil. If :never, "" is returned unless
  #    a title or alt_title in the specified langcode is found.
  #    NOTE the default value differs from {#titles} and the meanings differ anyway!
  #    NOTE also the similar option in {#get_a_title} differs in name: +lang_fallback+.
  # @param str_fallback [String, NilClass] Returned Object (String or nil) in case neither "title" is found.
  #    Unlike {#get_a_title} and {#titles}, the default is +""+, meaning this method
  #    never returns +nil+ in default, unless explicitly specified so with this option.
  # @param langcode: [String, NilClass] like 'ja' (directly passed to the parent method)
  # @param prioritize_orig: [Boolean] (directly passed to the parent method)
  # @param article_to_head: [Boolean] (directly passed to the parent method)
  # @return [String] Singleton method of +lcode+ is available.
  def title_or_alt(prefer_alt: false, lang_fallback_option: :either, str_fallback: "", **opts)
    cands = titles(lang_fallback_option: lang_fallback_option, str_fallback: nil, **opts) # nil is wanted when no translations are found.
    cands.reverse! if prefer_alt
    cands.map{|i| (i.blank? || i.strip.blank?) ? nil : i}.compact.first || str_fallback
    ## NOTE: Do NOT modify i (like i.strip) because "i" has a Singleton method #lcode
  end

  # Array of either 1 or 2 elements of String (title)
  #
  # NOTE: This method makes sense only when both +langcode+ and +prioritize_orig+
  #  are specified like +langcode: I18n.locale, prioritize_orig: true+
  #
  # Wrapper of {#title_or_alt}.  If the language of the returned one
  # differs from the specified language AND if +prioritize_orig+ is true,
  # you may not even read the returned String (characters).  In such a case,
  # this method returns the second element in the specified language,
  # providing a Translation in the language exists.
  #
  # If the specified +langcode+ is blank or +prioritize_orig+ is not true,
  # this returns the same as {#title_or_alt}, except in the form of Array.
  #
  # @param langcode: [String, NilClass] like 'ja' (directly passed to the parent method)
  # @param prioritize_orig: [Boolean] If true, is_orig has a higher priority than first_lang (Def: false)
  # @param #see title_or_alt
  # @return [Array<String>] Singleton method of +lcode+ is available. In no associated Translation is found (which realistically can happen only when +lang_fallback_option: :never+), this returns the Array with the value of +str_fallback+ (Def: "", meaning returning +[""]+) (see {#title_or_alt}).
  def title_or_alt_tuple(langcode: nil, prioritize_orig: false, **opts)
    retstr = title_or_alt(langcode: langcode, prioritize_orig: prioritize_orig, **opts)
    return [retstr] if !(langcode.present? &&
                         prioritize_orig &&
                         (!retstr.respond_to?(:lcode) || retstr.lcode != langcode.to_s))  # if lcode is not defined, it should be the +str_fallback+ character (Def: "")
    ret2 = title_or_alt(langcode: langcode, prioritize_orig: false, **(opts.merge({lang_fallback_option: :never})))
    ret2.blank? ? [retstr] : [retstr, ret2]
  end

  # Wrapper of {#title_or_alt_tuple} to return a formatted String
  #
  # NOTE: This method makes sense only when +langcode+ is explicitly specified
  #  like +langcode: I18n.locale+.  Unlike {#title_or_alt_tuple}, +prioritize_orig+
  #  does not need to be specified.
  #
  # @example
  #    s = b.title_or_alt_tuple_str("[和名: ", "]", langcode: I18n.locale)
  #    #=> "Queen [和名: クイーン]"  (if I18n.locale == "ja")
  #    #=> "Queen"  (if no JA-translation is found)
  #
  # @param open_para [String]
  # @param close_para [String]
  # @param definite_article_to_head: [Boolean]
  # @param #see title_or_alt_tuple
  # @return [String] Either "Queen" (maybe empty) or "Queen (クイーン)". Guaranteed to return String.
  def title_or_alt_tuple_str(open_pare="(", close_pare=")", normalize_definite_article: true, **opts)
    arret = title_or_alt_tuple(prioritize_orig: true, **opts)
    return "" if arret[0].blank?
    arret.map!{|i| (i && normalize_definite_article) ? definite_article_to_head(i) : i}
    return arret[0] if arret.size == 1
    sprintf("%s "+open_pare+"%s"+close_pare, *arret)
  end

  # Core method for title, alt_title, alt_ruby, etc
  #
  # Similarly to {#titles}, singleton method String#lcode is defined for the returned String.
  #
  # Option +str_fallback+ is useful for Views. In Dropdown menu, for example,
  # if one of them is left empty (instead of "NONE" or some significant string),
  # it would violate the HTML spec:
  #    Element "option" without attribute "label" must not be empty.
  #
  # @example
  #    sex.title(langcode: I18n.locale)
  #    get_a_title(:title, langcode: I18n.locale)  # private method!
  #
  # @param method [Symbol] one of %i(title alt_title ruby alt_ruby romaji alt_romaji)
  # @param langcode: [String, NilClass] like 'ja'. If nil, original language for the Translation is assumed.
  # @param lang_fallback: [Boolean] if true (Def), when no translation is found
  #    for the specified language, that of another language is returned
  #    unless none exists.
  # @param str_fallback [String, NilClass] Returned Object (String or nil) in case no "a title" is found.
  # @return [String, NilClass] nil if there are no translations for the langcode
  def get_a_title(method, langcode: nil, lang_fallback: true, str_fallback: nil)
    ret = (translations_with_lang(langcode)[0].public_send(method) rescue nil)
    return ret if ret
    return str_fallback if !lang_fallback

    ## Falback after no translations are found for the specified language.
    hstrans = best_translations
    hstrans.each_pair do |ek, ev|
      ret = ev.public_send(method)
      if !ret.blank?
        ret.instance_eval{singleton_class.class_eval { attr_accessor "lcode" }}
        ret.lcode = ek  # Define Singleton method String#lcode
        return ret
      end
    end
    str_fallback
  end
  private :get_a_title

  # Core method for title=, alt_title=, alt_ruby=, and langcode=, is_orig=, weight= etc
  #
  # This method is valid practically only for the first time (new, create)
  # Otherwise, ArgumentError is raised.
  #
  # The first-time call of this method creates a {Translation} accessible via +translations.first+
  #
  # == Problems
  #
  # I attempted to define writer methods like  title=, langcode= to as to allow Sex.new(iso5218: 4, title: "foo")
  # However, this weirdly fails...
  # Once these methods have been defined,
  #   model = Sex.new(iso5218: 4, title: "foo", langcode: "en")
  #   model.translations.first.valid? # => true
  #   model.valid?                    # => true
  #   model.save    # (no bang)
  #     #=> ActiveRecord::NotNullViolation: PG::NotNullViolation: ERROR:  null value in column "translatable_id"
  #
  # Basically, it seems Rails does some magic trick in associating an unsaved (polymorphic)
  # child to prevent "NotNullViolation" even when the foreign key ID is nil (which
  # is inevitable with a new and unsaved parent). And the magic does not work
  # for the associations that are defined at the time of creation.  Fair enough.
  #
  # To be honest, even if I managed to find a way to get around, I am afraid
  # that may not be future-proof as it must be an edge case for Rails and
  # the specification may change at any time, which would not affect 99.9%
  # of Rails users.
  #
  # So, instead, I implemented it with the Array @unsaved_translations, accessible
  # with the same name (+attr_accessor+).  It is just an instance valiable
  # and so has nothing to do with the Rails association mechanism.
  #
  # See +after_create+ callback +:save_unsaved_translations+ and also
  # +self.initialize+
  #
  # @param method [String, Symbol] one of %i(title= alt_title= ruby= alt_ruby= romaji= alt_romaji= langcode= is_orig= weight=)
  # @return [String, NilClass] nil if there are no translations for the langcode
  def put_a_title(method, value)
    method = method.to_s
    put_keys = Translation::TRANSLATION_PARAM_KEYS.map(&:to_s).map{|i| i+"="}

  if false  ## See the description. This is a more principled algorithm, but it does not work.
    if !new_record? || translations.size > 1
      raise ArgumentError, "#{self.class.name}.#{method} is invalid except for the first time for a new record."
    elsif !put_keys.include?(method)
      raise ArgumentError, "#{method} is wrong. Contact the code developer."
    end

    tra = translations.first
    if !tra
      tra = Translation.new
      translations << tra
    end
    tra.translatable_type ||= self.class.name
       # tra.translatable_id   ||= 8888  # random number is OK... Without this, an exception is raised: ActiveRecord::NotNullViolation: PG::NotNullViolation: ERROR:  null value in column "translatable_id"
    tra.send(method, value)
    value
  else
    ### This is the algorithm I ended up with.  Not pretty, but it works.
    if !new_record? || (@unsaved_translations && @unsaved_translations.size > 1)
      raise ArgumentError, "#{self.class.name}.#{method} is invalid except for the first time for a new record."
    elsif !put_keys.include?(method)
      raise ArgumentError, "#{method} is wrong. Contact the code developer."
    end

    if @unsaved_translations.blank?
      @unsaved_translations = [Translation.new(method[0..-2] => value, "translatable_type" => self.class.name)]
    else
      @unsaved_translations.first.send(method, value)
    end
  end
  end
  private :put_a_title

  # Defines %i(title= alt_title= ruby= alt_ruby= romaji= alt_romaji= langcode= is_orig= weight=)
  Translation::TRANSLATION_PARAM_KEYS.each do |metho|
    metho_i = (metho.to_s + "=").to_sym
    define_method(metho_i) do |arg|
      send(:put_a_title, metho_i, arg)
    end
  end

  # Gets the best-score title
  #
  # @param langcode: [String, NilClass] like 'ja'
  # @param lang_fallback: [Boolean] See {#get_a_title}
  # @param str_fallback [String, NilClass] See {#get_a_title}
  # @return [String, NilClass] nil if there are no translations for the langcode
  def title(**kwd)
    get_a_title(__method__, **kwd)
  end

  # Gets the best-score ruby
  #
  # @param langcode: [String, NilClass] like 'ja'
  # @param lang_fallback: [Boolean] See {#get_a_title}
  # @param str_fallback [String, NilClass] See {#get_a_title}
  # @return [String, NilClass] nil if there are no translations for the langcode
  def ruby(**kwd)
    get_a_title(__method__, **kwd)
  end

  # Gets the best-score romaji
  #
  # @param langcode: [String, NilClass] like 'ja'
  # @param lang_fallback: [Boolean] See {#get_a_title}
  # @param str_fallback [String, NilClass] See {#get_a_title}
  # @return [String, NilClass] nil if there are no translations for the langcode
  def romaji(**kwd)
    get_a_title(__method__, **kwd)
  end

  # Gets the best-score alt_title
  #
  # @param langcode: [String, NilClass] like 'ja'
  # @param lang_fallback: [Boolean] See {#get_a_title}
  # @param str_fallback [String, NilClass] See {#get_a_title}
  # @return [String, NilClass] nil if there are no translations for the langcode
  def alt_title(**kwd)
    get_a_title(__method__, **kwd)
  end

  # Gets the best-score alt_ruby
  #
  # @param langcode: [String, NilClass] like 'ja'
  # @param lang_fallback: [Boolean] See {#get_a_title}
  # @param str_fallback [String, NilClass] See {#get_a_title}
  # @return [String, NilClass] nil if there are no translations for the langcode
  def alt_ruby(**kwd)
    get_a_title(__method__, **kwd)
  end

  # Gets the best-score alt_romaji
  #
  # @param langcode: [String, NilClass] like 'ja'
  # @param lang_fallback: [Boolean] See {#get_a_title}
  # @param str_fallback [String, NilClass] See {#get_a_title}
  # @return [String, NilClass] nil if there are no translations for the langcode
  def alt_romaji(**kwd)
    get_a_title(__method__, **kwd)
  end

  # Gets the original {Translation}, meaning the original word(s)
  #
  # In the case (which should never happen) of multiple Translations having is_orig=true,
  # a single arbitrary one among them is returned.
  #
  # @example to get the language of the original word
  #   obj.orig_translation.langcode  # => 'ja'
  #   # == obj.orig_langcode
  #
  # @return [Translation, Nilclass] nil if no {Translation} has {Translation#is_orig}==true 
  def orig_translation
    return translations.where(is_orig: true)[0] if !(new_record? && @unsaved_translations.present?)

    # For new_record, mimicing the algorithm.
    utrans = unsaved_translations
    return nil if utrans.blank?
    utrans.sort{|a,b|
      ar = [a, b].map{|i| i.is_orig ? -2 : (i.is_orig.nil? ? 2 : 0) }
      ar[0] <=> ar[1]
    }.first
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

  # Reset the original langcode
  #
  # If there are multiple candidates for the given langcode, that of the best (=lowest)
  # weight is chosen.  To eliminate the uncertainty, give a {Translation} as the 1st arg.
  #
  # All the other {Translation#is_orig} becomes false.
  #
  # @param langcodearg [Translation, String, Symbol, NilClass] Translation to become Original. Alternatively, same as the optional argument and has a higher priority.
  # @param langcode [String, Symbol, NilClass] if nil, the same as the entry of is_orig==TRUE
  # @param to_nil: [Symbol] If true (Def: false), is_orig in any of them is nil. In some method, "orig_valid" is the opposit option name.
  # @return [Translation, NilClass] Original Tanslation. If to_nil==true, nil is returned. Or, if no Translation is found for the langcode, nil is returned, in which case is_orig of any of {Translation} is not modified at all. Or, if 
  def reset_orig_langcode(langcodearg=nil, langcode: nil, to_nil: false)  # langcode given both in the main argument and option to be in line with {#titles} etc.
    return  reset_orig_langcode_to_nil if to_nil
    return _reset_orig_langcode_to_trans(langcodearg) if langcodearg.respond_to?(:is_orig)

    langcode = (langcodearg || langcode).to_s
    raise ArgumentError, "No langcode specified" if !langcode

    origtran = nil
    best_translations.each_pair do |lcode, trans|
      if lcode.to_s == langcode
        trans.update!(is_orig: true)
        origtran = trans
        break
      end
    end

    if !origtran
      logger.warn "(#{__FILE__}:#{__method__}) No Translation if found for langcode=#{langcode} for #{self.class.name}: #{self.inspect}"
      return
    end

    _reset_orig_langcode_to_trans(origtran, set_true: false)
  end
  alias_method :reset_is_orig, :reset_orig_langcode if ! self.method_defined?(:reset_is_orig)

  # Reset orig_langcode to nil (or false if specified so) for all {#translations}
  #
  # @param to_value [NilClass, FalseClass] is_orig is set to either nil (Def) or false.
  # @return [NilClass]
  def reset_orig_langcode_to_nil(to_value: nil)
    translations.update_all(is_orig: to_value)
    return
  end

  # Reset orig_langcode to the given {Translation}
  #
  # @param origtran [Translation] Translation whose is_orig is (going to be) set true.
  # @param set_true: [Boolean] if true (Def), is_orig is set true. False can be specified just to avoid the unnecessary update action.
  # @return [Translation] Original Tanslation.
  def _reset_orig_langcode_to_trans(origtran, set_true: true)
    translations.where.not(id: origtran).update!(is_orig: false)
    origtran.update!(is_orig: true) if !set_true
    origtran
  end
  private :_reset_orig_langcode_to_trans

  # Reset orig_langcode for both self and other
  #
  # Wrapper method for internal use.
  #
  # @param other [BaseWithTranslation]
  # @param trans [Translation] original one
  # @param priority: [Symbol] eithr :self or :other
  # @return [void]
  def _reset_orig_langcode_self_other(other, trans, priority: )
    raise if ![:self, :other].include? priority
    case priority 
    when :self
        reset_orig_langcode(trans)  # In case there are multiple Translations of is_orig=true for a single BaseWithTranslation, i.e., self.
        other.reset_orig_langcode_to_nil(to_value: false)
    when :other
        reset_orig_langcode_to_nil(to_value: false)
        other.reset_orig_langcode(trans)
    else
      raise
    end
  end
  private :_reset_orig_langcode_self_other


  # Reset orig_langcode for both self and other and also reassign orig to self
  #
  # Wrapper method for internal use.
  #
  # @param other [BaseWithTranslation]
  # @param trans [Translation] original one
  # @param priority: [Symbol] eithr :self or :other
  # @return [Hash<Array<Engage>>, NilClass] nil only if it is not Music/Artist; else {remain: [Engage...], destroy: [...]}
  def _reset_reassign_orig_langcode_self_other(other, trans, priority: )
    _reset_orig_langcode_self_other(other, trans, priority: priority)
    _reassign_translation(trans, priority: :highest, force: true)
  end
  private :_reset_reassign_orig_langcode_self_other

  # Gets the sorted {Translation}-s of a specific language
  #
  # The highest-rank one (lowest in score) comes first (index=0).
  #
  # Language selection priority:
  #
  # 1. langcodearg (main argument)
  # 2. langcode (optional argument)
  # 3. {Translation#is_orig?} is true, if there is any.
  # 4. All existing translations
  #
  # This method never returns nil, though may return an empty Array.
  #
  # @todo Refactor with {best_translation} and {Translation#siblings}
  #
  # @param langcodearg [String, Symbol, NilClass] Same as the optional argument and has a higher priority.
  # @param langcode [String, Symbol, NilClass] if nil, the same as the entry of is_orig==TRUE
  # @return [ActiveRecord::AssociationRelation, Array]
  def translations_with_lang(langcodearg=nil, langcode: nil)  # langcode given both in the main argument and option to be in line with {#titles} etc.
    tras = (new_record? ? unsaved_translations : translations)
    langcode = (langcodearg || langcode || (ori=orig_translation) && ori.langcode)
    langcode &&= langcode.to_s
    if !langcode
      # Either is_orig=nil for all Translations or Translation is not defined.
      if self.id  # If not, self may be a new one and certainly has no translations.
        msg = "(#{__method__}) Failed to determine langcode for self=#{self.inspect} ; continue with a random language."
        logger.warn msg
        # warn msg
      end
      return Translation.sort(tras)
    end
    langcode &&= (langcodearg || langcode || (ori=orig_translation) && ori.langcode).to_s

    if !AVAILABLE_LOCALES.include? langcode.to_sym
      logger.warn "(#{__method__}) langcode=#{langcode} unavailable in the environment (available=#{I18n.available_locales.inspect})."
      # MultiTranslationError::UnavailableLocaleError
    end

    mdls =
      if new_record?
        tras.select{|et| et.langcode == langcode.to_s}
      else
        tras.where(langcode: langcode.to_s)
      end
    Translation.sort(mdls)
  end

  # @return [Boolean, NilClass] is_orig of {#best_translation} or nil if no Translation (or {#unsaved_translations}) is defined.
  def best_translation_is_orig(*args, **kwds)
    bt = best_translation(*args, **kwds)
    bt ? bt.is_orig : bt
  end

  # Best {Translation} for a specific language.
  #
  # If langcode is nil, the standard sorting/ordering (based on is_orig
  # and weight) regardless of langcode is applied and fallback is ignored.
  #
  # If fallback==false (Def: true), the result is the same as
  # {#best_translations}(langcode: your_langcode)
  # though this is less heavy on DB-accesses.
  #
  # @param langcodearg [String, Symbol, NilClass] Same as the optional argument and has a higher priority.
  # @param langcode [String, Symbol, NilClass] if nil or :all, langcode is not considered.
  # @param fallback [Boolean, Array] if true (Def) and if no translations are found for the specified langcode, translations in other langcode is searched for according to the priority of original language and then I18n.available_locales . Or, you can specify an Array like ["fr", "en"] to specify the order of fallback. This is ignored if langcode is nil.
  # @return [BaseWithTranslation, NilClass] nil if not found.
  def best_translation(langcodearg=nil, langcode: nil, fallback: true)  # langcode given both in the main argument and option to be in line with {#titles} etc.
    langcode = (langcodearg || langcode).to_s
    langcode = "" if "all" == langcode
    return Translation.sort(new_record? ? unsaved_translations : translations).first if langcode.blank?

    tra = translations_with_lang(langcode: langcode)
    return tra.first if !fallback || tra.exists?

    langs2try =
      if fallback.respond_to?(:map)
        fallback
      else
        ([orig_translation.langcode]+I18n.available_locales.map(&:to_s)).reject{|i| i == langcode}
      end

    langs2try.each do |lc|
      tra = translations_with_lang(langcode: lc)
      return tra.first if (tra.exists? rescue tra.present?)
    end
    nil
  end

  # Gets Hash of best {Translation}-s with keys of langcodes
  #
  # @return [Hash] like {'ja': <Translation>, 'en': <Translation>}
  def best_translations
    hsret = {}.with_indifferent_access
    ((new_record? && unsaved_translations.present?) ? unsaved_translations : translations).each do |ea_t|
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
  # @param reload [Boolean] If true (Def), self is reloaded after Creation.
  #   One more DB query is incurred, but recommended!
  # @param **kwds [Hash<Symbol, Hash, Array<Hash>>] to pass to {Translation}.new with keys like :ja and :en
  # @return [Array<Translation>]
  def create_translations!(slim_opts={}, unique_trans_keys=nil, reload: true, **kwds) ## convert_spaces: true, convert_blanks: true, strip: true, trim: true, **kwds)  ###############
    ret = update_or_create_translations_core(:create!, slim_opts, unique_trans_keys, **kwds)
    self.reload if reload
    ret
  end

  # Same as {#create_translations!} but it may update! instead of create!
  #
  # @param (see BaseWithTranslation#create_translations!)
  # @param slim_opts [Hash] Options to trim {Translation}.  Default: {COMMON_DEF_SLIM_OPTIONS}
  # @param unique_trans_keys [Array] If given, the keys (like [:ruby, :romaji]) is used
  #   to identify the {Translation}. Else {Translation.keys_to_identify} is called
  # @param reload [Boolean] If true (Def), self is reloaded after Creation.
  #   One more DB query is incurred, but recommended!
  # @return [Array<Translation>]
  def update_or_create_translations!(slim_opts={}, unique_trans_keys=nil, reload: true, **kwds)
    ret = update_or_create_translations_core(:update_or_create_by!, slim_opts, unique_trans_keys, **kwds)
    self.reload if reload
    ret
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
        hstmp = ea_hs_lang.merge({langcode: ek.to_s})
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
    self
  end

  # Same as {#with_translations} but may update the record.
  #
  # @param **kwds [Hash<Symbol>] to pass to {Translation}.new
  # @return [self]
  def with_updated_translations(**kwds)
    update_or_create_translations!(**kwds)
    self.reload  # Without reload, {#translations} may return nil.
    self
  end


  # Creates a {Translation} which is assciated to self.
  #
  # The argument must be a Hash with keys of langcodes, e.g.,
  #   a.create_translation!(langcode: "en", title: 'Imagine', is_orig: true)
  #
  # Keywords langcode and title must be specified at least.
  # title can be nil, as long as at least one of the other 5 keywords
  # (alt_title, ruby, alt_ruby, romaji, alt_romaji) is non-blank.
  #
  # Note that you probably want to include for the first one:  is_orig: true
  #
  # @param reload [Boolean] If true (Def), self is reloaded after Creation.
  #   One more DB query is incurred, but recommended!
  # @param convert_spaces: [Boolean] if True (Default), all blanks+returns are converted to ASCII spaces.
  # @param convert_blanks: [Boolean] if True (Default), all blanks (spaces or tabs) are converted to ASCII spaces.
  # @param strip: [Boolean] if True (Default), all strings are stripped with initial and trailing spaces.
  # @param trim: [Boolean] if True (Default), all multiple spaces are trimmed to a single space.
  # @param **kwds [Hash<Symbol>] to pass to {Translation}.new
  # @return [Translation]
  def create_translation!(reload: true, **kwds)
    ret = update_or_create_translation_core(:create!, **kwds)
    self.reload if reload
    ret
  end


  # Same as {#create_translation!} but it may update! instead of create!
  #
  # @param reload [Boolean] If true (Def), self is reloaded after Creation.
  #   One more DB query is incurred, but recommended!
  # @param (see BaseWithTranslation#create_translation!)
  # @return [Translation]
  def update_or_create_translation!(reload: true, **kwds)
    ret = update_or_create_translation_core(:update_or_create_by!, **kwds)
    self.reload if reload
    ret
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
    self
  end

  # Same as {#with_translation} but may update the record.
  #
  # @param **kwds [Hash<Symbol>] to pass to {Translation}.new
  # @return [self]
  def with_updated_translation(**kwds)
    update_or_create_translation!(**kwds)
    self.reload
    self
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
    self
  end

  # Same as {#with_orig_translation} but may update the record.
  #
  # @param **kwds [Hash<Symbol>] to pass to {Translation}.new
  # @return [self]
  def with_orig_updated_translation(**kwds)
    update_or_create_translation!(**({is_orig: true}.merge(kwds)))
    self.reload
    self
  end


  # Returns the Hash of the best translated_words of all languages
  #
  # @param attr [String, Symbol] method name
  # @param safe: [Boolean] if true, this returns '' instead of nil.
  # @return [Hash] key(langcode) => word (maybe nil) (n.b., with_indifferent_access)
  def all_best_titles(attr=:title, safe: false)
    AVAILABLE_LOCALES.map{ |ec|
      val = send(attr, langcode: ec.to_s) 
      val = '' if !val && safe
      [ec.to_s, val]
    }.to_h.with_indifferent_access
  end

  ######################
  
  # Returns a unique weight
  #
  # If (:priority == :highest) or (:priority == :high and tra_other.weight is 0),
  # existing Translations (there should be at most one but there is no validation for it so far)
  # with weight=0 if any are set in the given Array +to_destroy+.  The caller may destroy them.
  #
  # @param tra_other [Translation]
  # @param priority: [Symbol] :highest, :high (Def), :low, :lowest in assigning a new weight
  #    :highest and :lowest guarantee the new weight will be lowest/highest, respectively
  #    (NOTE: when +priority+ is high, +weight+ is low!  So it is reversed).
  #    :high and :low means unless there is a collision in weight, you leave it;
  #    otherwise the returned weight is shifted slightly.
  # @param to_destroy: [Array] For returning. Existing Translations with weight=0 if (:priority is :highest or :high). They are set.
  # @return [Float] unique weight
  def get_unique_weight(tra_other, priority: :high, to_destroy: [])
    weight_def = Role::DEF_WEIGHT.values.max
    weight_t = tra_other.weight 

    # Maybe there is a collision in weight.
    sorted_tras = Translation.sort(translations.where(langcode: tra_other.langcode), consider_is_orig: false)

    if (:highest == priority || (:high == priority && weight_t && weight_t <= 0)) && (origs = sorted_tras.where('weight <= 0')).exists?
      to_destroy.concat origs
      return 0
    end

    # there should be no nil, as Translation#weight should be always defined.
    # uniq is necessary to eliminate multiple Float::INFINITY
    arweight = sorted_tras.pluck(:weight).compact.uniq

    case priority
    when :high, :low
      index = arweight.find_index(weight_t)
      return weight_t if !index  # There is no existing weight that agrees with

      case priority
      when :high
        if 0 == index 
          if Float::INFINITY == weight_t
            weight_def  # If only the existing weight is Infinity and my weight is also Infinity.
          else
            weight_t.quo(2)
          end
        elsif Float::INFINITY == weight_t
          arweight[index-1]*2 # ==arweight[-2]*2  # twice as the largest existing weight except Infinity.
        else
          (arweight[index]+arweight[index-1]).quo(2)
        end
      when :low
        if arweight.size - 1 == index 
          weight_t*2 
        else
          (Float::INFINITY == arweight[index+1]) ? arweight[index]*2 : (arweight[index]+arweight[index+1]).quo(2)
        end
      end
    when :highest
      weight_cand = (arweight.empty? ? weight_def    : (arweight[0] || weight_def*2).abs.quo(2))
      weight_cand = weight_def if Float::INFINITY == weight_cand
      [(weight_t || Float::INFINITY), weight_cand].min
    when :lowest
      weight_cand = (arweight.empty? ? weight_def*10 : (arweight[-1] || Float::INFINITY).abs*2)
      [(weight_t || Float::INFINITY), weight_cand].max
    else
      raise
    end
  end

  # @param priorities [Hash<Symbol, Symbol>] an element is like :birthday => :other. Usually :default is recommended.
  # @param kwd [Symbol] Keyword, e.g., :prefecture_place
  # @return [Symbol] either :self or :other
  # @raise [RuntimeError] if neither kwd nor :default is defined for priorities
  def _priority2pass(priorities, kwd)
    retsym = (priorities[kwd] || priorities[:default])
    raise MissingRequirementError, "(#{__method__}) Neither Keyword (#{kwd}) nor :default is defined in the given priorities: #{priorities.inspect}" if !%i(self other).include?(retsym)  # BaseWithTranslation::MissingRequirementError
    retsym
  end
  private :_priority2pass

  # Returns the merged self (either Artist or Music)
  #
  # If an error raises in any of the save, it rollbacks.
  # Even if +save_destroy: false+, the related models like {Translation} are STILL updated!
  # So, for a test run, the caller must make sure to contain the calling routine
  # inside a transaction (and maybe rollbacks at the end of the process).
  #
  # The argument Hash +priorities+ must have either all the required keywords
  # for processing self or +{:default => :self|:other}+.  Otherwise,
  # BaseWithTranslation::MissingRequirementError is raised
  #
  # originally existed in app/controllers/base_merges_controller.rb
  #
  # == Returned Hash
  #
  #   trans:  Hash{remained: [Translation...], destroy: [Translation...], original: Translation}
  #     n.b., remained Array includes the original-Translation, too. Keys :tr_html and :tr_orig_html will be added.
  #   engage: Hash{remained: [Engage...],      destroy: [Engage...]}
  #   harami1129: Hash{remained: [Harami1129...], destroy: []}  # Harami1129 would be never destroyed.
  #   bday3s: Hash{birth_year: Integer, birth_month: Integer, birth_day: Integer}
  #     n.b., Missing Birthday part in one is ALWAYS supplemented by the other if there is any.
  #     e.g., (Y,M,S)=(1999,nil,3)&(2000,5,nil) => (1999,5,3) or (2000,5,3)
  #   prefecture_place: Place
  #   genre: Genre
  #   year: Integer
  #   sex: Sex
  #   wiki_en: String
  #   wiki_ja: String
  #   harami_vid_music_assocs: Hash{remained: [HaramiVidMusicAssocs...], destroy: [HaramiVidMusicAssocs...], n_destroyed: Integer}
  #   note: String
  #   created_at: DateTime(?)
  #   destroyed: Array[Model, ...]
  #
  # Note that a top-level key is (already) +:destroyed+ and a 2nd-level key is +:destroy+ (now or later after it was first created).
  # If (save_destroy: true), all :destroy Arrays should be empty and instead :destroyed contain destroyed Models.
  # If (save_destroy: false), :destroy Arrays contain Models to be destroyed AND those that have been already destroyed. The :destroyed Array should be empty.
  #
  # @example Standard execution (in one go)
  #    ActiveRecord::Base.transaction(requires_new: true) do
  #      hsret = music_to_merge.merge_other(other, priorities: {default: :other, lang_orig: :other}, save_destroy: true,  user: current_user)  # current_user defined in Controllers only; nil is OK.
  #      # => self is updated. other is destroyed.
  #    end
  #
  # @example separate execution (watch out for "other")
  #    ActiveRecord::Base.transaction(requires_new: true) do
  #      hsret = music_to_merge.merge_other(other, priorities: {default: :other, lang_orig: :other}, save_destroy: false, user: current_user)  # current_user defined in Controllers only; nil is OK.
  #      # ...
  #      music_to_merge.merge_save_destroy(hsret[:other], hsret)
  #    end
  #
  # @param other [BaseWithTranslation] of the same class
  # @param priorities: [Hash<Symbol => Symbol>] e.g., :year => :other (or :self). A key may be :default .
  #   Other than standard attribute/method names, including :engages, :harami_vid_music_assocs, and :note,
  #   the folloing special keys are accepted:
  #    :lang_orig, :lang_trans, :prefecture_place, :birthday
  # @param save_destroy: [Boolean] If true (Def), self is saved and the other is destroyed. If one fails, the entire transaction rollbacks.
  # @param user: [ApplicationRecord, NilClass] current_user
  # @return [Hash<Object, Hash<Array, Integer>>] See above.
  # @raise [BaseWithTranslation::MissingRequirementError] if +priorities+ is incomplete (see above).
  def merge_other(other, priorities: {}, save_destroy: true, user: nil)
    hsmodel = {engage: nil, harami1129: nil}
    ActiveRecord::Base.transaction(requires_new: true) do  # "requires_new" option necessary for testing.
      hsmodel[:trans]  = _merge_trans(other, priority_orig: _priority2pass(priorities, :lang_orig), priority_others: _priority2pass(priorities, :lang_trans)) # , orig_valid: true)
      hsmodel[:engage] = hsmodel[:harami1129] = nil
      hs = _merge_engages(other, priority: _priority2pass(priorities, :engages))  # updates Harami1129#engage_id, too
      hsmodel.merge!(hs) if hs  # keys of :engage and (probably?) :harami1129
      hsmodel[:bday3s] = _merge_birthday(  other, priority: _priority2pass(priorities, :birthday))
      %i(prefecture_place genre year sex wiki_en wiki_ja).each do |metho| 
        #next if !priorities.has_key?(metho)
        hsmodel[metho] = _merge_overwrite(other, metho, priority: _priority2pass(priorities, metho))
      end
      hsmodel[:harami_vid_music_assocs] = 
        _merge_harami_vid_music_assocs(other, priority: _priority2pass(priorities, :harami_vid_music_assocs))
      hsmodel[:artist_music_play] = _merge_artist_music_plays(other, priority: _priority2pass(priorities, :artist_music_play))
      hs = _merge_channel_owners(other, priority: _priority2pass(priorities, :channel_owner))  # nil if for Music
      hsmodel.merge!(hs) if hs  # keys of :channel_owner, :channel, and maybe :harami_vid

      hsmodel[:note]   = _merge_note(  other, priority: _priority2pass(priorities, :note))
      hsmodel[:created_at] = _merge_created_at(other)

      hsmodel[:harami1129_review] = _update_harami1129_review_after_merge(hsmodel, user: user)

      hsmodel[:destroyed] ||= []
      hsmodel[:other] = other

      other.artist_music_plays.reset if other.respond_to? :artist_music_plays
      if save_destroy
        hsmodel = merge_save_destroy(other, hsmodel)
      end
    end
    _uniq_hsmodel!(hsmodel)
  end # def merge_other(other, priorities: {}, save_destroy: true)

  # run unique for child/grand-child components
  #
  # @param hsmodel [Hash]
  # @return [Hash]
  def _uniq_hsmodel!(hsmodel)
    hsmodel.each_value do |ev1|
      if ev1.respond_to? :uniq!
        ev1.uniq!
      elsif ev1.respond_to? :each_value
        ev1.each_value do |ev2|
          if ev2.respond_to? :uniq!
            ev2.uniq!
          end
        end
      end
    end
    hsmodel
  end
  private :_uniq_hsmodel!

  # Save&Destroy for #{merge_other}
  #
  # @param other [BaseWithTranslation] of the same class
  # @param hsmodel [Hash] See merge_other for description
  # @return [self]
  def merge_save_destroy(other, hsmodel)
    hsmodel[:channel_owner][:destroy].first.destroy! if hsmodel[:channel_owner] && hsmodel[:channel_owner][:destroy].present? && !hsmodel[:channel_owner][:destroy].first.destroyed?  # ChannelOwner must be destroyed first.

    artist_music_plays.reset if respond_to? :artist_music_plays  # for some reason, this has to be placed here...
    self.save!

    # Channel, ChannelOwner
    %i(:channel :channel_owner).each do |klass|
      if hsmodel[klass] && hsmodel[klass].respond_to?(:keys)
        hsmodel[klass][:destroy].each do |mdl|
          # Most of them have been either already destroyed or cascade-destroyed.
          mdl.destroy if !mdl.destroyed?
          hsmodel[:destroyed] << mdl
        end
        hsmodel[klass][:destroy] = []  # reset
      end
    end

    # HaramiVidMusicAssocs
    if hsmodel[:harami_vid_music_assocs] && hsmodel[:harami_vid_music_assocs].respond_to?(:keys)
      hsmodel[:harami_vid_music_assocs][:destroy].each do |mdl|
        # This is probably not needed... cascade-destroyed?
        hsmodel[:destroyed] << mdl
        mdl.destroy
      end
      hsmodel[:harami_vid_music_assocs][:n_destroyed] = hsmodel[:harami_vid_music_assocs][:destroy].size
      hsmodel[:harami_vid_music_assocs][:destroy] = []  # reset
    end

    # Engage, ArtistMusicPlay
    %i(engage artist_music_play).each do |model|
      if hsmodel[model] && hsmodel[model].respond_to?(:keys)
        hsmodel[:destroyed].concat hsmodel[model][:destroy]  # This should be cascade-destroyed.
        hsmodel[model][:destroy] = []  # reset
      end
    end

    # Translation
    hsmodel[:destroyed].concat hsmodel[:trans][:destroy]  # This should be cascade-destroyed.  Some of them should have been already destroyed anyway!
    hsmodel[:trans][:destroy] = []  # reset

    other.reload
    other.destroy
    hsmodel[:other] = other
    hsmodel[:destroyed] << other
    hsmodel
  end

  # Overwrite a simple attribute of model, according to the priority, unless it is nil (in which case the other is used).
  #
  # * prefecture_place: 'prefecture_place',
  # * genre: 'genre',
  # * year: 'year',
  # * sex: 'sex_id',
  #
  # @todo  genre has Genre.default, place has Place.unknown
  #
  # @param other [BaseWithTranslation] of the same class as self
  # @param metho [Symbol]
  # @param priority: [Symbol] (:self(Def)|:other)
  # @return [Object] the updated value (like Place)
  def _merge_overwrite(other, metho, priority: :self)
    attrstr = ((metho == :prefecture_place) ? :place : metho).to_s
    return if !respond_to?(attrstr)
    raise "Should not happen Contact the code developer." if !other.respond_to?(attrstr)
    #attrstr += "_id" if respond_to?(attrstr+"_id")  # eg., Uses sex_id instead of "sex"
    contents = _prioritized_models(other, priority, __method__).map{|mdl| mdl.send(attrstr)}.sort{|a, b|
      if a == b
        0
      elsif a.nil?
        b.nil? ? 0 : 1
      elsif b.nil?
        -1
      elsif a.blank?
        b.blank? ? 0 : 1
      elsif b.blank?
        -1
      elsif a.respond_to?(:encompass_strictly?) && a.encompass_strictly?(b)
        # This has to come before checking unknown? b/c Place has many unknown-s.
        1
      elsif b.respond_to?(:encompass_strictly?) && b.encompass_strictly?(a)
        -1
      elsif a.respond_to?(:unknown?) && a.unknown?
        (b.respond_to?(:unknown?) && b.unknown?) ? 0 : 1
      elsif b.respond_to?(:unknown?) && b.unknown?
        -1
      elsif a.respond_to?(:default?) && a.default?
        (b.respond_to?(:default?) && b.default?) ? 0 : 1
      elsif b.respond_to?(:default?) && b.default?
        -1
      else
        0
      end
    }.compact
    send(attrstr+"=", contents.first)
  end
  private :_merge_overwrite


  # Overwrite/merge the Birthday-related columns of the model.
  #
  # If one of them misses birth_year and if the other has one,
  # then the significant one is adopted;
  # e.g., (Y,M,S)=(1999,nil,3)&(2000,5,nil) => (1999,5,3) or (2000,5,3)
  #
  # @param other [BaseWithTranslation] of the same class as self
  # @param priority: [Symbol] (:self(Def)|:other)
  # @return [Hash<Integer>] {birth_year: 1980, ...}
  def _merge_birthday(other, priority: :self)
    return if !respond_to?(:birth_year)
    raise "Should not happen Contact the code developer." if !other.respond_to?(:birth_year)
    bday_attrs = %i(birth_year birth_month birth_day)
    bday3s = {}
    _prioritized_models(other, priority, __method__).each do |mdl|
      bday_attrs.each do |attrsym|
        bday3s[attrsym] ||= mdl.send(attrsym)
        next if bday3s[attrsym].blank?
        send(attrsym.to_s+"=", bday3s[attrsym])  # self.birth_year(etc) may be overwritten (before the next loop)
      end
    end

    return bday3s
  end

  # notes are, unlike other parameters, simply merged.
  #
  # The note for the preferred comes first.
  # In an unlikely case of both notes being identical, one of them is discarded.
  #
  # As a retult of this, {#note} becomes non-nil but maybe blank.
  #
  # @param other [BaseWithTranslation] of the same class as self
  # @param priority: [Symbol] (:self(Def)|:other)
  # @return [String]
  def _merge_note(other, priority: :self)
    self.note = _prioritized_models(other, priority, __method__).map{|i| (i.note.strip rescue nil)}.compact.uniq.join(" ")
  end
  private :_merge_note

  # Append note to Model
  #
  # @param mdl   [BaseWithTranslation] note to append to
  # @param other [BaseWithTranslation] of the same class as mdl
  # @param reverse: [Boolean] If specified true, the order is reversed.
  # @return [String] the updated value
  def _append_note!(mdl, other, reverse: false)
    if !other.note.blank?
      if mdl.note.blank?
        mdl.note = other.note.strip
      elsif !mdl.note.include?(other.note)
        ar = [mdl.note.strip, other.note.strip]
        ar.reverse! if reverse
        mdl.note = ar.join(" ")
      end
    end
    mdl.note
  end
  private :_append_note!


  # Merge Translations with is_orig=true
  #
  # 1. If the languages are the same, the unselected one is deleted (title, alt_title, and all).
  #    1. However, if the unselected one has both `title` and `alt_title`, and the selected one has only `title`, the `alt_title` is transferred to `alt_title` of the selected one.
  # 2. If the languages are different, the unselected one is ignored, except its is_orig is set false
  #
  # If there are multiple is_orig=true, those except for the true one are set false.
  #
  # @param other [BaseWithTranslation] of the same class as self
  # @param priority: [Symbol] (:self(Def)|:other)
  # @param orig_valid: [Symbol] If false (Def: true), is_orig in any of them is nil.
  # @return [Hash<Array<Translation>>, NilClass] nil only if it is not Music/Artist; else {remain: [Translation...], destroy: [...]}
  def _merge_lang_orig(other, priority: :self, orig_valid: true)
    reset_orig_langcode_to_nil if !orig_valid
    transs = _prioritized_models(other, priority, __method__).map(&:orig_translation).compact

    case transs.size
    when 0   # None has is_orig=true
      if orig_valid
        reset_orig_langcode_to_nil(to_value: false)
        other.reset_orig_langcode_to_nil(to_value: false)
      end
      return {remained: [], destroy: []}
    when 1   # Only one of them has is_orig=true
      tra_orig = transs.first
      raise "Contact the code developer (translatable mismatch)." if tra_orig.translatable.class != self.class
      if tra_orig.translatable == self  # self.orig_translation is the only one with is_orig==true
        _reset_orig_langcode_self_other(other, tra_orig, priority: :self)
        return {remained: [tra_orig], destroy: []}
      end
      return _reset_reassign_orig_langcode_self_other(other, tra_orig, priority: :other)
    when 2
      # skip
    else
      raise  # this should never happen as orig_translation() should return a single Translation
    end

    # Both have orig_translation
    raise "Contact the code developer (translatable_type mismatch: #{transs.map(&:translatable_type).inspect})." if transs.map(&:translatable_type).uniq.size > 1

    (tra_orig, tra_other) = transs  # tra_orig is the new original Translation (it may belong to self or other!)

    if transs.map(&:langcode).uniq.size != 1 # langcode-s are different
      if tra_orig.translatable == self
        # Basically does nothing but adjusts is_orig .
        _reset_orig_langcode_self_other(other, tra_orig, priority: :self)
        return {remained: [tra_orig], destroy: []}
      else
        # Condition: Both have orig && langcode-s differ && priority==:other
        return _reset_reassign_orig_langcode_self_other(other, tra_orig, priority: :other)
      end
    end

    # langcode-s are common
    # alt_title can be copied if existent. note-s are merged.
    if tra_orig.alt_title.blank? && tra_other.title.present? && tra_other.alt_title.present? 
      tra_orig.alt_title = tra_other.alt_title
      _append_note!(tra_orig, tra_other)
      tra_orig.created_at = _older_created_at(tra_orig, tra_other)
tra_orig.save!
    end

    tra_other.destroy  # has to be destroyed before the new one is assigned.
    if tra_orig.translatable == self
      _reset_orig_langcode_self_other(other, tra_orig, priority: :self)
      return {remained: [tra_orig], destroy: [tra_other]}
    else
      reths = _reset_reassign_orig_langcode_self_other(other, tra_orig, priority: :other)
      reths[:destroy].push tra_other
      return reths
    end
  end
  private :_merge_lang_orig

  # Merge Translations from other to self
  #
  # If two of them have same weights and langcode (it should never happen
  # between the Translations for the same {BaseWithTranslation}, but because we are
  # handling two {BaseWithTranslation}-s, it can happen), one of the weights
  # must be adjusted before merging multiple {Translation}, that is,
  # unifying their parent into one {BaseWithTranslation}.
  #
  # This ignores any Translation with is_orig=true. So,
  # {#_merge_lang_orig} should be called before this method, though technically not mandatory.
  #
  # @param other [BaseWithTranslation] of the same class as self
  # @param priority: [Symbol] (:self(Def)|:other)
  # @param orig_valid: [Symbol] If false, is_orig in any of them is nil.
  # @return [Hash<Array<Translation>>, NilClass] nil only if it is not Music/Artist; else {remained: [Translation...], destroy: [...]}
  def _merge_lang_trans(other, priority: :self, orig_valid: true)
    prio = ((:self == priority) ? :low : :high)
    reths = {remained: [], destroy: [], errors: []}
    (self.translations.pluck(:langcode)+other.translations.pluck(:langcode)).uniq.each do |lcode|
      artrans_self  = Translation.sort(translations.where(langcode: lcode))
      artrans_other = Translation.sort(other.translations.where(langcode: lcode))
      artrans = ((:self == priority) ? artrans_self+artrans_other : artrans_other+artrans_self)

      artrans.each_with_index do |etra, ind|  # etra: Each_TRAnslation
        next if etra.is_orig  # ignores any Translation with is_orig=true
        if etra.translatable == self
          hscand = {remained: [], destroy: []}
          hscand[:remained] << etra if Translation.exists?(etra.id)  # Only if it is present; the Translation may have already been destroyed (in order to add a conflicting one from other). Note "etra.present?" is affected by cache and so is unsuitable.
        else
          if (hscand = _attempt_add_other_trans(etra, prio: prio, other_comes_first: (:other == priority)))
            # skip
          else
            hscand = nil
            translations.where(langcode: etra.langcode).where.not(is_orig: true).each do |etra_self|
              hscand = _attempt_add_other_trans(etra, tra_self: etra_self, prio: prio, other_comes_first: (:other == priority))
              break if hscand
            end
          end
        end

        if hscand
          reths[:remained].concat hscand[:remained]
          reths[:destroy ].concat hscand[:destroy]
        else
          # All attempts to try to add a Translation to self have failed.
          # This would happen when other's candidate (is_orig=false) is (almost) identical to self's is_orig=true.
          reths[:destroy ].push etra
          reths[:errors].push sprintf("Translation (%s|%s) (ID=%d) failed to be merged probably because of the original language constraint.", etra.title, etra.alt_title, etra.id)
        end
      end
    end

    reths[:remained].uniq!
    reths[:destroy ].uniq!
    reths[:remained].map(&:reload)  # Is it needed??
    reths
  end
  private :_merge_lang_trans

  # core routine to attempt to add a Translation from other to self
  #
  # If other_comes_first is false (Default) and if it fails, other is included in :destroy Array in the returned Hash.
  #
  # If not, a Translation for self is destroyed first (if specified), and adding a new one (from other) is attempted.
  # If successful, return the standard Hash(:remained, :destroy), else nil.
  #
  # @param other_comes_first: [Boolean] If true, a Translation in self is attempeted to be destroeyd, before a new one is added
  # @return [Hash<Array<Translation>>, NilClass] nil only if it is not Music/Artist; else {remained: [Translation...], destroy: [...]}
  def _attempt_add_other_trans(tra_other, tra_self: nil, prio: :low, other_comes_first: false)
    hsret = nil
    ActiveRecord::Base.transaction(requires_new: true) do  # "requires_new" option necessary for testing; otherwise testing would not properly handle rollbacks. Also, don't return from inside the transaction as it would rollback!
      tra_self.destroy if tra_self && other_comes_first
      hsret = _reassign_translation(tra_other, priority: prio, force: false)
      if !other_comes_first
        # Skip  # Don't return from inside Transactino.
      elsif !hsret[:destroy].include? tra_other
        hsret[:destroy].push(tra_self.destroy) if tra_self
      else
        hsret = nil
        raise ActiveRecord::Rollback, "Force rollback."  # failed to add the Translation.
      end
    end
    return hsret if hsret

    tra_self.reload if tra_self
    nil
  end
  private :_attempt_add_other_trans

  # Merge Translations from other to self (both original-language and others)
  #
  # @param other [BaseWithTranslation] of the same class as self
  # @param priority_orig: [Symbol] (:self(Def)|:other)
  # @param priority_others: [Symbol] (:self(Def)|:other)
  # @param orig_valid: [Symbol] If false, is_orig in any of them is nil.
  # @return [Hash<Array<Translation>>, NilClass] nil only if it is not Music/Artist; else {remained: [Translation...], destroy: [...], original: Translation}
  #    Also, it contains the key :original with the value of the original Translation if any.
  #    The same Translation is also contained in the :remained Array.
  def _merge_trans(other, priority_orig: :self, priority_others: :self, orig_valid: true)
    reths_orig   = _merge_lang_orig(other, priority: priority_orig, orig_valid: orig_valid)
    reths_others = _merge_lang_trans(other, priority: priority_others)
    _hash_array_merge(reths_orig, reths_others).merge({original: reths_orig[:remained].first})
  end
  private :_merge_trans

  # Returns a merged Hash of two Hash of Arrays. The values have to be Arrays.
  #
  # @param hs1 [Hash]
  # @param hs2 [Hash]
  # @return [Hash]
  def _hash_array_merge(hs1, hs2)
    hsret = hs1.merge({})
    (hs1.keys + hs2.keys).each do |ek|
      if hsret[ek]
        hsret[ek].concat hs2[ek]
      else
        hsret[ek] = hs2[ek]
      end
    end
    hsret
  end
  private :_hash_array_merge

  # merging Engage, handling Harami1129s, where Engage-s may be merged or possibly just one of them is modified (like music_id).
  #
  # If there are multiple Engages related to self (either Music/Artist) that have the same
  # Music/Artist/EngageHow, then they will be merged.  If one of them that is merged to something else
  # is referred to from Harami1129, then {Harami1129#engage_id} must change, too, which
  # this method handles.  Otherwise, Engage-s would not disappear and hence no change
  # in Harmai1129.
  #
  # For example, if only the Engages for Music_1a/1b are
  # Engage(Composer-Music_1a) and Engage(Lyricist-Music_1b), they would survive
  # after Music_1a and 1b are merged.
  #
  # In practice, most of EngageHows are default semi-automatically ones imported from Harami1129.
  # Therefore, modification in Harami1129 frequently happens after merging Music or Artist.
  #
  # With this routine, many Engage may be updated in DB.
  # This may update Harami1129 in DB, too(!).
  # However, this does not destroy Engages to discard. They should be cascade-deleted when
  # an Artist/Music is destroyed (which should be done shortly after this method is called).
  # If you want to destroy them explicitly, do:
  #
  #   hs = _merge_engages(other, priority: :self)
  #   hs[:destroy].each do |em|
  #     em.destroy
  #   end
  #
  # Unlike other sub-methods of of {#merge_other}, this method returns a Hash of Hash,
  # the top level of keys are :engage and :harami1129.  In the returned Hash +hsret+,
  #   hsret[:harami1129][:destroy] == []
  # always holds, because merging Artist or Music would not lead to destroying Harami1129.
  # If no Engages are destroyed,
  #   hsret[:harami1129][:remained].empty? == true
  # because Engage's "internal" change does not affect any of Harami1129 (and so
  # the related Harami1129-s can be easily retrieved from the remaining Engage-s, should you wish).
  #
  # @param other [BaseWithTranslation] of the same class as self. This method makes sense only for Music/Artist (not Harami1129)
  # @param priority: [Symbol] (:self(Def)|:other)
  # @return [Hash<Hash<Array<Engage>>>, NilClass] nil only if it is not Music/Artist; else {engage: {remained: [Engage...], destroy: [...]}, harami1129: {...}}
  def _merge_engages(other, priority: :self)
    return if !respond_to?(:engages)
    raise "Should not happen Contact the code developer." if !other.respond_to?(:engages)
    all_engages = []
    is_music = !respond_to?(:musics)
    remains = _prioritized_models(other, priority, __method__).map.with_index{ |emdl, ind|
      all_engages.push emdl.engages
      all_engages[-1].map{ |eng|
        hsprm = (is_music ? {artist: eng.artist, music: self} : {artist: self, music: eng.music})
        mdl = (Engage.where(hsprm).where(engage_how: eng.engage_how).first || eng)  # If one of self.engages has the same Artist & Music & EngageHow, it is used.
        if is_music 
          mdl.music  = self
        else
          mdl.artist = self
        end

        # Following is updated only when Music, Artist, and EngageHow all agree
        mdl.year = eng.year if ind == 0 && eng.year
        mdl.year ||= eng.year
        if eng.contribution && eng.contribution > 0
           mdl.contribution = eng.contribution if ind == 0
           mdl.contribution = eng.contribution if (!mdl.contribution || mdl.contribution <= 0)
        end

        _append_note!(mdl, eng)
        mdl.created_at = _older_created_at(mdl, eng)

        mdl.save!
        mdl
      }
    }.flatten.uniq

    to_destroys = all_engages.flatten.uniq.select{|mdl| !remains.include?(mdl) }

    ## Register to destroy EngageHow.unknown-s if there is another one for the same Music and Artist that is NOT unknown. 
    if remains.size > 1
      eng_unknowns = remains.select{|eng| eng.engage_how.unknown?}
      tmp2destroy = eng_unknowns.select{ |engkn|
        remains.any?{ |em|
         !em.engage_how.unknown? &&
          em.id != engkn.id &&
          em.music  == engkn.music &&
          em.artist == engkn.artist
        }
      }.compact
      to_destroys.concat tmp2destroy
      remains.delete_if{|em| tmp2destroy.include?(em)} 
    end

    ## Update dependent Harami1129
    ids_to_destroy = to_destroys.map(&:id)
    remains_hs1129 = to_destroys.map{ |eng|
      hsprm = (is_music ? {artist: eng.artist, music: self} : {artist: self, music: eng.music})
      eng.harami1129s.map{ |harami1129|
        new_eng = Engage.where(hsprm).where.not(id: ids_to_destroy).joins(:engage_how).order(:weight).first  # There may be multiple candidatesi Engages. Picks one of the least-weight one (in terms of EngageHow).
        harami1129.update!(engage: new_eng)
        harami1129
      }
    }.flatten.compact.uniq # remains_hs1129 = to_destroys.map{ |eng|

    remains.map(&:reload)  # I do not know why this is required...
    {engage:     {remained: remains,        destroy: to_destroys},
     harami1129: {remained: remains_hs1129, destroy: []}}
  end
  private :_merge_engages


  # merging ChannelOwner-s
  #
  # == Algorithm: Four-ish cases.
  #
  # === Visualization of the the most complicated situation
  #
  # The following is for Case 4. Here, Left-hand one has a higher priority than Right. There are 2 cases:
  #
  #   Cow(art=self)  Cow(art=other) | Cow(art=other) Cow(art=self)
  #    |              |     ->DEL   |  | 4:Art-self  |  (3)->DEL
  #   Channels..<--  Channels..     | Channels..<--  Channels..
  #    | updat \      | ->DEL/upd   |  | 2-1  \      | ->(1)Upd/(2-3)DEL
  #   HVids..  +---- HVids..        | HVids..  +---- HVids..(2-2)
  #
  # === Procedure
  #
  # 1. If not Artist, return nil
  # 2. If no ChannelOWners (=Cows), returns (viatually empty) Hash.
  # 3. If only one Cow exists [regardless of higher/lower priority],
  #    1. update Cow#artist=self  [which may or may not be already the case]
  #    2. update Cow#themselves=true  [redundant, but playing safe]
  #    3. Cow#synchronize_translations_to_artist  End.
  # 4. If Cows exist for both, do as follows (also see the figure above):
  #    1. Left-hand case (Merge-Destroy Cow(R), taking care of Channels(R) and HaramiVids(R))
  #       1. if no Channels(R),
  #          1. merge Cow(R)-note to Cow(L)
  #          2. Destroy Cow(R). End.
  #       2. Else, update Channels(R)#CoW = Cow(L)  (multiple)  # => _merge_channel_owners_with_artist_with_channels
  #          1. If successful, fine.
  #          2. Else, find the Channel(L)                       # => _merge_channel_owners_with_artist_merge_channels
  #             1. merge note to the_Channel(L)
  #             2. HVids(R)#channel = the_Channel(L)  (multiple, if any)
  #             3. Destroy the_Channels(R)
  #       3. Destroy Cow(R)
  #    2. Right-hand case (Same as Left-hand case, except case 3 is then followed).
  #       1. Follow 4-1
  #       2. Now reduced to case 3; follow it for Cow(L)
  #
  # @param other [BaseWithTranslation] of the same class as self. For this method, it makes sense only for Artist
  # @param priority: [Symbol] (:self(Def)|:other)
  # @return [Hash<Array<ArtistMusicPlay>>, NilClass] nil only if self is not Artist; else {channel_owner: {remained: [ChannelOwner], destroy: [ChannelOwner]}, channel: {...}, harami_vid: {...}} (up to 1 element each for channel_owner and potentially many for the others; no destroy for harami_vid)
  def _merge_channel_owners(other, priority: :self)
    return if !respond_to?(:channel_owner)  # because it is a singular, Artist is the only relevant one?
    raise "Should not happen Contact the code developer." if !other.respond_to?(:channel_owner)
    return if !is_a?(Artist) || !other.is_a?(Artist)

    hsret = {
      channel_owner: {remained: [], destroy: []},
      channel:       {remained: [], destroy: []},
    }.map{|ek, ev| [ek, ev.with_indifferent_access]}.to_h.with_indifferent_access

    remains = _prioritized_models(other, priority, __method__).map(&:channel_owner)

    if (ary=remains.compact).empty?
      # Case 2
      return hsret
    elsif 1 == ary.size
      # Case 3
      _merge_channel_owners_set_artist(ary.first)
      hsret[:channel_owner][:remained] << ary.first
      return hsret
    else
      # Case 4
      if self == remains[0].artist
        _merge_channel_owners_with_artist(*remains, hsret: hsret)
      else
        _merge_channel_owners_with_artist(*remains, hsret: hsret)  # This sets hsret
        _merge_channel_owners_set_artist(remains.first)
      end
      return hsret
    end
  end
  private :_merge_channel_owners

  # Set Artist to ChannelOwner and save ChannelOwner
  #
  # @return [Boolean]
  # @raise [RuntimeError] in a totally unexpected case only
  def _merge_channel_owners_set_artist(channel_owner, artist=self)
    ActiveRecord::Base.transaction(requires_new: true) do
      channel_owner.reset_to_artist(artist, force: true)
      if !channel_owner.valid?   ### This should be put into Controller validation!!
        errmsg = "ChannelOwner(#{remains[1].id}) cannot be associated with Artist(#{title_or_alt(prefer_alt: true, str_fallback: '', article_to_head: true)}) presumably because there is another ChannelOwner with the Artist."
        raise errmsg
      end
      channel_owner.save!
    end
  end
  private :_merge_channel_owners_set_artist

  # Case 4-1 in _merge_channel_owners
  #
  # @param chow_l [ChannelOwner] "Left" ChannelOwner, meaning higher-priority. Its Artist is self.
  # @param chow_r [ChannelOwner] "Right" ChannelOwner, meaning lower-priority. Either updated or destroyed (after merging)
  # @return [Hash<Array<ArtistMusicPlay>>] See #_merge_channel_owners
  def _merge_channel_owners_with_artist(chow_l, chow_r, hsret: {})
    if !chow_r.channels.exists?
      # Case 4-1-1
      _append_note!(chow_l, chow_r)  # merge notes
      chow_l.save!
    else
      # Case 4-1-2
      _merge_channel_owners_with_artist_with_channels(chow_l, chow_r, hsret: hsret)  # modifies hsret, adding {channel: {}}
    end
    chow_r.channels.reset
    chow_r.destroy!   #### later, may delegate to the later process.
    hsret[:channel_owner][:remained] << chow_l
    hsret[:channel_owner][:destroy]  << chow_r
  end
  private :_merge_channel_owners_with_artist

  # Case 4-1-2 in _merge_channel_owners
  #
  # @param chow_l [ChannelOwner] "Left" ChannelOwner, meaning higher-priority. Its Artist is self.
  # @param chow_r [ChannelOwner] "Right" ChannelOwner, meaning lower-priority. Either updated or destroyed (after merging)
  # @return [Hash<Array<ArtistMusicPlay>>] See #_merge_channel_owners
  def _merge_channel_owners_with_artist_with_channels(chow_l, chow_r, hsret: {})
    chow_r.channels.each do |ea_cha|
      ea_cha.channel_owner = chow_l
      if ea_cha.valid?
        # Case 4-1-2-1
        ea_cha.save!
        hsret[:channel][:remained] << ea_cha
      else
        # Case 4-1-2-2
        _merge_channel_owners_with_artist_merge_channels(chow_l.channels, ea_cha, hsret: hsret)  # hsret is modified; one of Channel(L) is added to :remained
      end
    end
    hsret
  end
  private :_merge_channel_owners_with_artist_with_channels

  # Case 4-1-2-2 in _merge_channel_owners
  #
  # 1. Two ChannelOwners exist for both Artists to merge
  # 2. ChannelOwner with Artist-to-merge should (at least) remain
  # 3. The other ChannelOwner have_many (significant) Channels
  # 4. The other ChannelOwner cannot accept Artist to associate (presumanbly) due to unique constraints
  # 5. The other ChannelOwner cannot accept Artist to associate (presumanbly) due to unique constraints
  #
  # Therefore, the other ChannelOwner has to be merged to the remaining ChannelOwner
  # where its contents (specifically, note only) AND the associated HaramiVid-s
  # must be updated appropriately.
  #
  # @param chan_to_cands [Channel::Relation]
  # @param chan_from [Channel]
  # @param hsret: [Hash] to modify and return
  # @return [Hash<Array<ArtistMusicPlay>>, NilClass] nil only if self is not Artist; else {channel_owner: {remained: [ChannelOwner], destroy: [ChannelOwner]}, channel: {...}, harami_vid: {...}} (up to 1 element each for channel_owner and potentially many for the others; no destroy for harami_vid)
  def _merge_channel_owners_with_artist_merge_channels(chan_to_cands, chan_from, hsret: {})
    # Case 4-1-2-2
    chan_to = chan_to_cands.find_by(chan_from.attributes.slice(*%w(channel_type_id channel_platform_id channel_owner_id)))
    raise "Equivalent Channel for #{chan_from.inspect} is not found despite it is invalid. Strange. Contact the code developer." if !chan_to
    _append_note!(chan_to, chan_from)  # merge notes
    chan_from.harami_vids.each do |ehvid|
      # Case 4-1-2-2-2
      ehvid.update!(channel: chan_to)
    end
    chan_from.harami_vids.reset
    chan_from.destroy!   ## delegation of deletion to the later process may not work well, because otherwise you cannot update another existing Channel, violating a unique constraint!
    hsret[:channel][:remained] << chan_to
    hsret[:channel][:destroy]  << chan_from
    hsret
  end
  private :_merge_channel_owners_with_artist_merge_channels

  # Adjust model parameters in merging to get the best of both worlds
  #
  # @example for model based on self
  #    _adjust_prms_according_priority(engage, other_music, %w(artist_id music_id engage_how), "music_id", %w(contribution), priority: :self 
  #
  # @example for model based on other where :self has the original priority for the method
  #    _adjust_prms_according_priority(engage, self_music, %w(artist_id music_id engage_how), "music_id", %w(contribution), priority: :other
  #
  # @param model [ActiveRecord] model to deal with (like an association model Engage)
  # @param other [BaseWithTranslation] Other model corresponding to self (like Artist)
  # @param allcols [Array<String>] All unique column names to identify the other model
  # @param mykeyid [String] "*_id" for the model so that {mykey_id => other.id} would characterize the DB query.
  # @param cols [Array<String>] columns to possibly update, loading values from other model
  # @param cols, priority: :self)
  # @param cols, priority: :self)
  # @return [ActiveRecord] of the given model
  def _adjust_prms_according_priority(model, other, allcols, mykeyid, cols, priority: :self)
    hstmp = model.attributes.slice(*allcols)
    hstmp[mykeyid] = other.id
    counterpart = model.class.find_by(hstmp)
    cols.map(&:to_s).each do |ecol|
      if ((:self  == priority) && model.send(ecol).blank? && !(val=counterpart.send(ecol)).blank?) ||
         ((:other == priority) && !counterpart.send(ecol).blank?)
        model.send(ecol+"=", counterpart.send(ecol))
      end
    end

    ar = [model, counterpart]
    ar.reverse! if :other == priority
    _append_note!(*ar)

    model.save!
    model
  end
  private :_adjust_prms_according_priority

  # merging ArtistMusicPlay
  #
  # Many ArtistMusicPlay may be updated in DB.
  # However, this does not destroy ArtistMusicPlay to discard. To do that,
  # They should be cascade-deleted when a Artist/Music is destroyed.
  # If you want to do it explicitly, do:
  #
  #   hs = _merge_artist_music_plays(other, priority: :self)
  #   hs[:destroy].each do |em|
  #     em.destroy
  #   end
  #
  # @param other [BaseWithTranslation] of the same class as self. This method makes sense only for Music and HaramiVid
  # @param priority: [Symbol] (:self(Def)|:other)
  # @return [Hash<Array<ArtistMusicPlay>>, NilClass] nil only if it is not Artist/Music; else {remained: [ArtistMusicPlay...], destroy: [...]}
  def _merge_artist_music_plays(other, priority: :self)
    return if !respond_to?(:artist_music_plays)
    raise "Should not happen. Contact the code developer." if !other.respond_to?(:artist_music_plays)

    allcols = ArtistMusicPlay.reflect_on_all_associations(:belongs_to).map(&:foreign_key)
    mykeyid = (mykey=self.class.name.underscore)+"_id"
    unicols = allcols - [mykeyid]  # columns except for self (like music_id) for use of identifying the counterpart
    return if !allcols.include? mykeyid  # self (nor other) is not one of the five Classes of ArtistMusicPlay belongs_to

    hsret = {remained: [], destroy: []}.with_indifferent_access

    amps         = [self, other].map{|emdl| [emdl, emdl.artist_music_plays]}.to_h
    amps_unicol_ids = [self, other].map{|emdl| [emdl, emdl.artist_music_plays.pluck("artist_music_plays.id", *unicols).map{|i| [i[0], i[1..-1]]}]}.to_h
    # {self => [[14, [123,456,789,101]], [15, [...]]], other => [...]}   # [ID, [four-element ID Arrays]
    amps_unicol_id_onlys = amps_unicol_ids.map{|ek, ea| [ek, ea.map(&:last)]}.to_h
    # {self => [     [123,456,789,101],  [...]], other => [...]}   # [[four-element ID Arrays], ...]
    amps_ors = amps_unicol_ids[self] + amps_unicol_ids[other]
    amps_and_ids = amps_ors.select{|ear| [self, other].all?{|emdl| amps_unicol_id_onlys[emdl].include?(ear[1])}}.map(&:first)  # AMP IDs only
#print "DEBUG:honb810:and:";p amps_and_ids
    amps_xor_ids = amps_ors.select{|ear| amps_unicol_id_onlys[self].include?(ear[1]) ^ amps_unicol_id_onlys[other].include?(ear[1])}.map(&:first)
#print "DEBUG:honb811:xor:";p amps_xor_ids
    cols = %w(contribution_artist cover_ratio)

    (amps[self] | amps[other]).each do |emdl|
      case emdl.send(mykey)
      when self
        hsret[:remained] << 
          if amps_xor_ids.include? emdl.id
            emdl
          else
            _adjust_prms_according_priority(emdl, other, allcols, mykeyid, cols, priority: priority)
          end
      when other
        if amps_and_ids.include? emdl.id
          hsret[:destroy] << emdl  # duplicated model, will be cascade-destroyed.
          next 
        end

        emdl.send(mykey+"=", self)  # belongs_to (e.g., music_id) is now updated to self (Music etc)
        emdl.save!
        hsret[:remained] << emdl
      else
        raise
      end
    end # (amps[self] | amps[other]).each do |emdl|

    self.artist_music_plays.reset  # Essential!
    hsret
  end
  private :_merge_artist_music_plays

  # merging HaramiVidMusicAssoc
  #
  # Many HaramiVidMusicAssoc may be updated in DB.
  # However, this does not destroy HaramiVidMusicAssoc to discard. To do that,
  # They should be cascade-deleted when a Music/HaramiVid is destroyed.
  # If you want to do it explicitly, do:
  #
  #   hs = _merge_harami_vid_music_assocs(other, priority: :self)
  #   hs[:destroy].each do |em|
  #     em.destroy
  #   end
  #
  # @param other [BaseWithTranslation] of the same class as self. This method makes sense only for Music and HaramiVid
  # @param priority: [Symbol] (:self(Def)|:other)
  # @return [Hash<Array<HaramiVidMusicAssoc>>, NilClass] nil only if it is not Music/HaramiVid; else {remained: [HaramiVidMusicAssoc...], destroy: [...]}
  def _merge_harami_vid_music_assocs(other, priority: :self)
    return if !respond_to?(:harami_vid_music_assocs)
    raise "Should not happen Contact the code developer." if !other.respond_to?(:harami_vid_music_assocs)
    all_hvmas = []
    remains = _prioritized_models(other, priority, __method__).map{ |emdl|
      all_hvmas.push emdl.harami_vid_music_assocs
      all_hvmas[-1].map{ |hvma|
        is_music = !respond_to?(:musics)
        hsprm = (is_music ? {harami_vid: hvma.harami_vid, music: self} : {harami_vid: self, music: hvma.music})
        mdl = (HaramiVidMusicAssoc.where(hsprm).first || hvma)
        if is_music 
          mdl.music      = self
        else
          mdl.harami_vid = self
        end
        mdl.flag_collab ||= hvma.flag_collab
        mdl.completeness = hvma.completeness if !mdl.completeness || mdl.completeness <= 0
        mdl.timing       = hvma.timing       if !mdl.timing       || mdl.timing <= 0
        _append_note!(mdl, hvma)
        mdl.created_at = _older_created_at(mdl, hvma)

        mdl.save!
        mdl
      }
    }.flatten.uniq
    to_destroys = all_hvmas.flatten.uniq.select{|mdl| !remains.include?(mdl) }
    {remained: remains, destroy: to_destroys}.with_indifferent_access
  end
  private :_merge_harami_vid_music_assocs

  # Update/Create {Harami1129Review} after merging Artist/Music
  #
  # Entries of {Harami1129Review} are added/updated for an updated Artist/Music title
  # from original ins_singer|song through merging Artists/Musics.  Only one entry
  # is created for a combination of (ins_singer|song and {Engage})
  #
  # == Algorithm
  #
  # For each "remaining" Engage, compare the updated {Translation}-s of the same class
  # of self (either Artist or Music, i.e., {Engage#artist} etc) and
  # the corresponding ins_* value of {Harami1129} of which {Harami1129#engage}
  # points to the Engage:
  #   Harami1129.engage.artist.translations  # <=>
  #   Harami1129.ins_singer
  #
  # If there is a discrepancy, a new row of {Harami1129Review} is added
  # or an existing row of it is updated with +checked+ = false
  #
  # Note that if +ins_singer+ corresponds to only one of the {Translation}-s,
  # it is regarded as "agree" and no new record is added to {Harami1129Review}.
  #
  # Note that "destroy" set of {Engage} needs not be considered, because the corresponding Harami1129's
  # +engage_id" should be already altered to point to one of the remaining Engage-s
  #
  # @param hsmodel [Hash<Hash<Array>,Array>] 
  # @param user: [ApplicationRecord, NilClass] current_user
  # @return [Hash<remained: Array<Harami1129>>] {Harami1129Review}-s that are created or updated
  def _update_harami1129_review_after_merge(hsmodel, user: nil)
    retary = []
    hs_already_updated = {}  # "ins_singer" => [Engage, Engage, ...]
    hsmodel[:engage][:remained].each do |ea_eng|
      ea_eng.harami1129s.each do |h1129| 
        ins_colname = Harami1129.model2harami1129_colname(self, ins: true)  # Either "ins_singer" or "ins_song"
        hs_already_updated[ins_colname] = [] if !hs_already_updated.key?(ins_colname)  # initialization
        next if hs_already_updated[ins_colname].include? ea_eng  # Already at least one entry is listed in Harami1129Review for this ins_column and Engage

        ins_val = h1129.send(ins_colname)  # Value of ins_singer or ins_song
        art_or_mus = h1129.engage.send(self.class.table_name.singularize)   # Artist or Music record of Engage
        next if art_or_mus.translations.pluck(:title, :alt_title).flatten.compact.uniq.include?(ins_val)  # H1129's ins_song is still found in one of Engage's Music's translations?

        h_rev = Harami1129Review.find_or_create_by(harami1129: h1129, harami1129_col_name: ins_colname)

        h_rev.harami1129_col_val = ins_val
        h_rev.engage = ea_eng
        h_rev.checked = false  # If the record exists, its checked is updated with false.
        if h_rev.changed? 
          h_rev.user = user  # user_id updated only when something else has changed.
          retary.push h_rev 
        end
        h_rev.save!

        hs_already_updated[ins_colname].push ea_eng  # Logged that the combination (ins_COLUMN and Engage) was recorded for at least one Harami1129
      end
    end
    {remained: retary, destroy: []}
  end
  private :_update_harami1129_review_after_merge

  # Older one is adopted
  #
  # @param other [BaseWithTranslation] of the same class as self
  # @return [DateTime] 
  def _merge_created_at(other)
    self.created_at = _older_created_at(self, other)
  end
  private :_merge_created_at

  # Returns the older created_at
  #
  # @param mdl   [BaseWithTranslation]
  # @param other [BaseWithTranslation] of the same class as mdl
  # @return [DateTime] 
  def _older_created_at(mdl, other)
    [mdl, other].map(&:created_at).min
  end
  private :_older_created_at

  # Returns ordered models according to the given priority
  #
  # @example
  #    _prioritized_models(other, priority, __method__)
  #
  # @param other [BaseWithTranslation] of the same class as self
  # @param priority [Symbol] (:self(Def)|:other)
  # @param caller_method [String] Caller's name for error output
  # @return [Array<BaseWithTranslation>] [self, other] or [other, self]
  def _prioritized_models(other, priority, caller_method)
    #raise "(#{caller_method}) Wrong other (#{other.inspect}). Contact the code developer." if self.class != other.class
    raise "(#{caller_method}) Wrong priority (#{priority.inspect}). Contact the code developer." if ![:self, :other].include?(priority)
    return ((:other == priority) ? [other, self] : [self, other])
  end


  # Assign a Translation to self, which belonged to another.
  #
  # @param tra_other [Translation]
  # @param priority: [Symbol] :highest, :high (Def), :low, :lowest in assigning a new weight
  #          :highest and :lowest guarantee the new weight will be highest/lowest, respectively.
  #          :high and :low means unless there is a collision in weight, you leave it.
  # @param force: [Symbol] if true (Def: false), the given tra_other has a higher priority than others (like is_orig==true).
  #     Else, if the first attempt to save tra_other fails, tra_other is destroyed.
  # @return [Hash<Array<Engage>>, NilClass] nil only if it is not Music/Artist; else {remain: [Engage...], destroy: [...]}
  def _reassign_translation(tra_other, priority: :high, force: false)
    destroyed_first = []
    tra_other.translatable_id = self.id
    tra_other.weight = get_unique_weight(tra_other, priority: priority, to_destroy: destroyed_first)

    # destroyed_first was set above only when they have to be destroyed before self.save!
    destroyed_first.each do |et|
      et.destroy
    end

    if tra_other.valid?
      tra_other.save!  # may raise an Error, if validation misses a DB-level validation and if it fails at DB.
      return {remained: [tra_other], destroy: destroyed_first}
    end

    if !force
      # tra_other.destroy  # Destroy tra_other  --- it will be cascade-destroyed.
      return {remained: [], destroy: destroyed_first+[tra_other]}
    end

    # Now, Translation validation has failed maybe because, such as, a (title, alt_title) combination already exists.
    logger.info "(#{__FILE__}:#{__method__}) Handling a rare case of translaiton validation failure during merging due to similar ones: other-other=#{tra_other.inspect} self.translations=#{translations.inspect}"

    destroyed = []
    translations.where(langcode: tra_other.langcode).each do |etra|
      # Destroy self.translations with the same langcode one by one. When the "tra_orig" to save becomes valid, do it.
      # NOTE: Some Translations that are unrelated to the validation failure may be destroyed.
      #   However, given this situation rarely happens anyway, I ignore the downsides.
      #   I note, as for the original language, it is debatable whether you allow multiple Translation-s,
      #   because you may as well delete all of them except for the best one.
      destroyed.push etra
      etra.destroy  # Destroy one of self.translations
      if tra_other.valid?
        tra_other.save!  # may raise an Error, if validation misses a DB-level validation and if it fails at DB.
        return {remained: [tra_other], destroy: destroyed_first+destroyed}
      end
    end
    logger.error "ERROR: (#{__FILE__}:#{__method__}) tra_other=#{tra_other.inspect} self.translations=#{translations.inspect}"
    raise "Contact the code developer (translation reassigment error)."
  end
  private :_reassign_translation

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
  # A child class of this base class may define a callback
  #     fallback_non_existent_unsaved_translations
  # (which can be a private method.)
  #
  # If it is defined and if @unsaved_translations is blank,
  # the callback is invoked, perhaps for the purpose of making sure
  # a Translation is created when a model is created.
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

    # This should be redundant as self.translations for new_record (but changed)
    # should always return an empty relation [].
    translations.each do |ea_t|
      ea_t.save! if ea_t.new_record? || ea_t.changed?
    end

    if @unsaved_translations.blank?
      if respond_to?(:fallback_non_existent_unsaved_translations)
        fallback_non_existent_unsaved_translations
      end
      return
    end

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

    @unsaved_translations.reverse!
    @unsaved_translations.reverse.each do |translation|
      translation.save!
      @unsaved_translations.pop
    end
  end

  # Validates translation immediately before it is saved/updated.
  #
  # Validation of {Translation} fails if any of to-be-saved
  # title and alt_title matches an existing title or alt_title
  # of any {Translation} belonging to the same {Translation#translatable} class.
  #
  # == Usage
  #
  # In a model (a child of BaseWithTranslation), define a public method:
  #
  #   def validate_translation_callback(record)
  #     validate_translation_neither_title_nor_alt_exist(record)
  #   end
  #
  # @param record [Translation]
  # @return [Array] of Error messages, or empty Array if everything passes
  def validate_translation_neither_title_nor_alt_exist(record)
    msg = msg_validate_double_nulls(record) # defined in app/models/concerns/translatable.rb
    return [msg] if msg

    tit     = record.title
    alt_tit = record.alt_title
    tit     = nil if tit.blank?
    alt_tit = nil if alt_tit.blank?

    options = {}
    options[:langcode] = record.langcode if record.langcode

    wherecond = []
    wherecond.push ['id != ?', record.id] if record.id  # All the Translation of Country but the one for self (except in create)
    vars = ([tit]*2+[alt_tit]*2).compact
    sql = 
      if vars.size == 4
        '((title = ?) OR (alt_title = ?) OR (title = ?) OR (alt_title = ?))'
      else
        '((title = ?) OR (alt_title = ?))'
      end
    wherecond.push [sql, *vars]

    alltrans = self.class.select_translations_regex(nil, nil, where: wherecond, **options)

    if !alltrans.empty?
      tra = alltrans.first
      msg = sprintf("%s=(%s) (%s) already exists in %s [(%s, %s)(ID=%d)] for %s(ID=%d)",
                    'title|alt_title',
                    [tit, alt_tit].compact.map{|i| single_quoted_or_str_nil i}.join("|"),
                    single_quoted_or_str_nil(record.langcode),
                    record.class.name,
                    tra.title,
                    tra.alt_title,
                    tra.id,
                    self.class.name,
                    tra.translatable_id
                   )
      return [msg]
    end
    return []
  end

  # Utility for Callback/hook to validate translation immediately before it is added.
  #
  # Call this inside the validation callback that is called in validation by {Translation}
  #
  # In short, this validation means:
  # if {Translation#title} (or {Translation#alt_tiele} if title is nil)
  # is not unique within the same parent, it is not valid.
  #
  # Note: {Translation}.joins(:translatable) would lead to ActiveRecord::EagerLoadPolymorphicError
  #  as of Ruby 6.0.
  #
  # @example for model Place
  #   class Place
  #     def validate_translation_callback(record)
  #       validate_translation_unique_within_parent(record)
  #     end
  #   end
  #
  # @param record [Translation]
  # @param parent_klass: [BaseWithTranslation, NilClass] parent class that self belongs_to. Unless self has multiple parents, this can be guessed.
  # @return [Array] of Error messages, or empty Array if everything passes
  def validate_translation_unique_within_parent(record, parent_klass: nil)
    msg = msg_validate_double_nulls(record)
    return [msg] if msg

    ### To achieve with a single SQL query, the following is the one (for Prefecture)??
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

    my_tblname = self.class.table_name
    parent_klass ||= self.class.reflect_on_all_associations(:belongs_to).map{|i| i.klass.name}[0].constantize
    # If self.class has multiple belongs_to, the guessed class may be wrong (the Array has more than one element).

    parent_col = parent_klass.table_name.singularize + "_id"

    # Gets all the Translation of this class belonging to the same parent class except oneself.
    joinscond = "INNER JOIN #{my_tblname} ON translations.translatable_id = #{my_tblname}.id"
    whereconds = []
    whereconds << [my_tblname+"."+parent_col+" = ?", record.translatable.send(parent_col)]
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
      parent_obj = record.translatable.send(parent_klass.table_name.singularize)
      msg = sprintf("%s=%s (%s) already exists in %s for %s in %s (%s).",
                    method.to_s,
                    current.inspect,
                    record.langcode,
                    record.class.name,
                    self.class.name,
                    parent_klass.class.name,  # == parent_klass.name
                    (parent_obj.titles.compact[0].inspect rescue '"No titles"')
                   )
      return [msg]
    end
    return []
  end

  ######################## Validations #######################

  # on-create validation re Translation which some models may use
  # 
  # Some child models may require `@unsaved_translations` exist in save.
  # If so, define this method for an on-create validation callback as:
  # 
  #   validate :valid_present_unsaved_translations, on: :create  # @unsaved_translations must be defined and valid. / defined in BaseWithTranslation
  # 
  # @note Do not change the messesages!  They are referred to from /db/seeds/common.rb
  # 
  def valid_present_unsaved_translations  # @unsaved_translations must be defined and valid.
    def _unsaved_trans_valid?(tras=unsaved_translations)
      (tra=tras.first).valid?
      msgs = tra.errors.full_messages
      # An error of "Translatable can't be blank." is expected.
      msgs.reject{|i| /\btranslatable/i =~ i}.empty?
    end

    return if !new_record?
    if !unsaved_translations.empty?
      errors.add :base, "one of (unsaved)_translations is invalid" if !_unsaved_trans_valid?
    end

    translations.each do |et|
      errors.add :base, "one of (unsaved) translations is invalid" if !et.valid?
    end
    errors.add :base, "no translations are defined" if unsaved_translations.empty? && !translations.exists?
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

class << BaseWithTranslation
  alias_method :create_basic_application_original!, :create_basic! if !self.method_defined?(:create_basic_application_original!)
  alias_method :initialize_basic_application_original, :initialize_basic if !self.method_defined?(:initialize_basic_application_original!)

  # Modifies {ApplicationRecord.create_basic!} to automatically add a unique translation
  #
  # Original is defined in /app/models/concerns/module_application_base.rb
  #
  # @example In case you need to overwrite it (see also the bottom section of BaseWithTranslation).
  #    class << Artist
  #      alias_method :create_basic_bwt!, :create_basic! if !self.method_defined?(:create_basic_bwt!)
  #      def create_basic!(*args, sex: nil, sex_id: nil, **kwds, &blok)
  #        sex_id ||= (sex ? sex.id : Sex.create_basic!.id)
  #        create_basic_bwt!(*args, sex_id: sex_id, **kwds, &blok)
  #      end
  #    end
  #
  #    record = Artist.create_basic!  # => ok.
  #
  # @param translation: [Translation, Nilclass] if given, this (unsaved) Translation is used instead.
  #    You can give an existing Translation as long as it belongs to a different parent class
  #    (if it belongs to the same class, it is likely to raise a unique-violation-related Exception).
  def create_basic!(*args, translation: nil, **kwds, &blok)
    model = create_basic_application_original!(*args, **kwds, &blok)
    model.reload
    if model.translations.exists?
      model
    else
      if translation
        translation.translatable = nil
        model.translations << translation
      else
        model.with_translation(**_prepare_hash_basic_translation(translation))
      end
      model
    end
  end

  # Initialize version.
  #
  # @note Other related models are not likely to be created, but existing ones should be used.
  def initialize_basic(*args, translation: nil, **kwds, &blok)
    model = super(*args, **kwds, &blok)
    if model.unsaved_translations.empty? && model.instance_variable_get(:@title).blank? && model.instance_variable_get(:@langcode).blank?
      model.unsaved_translations << Translation.new(_prepare_hash_basic_translation(translation))
    end
    model
  end

  private
  def _prepare_hash_basic_translation(translation)
    if translation 
      translation.attributes.except(*(%w(id translatable_type translatable_id created_at updated_at)))
    else
      {langcode: "en", title: name+"-basic-"+rand(0.429).to_s, is_orig: true, weight: 1000}
    end
  end
end

