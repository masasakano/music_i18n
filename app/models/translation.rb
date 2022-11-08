# -*- coding: utf-8 -*-

# == Schema Information
#
# Table name: translations
#
#  id                :bigint           not null, primary key
#  alt_romaji        :text
#  alt_ruby          :text
#  alt_title         :text
#  is_orig           :boolean
#  langcode          :string           not null
#  note              :text
#  romaji            :text
#  ruby              :text
#  title             :text
#  translatable_type :string           not null
#  weight            :float
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  create_user_id    :bigint
#  translatable_id   :bigint           not null
#  update_user_id    :bigint
#
# Indexes
#
#  index_translations_on_9_cols                                 (translatable_id,translatable_type,langcode,title,alt_title,ruby,alt_ruby,romaji,alt_romaji) UNIQUE
#  index_translations_on_create_user_id                         (create_user_id)
#  index_translations_on_create_user_id_and_update_user_id      (create_user_id,update_user_id)
#  index_translations_on_translatable_type_and_translatable_id  (translatable_type,translatable_id)
#  index_translations_on_update_user_id                         (update_user_id)
#
# Foreign Keys
#
#  fk_rails_...  (create_user_id => users.id)
#  fk_rails_...  (update_user_id => users.id)
#
class Translation < ApplicationRecord
  extend ModuleCommon
  using ModuleHashExtra  # for extra methods, e.g., Hash#values_blank_to_nil

  before_validation :move_articles_to_tail
  after_validation  :revert_articles
  before_save       :move_articles_to_tail
  before_create     :set_create_user
  before_save       :set_update_user
  after_save        :reset_backup_6params  # to reset the temporary instance variable

  #after_create :set_create_user
  after_create :call_after_first_translation_hook
  #after_update :set_update_user

  belongs_to :translatable, polymorphic: true
  belongs_to :create_user, class_name: "User", foreign_key: "create_user_id", optional: true
  belongs_to :update_user, class_name: "User", foreign_key: "update_user_id", required: false

  class OneSignificanceValidator < ActiveModel::Validator
    def validate(record)
      if options[:fields].all?{|field| record.send(field).blank? }
        record.errors.add :base, "One of the columns must be non-blank: #{options[:fields].map{|i| [i, record.send(i)]}.to_h.inspect}"
      end
    end
  end

  class UniqueCombiValidator < ActiveModel::Validator
    # Unless both title and alt_title are nil, the pair should be unique within the same Parent object and language.
    #
    # Cases:
    #
    # (1) BAD if ((Either new.(title||alt_title) exists in Either new.(title||alt_title)) in the entire translatable class (e.g., Country)
    # (2) BAD if ((Either new.(title||alt_title) exists in Either new.(title||alt_title)) except blank
    # (3) BAD if ((new.title exists in titles) && (either(new.alt_title || existing alt_titles).blank?)
    # (4) BAD if ((new.title exists in titles) && (new.alt_title exists in alt_titles))
    # (5) others: e.g., BAD if in Music, (2) and if Composer-Artist and Year exist.
    #
    # This somehow validates as long as translatable_type is significant even if
    # translatable_id is not.
    #
    def validate(record)
      # return if !record.translatable_type || !record.translatable_id

      hs2pass = %i(title alt_title langcode translatable_type translatable_id).map{|i| [i, record.send(i)]}.to_h
      cmped = hs2pass.values_at(:title, :alt_title)
      if !cmped.compact.empty?
        rel = record.class.where(hs2pass)
        rel = rel.where.not(id: record.id) unless record.new_record?  # For update
        if rel.count > 0
          record.errors.add :base, "Combination of (title, alt_title) must be unique: #{cmped.inspect}" # i.e., no two identical translations should associate a single entity.
        end
      end

      ## Custom callback of the parent
      parent = (record.translatable || (record.translatable_type.constantize rescue nil)) # This returns either a model OR for a new record, a model class.  For the latter, validate_translation_callback must be defined as a class method in the model class to be executed.
      #if parent.respond_to? :validate_translation_for_new_base_callback
      #  # for new record, defined in base_with_translation.rb
      #  parent.validate_translation_for_new_base_callback(record)
      #end

      if parent.respond_to? :validate_translation_callback
        [parent.validate_translation_callback(record)].flatten.compact.each do |msg|
          record.errors.add :base, msg
        end
      end
    end
  end

  # Column names (Symbols) of the translation String
  TRANSLATED_KEYS = %i(title alt_title ruby alt_ruby romaji alt_romaji)

  # Column names (Symbols) of the translation String
  TRANSLATION_PARAM_KEYS = %i(langcode is_orig) + TRANSLATED_KEYS

  # Match method lists. Usually examined in this order.
  # For example, if there is an exact match, :exact.
  # Note the DB converts "The Beatles" into "Beatles, The" when save.
  # For this reason, ":exact" accepts both the forms of the article:
  # prefixed ("The Beatles") and postfixed ("Beatles, The"),
  # whereas :exact_absolute is the most simple DB search.
  #
  # * :exact_absolute / Absolute exact match / Not included here so it won't be processed in default.
  # * :exact / Exact match
  # * :exact_ilike / Case-insensitive exact match
  # * :optional_article_ilike / Match if a definite-article is ignored (case-insensitive)
  # * :include / The string is a part of it
  # * :include_ilike / Same but case-insensitive
  MATCH_METHODS = [:exact, :exact_ilike, :optional_article_ilike, :include, :include_ilike]

  # All the accepted {Translation::MATCH_METHODS}
  ACCEPTED_MATCH_METHODS = [:exact_absolute] + MATCH_METHODS

  validates :title, uniqueness: { scope: [:alt_title, :ruby, :alt_ruby, :romaji, :alt_romaji, :langcode, :translatable_type, :translatable_id] }
  # NOTE: PostgreSQL does not validate the values when one of any values (whether
  #   existing or new) is null.  But Rails does.

  validate :asian_char_validator
  validates_with OneSignificanceValidator, fields: TRANSLATED_KEYS
  validates_with UniqueCombiValidator

  # The attribute (e.g., :alt_title) that has the value of the matched String,
  # set by {Translation.find_by_regex}, or manually with {#set_matched_attribute}.
  attr_accessor :matched_attribute

  # Confidence level (Symbol) when matched to find a {Translation}.
  # See {Translation::MATCH_METHODS}
  attr_accessor :match_method

  # [Hash] Options to pass to {SlimString.slim_string} in a callback
  # and {#preprocess_6params} etc.
  attr_accessor :slim_opts

  # Skip move_articles_to_tail (before_validation and before_save) callbacks,
  # meaning the 6 columns like "title" are saved as they are.
  attr_accessor :skip_preprocess_callback

  # Returns true if the current user is allowed to edit self.
  #
  # Creator of the entry can edit it.
  # Translation Moderator can edit it.
  # No other users can edit it except for the following edge case.
  #
  # == the edge case
  #
  # If the user "can" edit {Translation#translatable} (namely, a moderator) AND
  # if the language of self is non-nil and agrees with the original language
  # (which means self is most likely to be the only one) or if both are nil
  # (meaning there is no default language) and the current language is 'ja',
  # returns true.
  #
  # For example, supposer a JA-editor creates a new Genre; is_orig is
  # not defined in this case. While another JA-editor is prohibited to edit it
  # in any way, a JA-moderator can edit its Japanese translation, while s/he
  # cannot edit its English translation (unless s/he is a Translation moderator).
  #
  # @param user: [User]
  def editable?(user:)
    return false if !user
    rc_tra = RoleCategory[RoleCategory::MNAME_TRANSLATION]
    return true if user.qualified_as? :moderator, rc_tra
    cuser = create_user
    return true if cuser == user

    # Edge case
    olc = original_langcode
    return true if olc == langcode && (olc || langcode.to_s == 'ja') && translatable && Ability.new(user).can?(:edit, translatable)

    false
  end

  # Returns true if a user can create another Translation for self
  #
  # Creator of the entry can create one.
  # Translation Editor can create one.
  # No other users can create one except for the following edge cases.
  #
  # == the two edge cases
  #
  # If the user "can" create an instance of {Translation#translatable}.class
  # and the given langcode is 'ja', s/he can create one.
  #
  # If the user already has created a {Translation} of the same {#langcode}
  # for the {Translation#translatable}, s/he can create another one.
  #
  # @param user: [User]
  # @param langcode: [String, Symbol] like 'ja'
  def creatable_other?(user:, langcode: self.langcode)
    lc = langcode.to_s  # NOTE: whereas self.langcode is a DB entry, this langcode is the given argument!
    return false if !user
    rc_tra = RoleCategory[RoleCategory::MNAME_TRANSLATION]
    return true if user.qualified_as? :editor, rc_tra

    # Edge cases
    olc = original_langcode
    return true if lc == 'ja' && translatable && Ability.new(user).can?(:create, translatable.class)
    return true if siblings(lc).pluck(:create_user_id).include? user.id
    false
  end

  # Sort based on {#is_orig} and {#weight}
  #
  # Tries to use the DB.  But in failing, Array is returned.
  #
  # @return [ActiveRecord::AssociationRelation, Array]
  def self.sort(rela)
    begin
      rela.order(Arel.sql('CASE WHEN is_orig IS NULL THEN 1 ELSE 0 END, is_orig DESC')).order(Arel.sql('CASE WHEN weight IS NULL THEN 1 ELSE 0 END, weight'))  # regardless of DBs; cf. https://stackoverflow.com/a/68698547/3577922
    rescue NoMethodError
      rela.sort
    end
  end


  # The matched String by {Translation.find_by_regex}.
  #
  # This returns the matched String held by self.
  #
  # It should be automatically set in a search conducted by {Translation.find_by_regex}.
  # However, if the search was run by {Translation.select_regex},
  # you must set it by yourself, specifying kwd and value in this method
  # as the same values used for {Translation.select_regex}.
  #
  # @param kwd [Symbol, String, Array<String>, NilClass] (title|alt_title|ruby|alt_ruby|romaji|alt_romaji|titles|all)
  #    or Array of Symbol|String to evaluate. Note :titles is the alias
  #    for [:title, :alt_title], and :all means all the 6 columns.
  #    If nil, this parameter, as well as value, is not used.
  # @param value [Regexp, String, NilClass] e.g., 'male' and /male\z/
  # @param att: [Symbol, NilClass] e.g., :alt_title. Usually read from @matched_attribute or generated from kwd and value, but you can specify it explicitly.
  # @return [String, NilClass] nil if not found
  def matched_string(kwd=nil, value=nil, att: nil)
    att ||= matched_attribute
    if !att
      raise MultiTranslationError::AmbiguousError, "(kwd, value) must be explicitly specified in #{self.class.name}##{__method__} because matched_attribute has not been defined. Note Translation was likely created by Translation.select_regex as opposed to by Translation.find_by_regex, which would set matched_attribute." if [kwd, value].compact.empty?
      att = get_matched_attribute(kwd, value)
    end

    att ? send(att) : nil
  end

  # Returns the parameter article_to_tail for {ModuleCommon#preprocess_space_zenkaku}.
  #
  # If the argument is TrueClass, a definite article
  # of the string of the caller's interst is moved to the tail. If it is false, it is not.
  # If it is a class of {BaseWithTranslation}, this method looks into
  # {BaseWithTranslation::ARTICLE_TO_TAIL}. If it is a String,
  # it should be like {Translation#translatable_type}, i.e.,
  # the model class name (e.g., {Artist}) that can be {#constantize}-d
  #
  # @param inobj [Boolean, Class, String] if Class, it should be BaseWithTranslation.
  #    If String, it should be {Translation#translatable_type}
  # @return [Boolean] true if the definite article in Title should be moved to the tail
  def self.get_article_to_tail(inobj)
    if inobj.respond_to?(:safe_constantize) && inobj.safe_constantize && inobj.safe_constantize.const_defined?(:ARTICLE_TO_TAIL)
      inobj.safe_constantize::ARTICLE_TO_TAIL
    elsif inobj.respond_to?(:const_defined?) && inobj.const_defined?(:ARTICLE_TO_TAIL)
      inobj::ARTICLE_TO_TAIL
    else
      case inobj
      when true, false, nil
        !!inobj
      else
        msg = "(#{__method__}) inobj is strange: "+inobj.inspect
        warn msg
        logger.warn msg
        false
      end
    end
  end

  # Instance method version of {Translation.get_article_to_tail}
  #
  # @param [Boolean, NilClass, Symbol] if Symbol, only :check is accepted, meaning automatic check (nil is the same)
  # @return [Boolean]
  def get_article_to_tail(article_to_tail)
    case article_to_tail
    when true, false
      article_to_tail
    when :check, nil
      return self.class.get_article_to_tail(translatable.class) if translatable     # pass BaseWithTranslation
      translatable_type ? self.class.get_article_to_tail(translatable_type) : false # pass BaseWithTranslation.name
    else
      false
    end
  end

  # Returns the Hash of 6 preprocessed parameters
  #
  # 6 parameters are title, alt_title, ruby, alt_ruby, romaji, alt_romaji,
  # though any other arbitrary parameters can be included.
  # The keys are as they receive: either Symbol or String.
  #
  # If article_to_tail is nil (Default) and if non-nil translatable or translatable_type
  # is included in opts, it is passed to {ModuleCommon#preprocess_space_zenkaku}.
  # Basically if it is true, a definite article in each word is,
  # if exists, moved to the tail. {Translation#translatable}.class should
  # have a constant {BaseWithTranslation::ARTICLE_TO_TAIL} to
  # determine the default value; however, at the time of this calling,
  # it is not defined and hence it is guessed from translatable_type
  # in opts, providing it is defined.
  #
  # Note that if {BaseWithTranslation::unsaved_translations} are defined,
  # for a new_record, {Translation}s will be saved automatically when
  # {BaseWithTranslation} is created, in which case translatable_type
  # is definitely defined. So, you may postpone the decision
  # instead of calling this method now?!
  #
  # @param article_to_tail [Boolean, NilClass, Symbol] If Symbol, it must be :check.
  #   If :check or nil, the value is "best"-guessed.
  #   It is passed to {ModuleCommon#preprocess_space_zenkaku}.
  # @param opts [Hash] as passed to new, create etc.
  # @return [Hash]
  def self.preprocessed_6params(article_to_tail=nil, **opts)
    article_to_tail = 
      case article_to_tail
      when true, false
        article_to_tail
      when nil, :check
        if (val = (opts[:translatable] || opts['translatable']))
          article_to_tail = get_article_to_tail val.class
        elsif  (val = (opts[:translatable_type] || opts['translatable_type']))
          article_to_tail = get_article_to_tail val
        end
      else
        msg = "(#{__method__}) article_to_tail is strange: "+article_to_tail.inspect
        warn msg
        logger.warn msg
        false
      end

    slim_opts = (opts[:slim_opts] || opts['slim_opts'] || {})

    newopts = {}.merge opts
    %i(title alt_title ruby alt_ruby romaji alt_romaji).each do |ek|
      [ek, ek.to_s].each do |k|
        newopts[k] = preprocess_space_zenkaku(opts[k], article_to_tail, **slim_opts) if opts.key?(k) && !opts[k].blank?
      end
    end
    newopts
  end
  private_class_method :preprocessed_6params

  # Returns 2-element Array where the 6 parameters are preprocessed.
  #
  # Wrapper of #{Translation.preprocessed_6params}
  #
  # In Rails new, create, update etc, the arguments can be either
  # a main argument of Hash or all optional parameters.
  # This method deals with both cases.
  #
  # @param *args [Array<Hash>] First and only argument can be Hash to pass to new/create
  #    as in Rails' convention.  In that case, no opts should be passed.
  # @param article_to_tail: [Boolean, NilClass, Symbol] as passed to {ModuleCommon#preprocess_space_zenkaku}.
  #   See {Translation.preprocessed_6params}
  # @return [Array<Array, Hash>]
  def self.preprocessed_6params_both(*args, article_to_tail: nil, **opts)
    ar = 
      if args.size == 1 && args[0].respond_to?(:each_pair)
        [preprocessed_6params(article_to_tail, **(args[0]))]
      else
        args
      end

    [ar, preprocessed_6params(article_to_tail, **opts)]
  end
  private_class_method :preprocessed_6params_both

  # The 6 parameters are preprocessed in self (not saved, though)
  #
  # Useful for {Translation.find_or_initialize_by} etc.
  #
  # @param article_to_tail: [Boolean, NilClass, Symbol] as passed to {ModuleCommon#preprocess_space_zenkaku}.
  #   See {Translation.preprocessed_6params}
  # @return [Hash] of the original values before_change for the values that have changed.
  def preprocess_6params(article_to_tail: :check)
    article_to_tail = get_article_to_tail(article_to_tail)
    reths = {}
    %w(title alt_title ruby alt_ruby romaji alt_romaji).each do |ek|
      val = send(ek)
      next if val.blank?

      newval = self.class.preprocess_space_zenkaku(val, article_to_tail, **(slim_opts || {}))
      next if newval == val

      send ek+'=', newval
      reths[ek]  = val
    end
    reths
  end

  # Alternative constructor, where the parameters are preprocessed
  #
  # Note that preprocessed_create() would be unnecessary
  # because before_save callback would be fired anyway.
  #
  # like zenkaku-hankaku conversions
  def self.preprocessed_new(*args, **opts)
    ar, newopts = preprocessed_6params_both(*args, **opts)
#print "DEBUG:p1:object_id=";p [newopts[:title].object_id, newopts[:title].preprocessed?]
    ret = self.new(*ar, **newopts)
#print "DEBUG:p2:object_id=";p [ret.title.object_id, ret.title.preprocessed?]
    ret
    #self.new(*ar, **newopts)
  end

  # Return true if the main argument parameters for {#create} is valid.
  #
  # That is, those except for {#translatable}.  In short,
  # the values for the keys of {#langcode} and either or both of {#title} and {#alt_title}
  # must be significant (non-blank after strip).
  #
  # @param in_hs_param [#to_h] Hash (or params) containing the keys like 'langcode' and 'title'
  # @param messages: [Array] an error message is Array#push-ed in returning false.
  def self.valid_main_params?(in_hs_param, messages: [])
    hs_param = in_hs_param.to_h.strip_strings.values_blank_to_nil.compact.with_sym_keys # defined in ModuleHashExtra
    # return false if ((/\A[a-z]{1,2}\z/ !~ hs_param[:langcode]) rescue false) # if langcode != (ja|en|fr) etc
    if ((/\A[a-z]{1,2}\z/ !~ hs_param[:langcode]) rescue false) # if langcode != (ja|en|fr) etc (or kr|de ...)
      messages.push "langcode (#{hs_param[:langcode]}) is none of (ja|en|fr)."
      return false
    end
    # return false if !(%i(title alt_title).any?{|i| hs_param.keys.include?(i)})
    if !(%i(title alt_title).any?{|i| hs_param.keys.include?(i)})
      messages.push 'At least either Title or AltTitle must exist.'
      return false
    end
    if hs_param[:title] == hs_param[:alt_title]
      messages.push 'Title and AltTitle must differ.'
      return false
    end
    true
  end

  # Wrapper of {Translation.valid_main_params?}
  def valid_main_params?(**kwd)
    self.class.send(__method__, slice(*(%i(langcode title alt_title))), **kwd)
  end


  # Find a {Translation} based on a String
  #
  # The matching methods are given in "accept_match_methods", whose default is
  # {Translation::MATCH_METHODS}, and it is processed in the order, i.e.,
  # as soon as a match is found, the process stops and returns the first result.
  # For convenience, you can specify the last method in "accept_match_methods"
  # with the "match_method_upto" option.
  #
  # {#match_method} and {#matched_attribute} attributes are set in the return,
  # and hence {#matched_string} can be used, too.
  #
  # @example success
  #   Translation.find_by_a_title(:titles, 'beatles',
  #     match_method_upto: :optional_article_ilike, translatable_type: Artist)
  #     # => Translation["Beatles, The"]
  #
  # @example failure
  #   Translation.find_by_a_title(:titles, 'beatles',
  #     match_method_upto: :exact_ilike, translatable_type: Artist)
  #     # => nil (because the argument lacks 'The')
  #
  # See {#Translatino.find_all_by_a_title} for the options.
  #
  # @param kwd [Symbol, String, Array<String>, NilClass] (title|alt_title|ruby|alt_ruby|romaji|alt_romaji|titles|all)
  #    or Array of Symbol|String to evaluate. Note :titles is the alias
  #    for [:title, :alt_title], and :all means all the 6 columns.
  #    If nil, this parameter, as well as value, is not used.
  # @param *args [Array]
  # @param **opts; [Hash] 
  # @return [Translation, NilClass] nil if not found
  #
  # @todo In the current algorithm, it assumes the search finds
  #   a matching String in most of the time. But if it is a fuzzy match,
  #   it runs SQL queries 5 or so times to finally confirm it, which is a waste.
  #   Binary search would be more efficient.
  #   In practice, though, it can be mitigated by the caller to specify
  #   both match_method_from and match_method_upto (maybe even the same one).
  def self.find_by_a_title(kwd, *args, **opts)
    rela = find_all_by_a_title(kwd, *args, **opts)

    ret = rela.first || return
    ret.set_matched_method_attribute(kwd, rela)
    ret
  end # def self.find_by_a_title(kwd, value, accept_match_methods: MATCH_METHODS, **restkeys)


  # Find all {Translation}-s based on a String that satisfies the condition
  #
  # More strictly, the most strict condition among the given conditions
  # with which one or more entries are found.
  #
  # For example, if no record is found with the most strict condition
  # but 3 records are found with the second most strict, (the relation
  # for) the 3 records are returned.
  #
  # The matching methods are given in "accept_match_methods", whose default is
  # {Translation::MATCH_METHODS}, and it is processed in the order, i.e.,
  # as soon as a match is found, the process stops and returns the first result.
  # For convenience, you can specify the last method in "accept_match_methods"
  # with the "match_method_upto" option.
  #
  # @example success
  #   Translation.find_all_by_a_title(:titles, 'xxxxxxxxxx', translatable_type: Artist).exists?
  #     # => false
  #
  # See also {#Translatino.find_by_a_title}
  #
  # @param kwd [Symbol, String, Array<String>, NilClass] (title|alt_title|ruby|alt_ruby|romaji|alt_romaji|titles|all)
  #    or Array of Symbol|String to evaluate. Note :titles is the alias
  #    for [:title, :alt_title], and :all means all the 6 columns.
  #    If nil, this parameter, as well as value, is not used.
  # @param value_in [Regexp, String, NilClass] e.g., 'male' and /male\z/
  # @param accept_match_methods: [Array<Symbol>] checks these match_method levels only.
  #    Default is {Translation::MATCH_METHODS}
  # @param match_method_from: [NilClass, Symbol] process from this in "accept_match_methods"
  #   If you do not care potential multiple matches, this will help the processing efficiency.
  # @param match_method_upto: [NilClass, Symbol] process up to this in "accept_match_methods"
  # @param where: [String, Array<String, Hash, Array>, NilClass] Rails where clause. See #{Translation.select_regex} for detail.
  # @param joins: [String, Array<String, Hash, Array>, NilClass] Rails joins clause. See #{Translation.select_regex} for detail.
  #    Example: to join {Engage} for the translatable {Music}
  #       joins: 'INNER JOIN engages ON translations.translatable_id = engages.music_id'
  # @param not_clause: [String, Array<String, Hash, Array>, NilClass] Rails not.where clause. See #{Translation.select_regex} for detail.
  # @param **restkeys: [Hash] Any other (exact) constraints to pass to {Translation}, including
  #    langcode: [String, NilClass] Optional argument, e.g., 'ja'. If nil, all languages.
  #    translatable_type: [Class, String] that is, the orresponding Class of the translation,
  #      which you most likely want to specify.
  #    translatable_id: [Integer, Array] To find a Translation for a particular object(s).
  # @return [Relation] an empty Relation if not found. If found, the singleton
  #    methods {#match_method}, value_searched and common_sql are defined
  #    for the returned Relation to allow the caller to access these values.
  #    Note that as an exception, if no methods are given, the returned value will be an empty Array.
  def self.find_all_by_a_title(kwd, value_in, accept_match_methods: MATCH_METHODS, match_method_from: nil, match_method_upto: nil, where: nil, joins: nil, not_clause: nil, **restkeys)
    i_from = (match_method_from ? accept_match_methods.find_index(match_method_from) : 0)
    i_last = (match_method_upto ? accept_match_methods.find_index(match_method_upto) : -1)
    if !i_from || !i_last
      raise ArgumentError, "(#{__method__}) Specified key(s) match_method_from=(#{match_method_from.inspect}), match_method_upto=(#{match_method_upto.inspect}) do not exist in accept_match_methods=#{accept_match_methods.inspect}"
    end
    accept_match_methods = accept_match_methods[i_from..i_last]
    value = preprocess_space_zenkaku value_in
    raise ArgumentError, "(#{__method__}) value=(#{value_in.inspect}) must be significant" if value.blank?
    allkeys = get_allkeys_for_select_regex(kwd)
    raise ArgumentError, "(#{__method__}) allkeys=(#{allkeys.inspect}) must be significant" if allkeys.empty?

    # Typically, :translatable_type and :langcode
    common_opts = init_common_opts_for_select(**restkeys)
    logger.warn "#{__method__}: translatable_type is blank..." if common_opts[:translatable_type].blank? && common_opts[:translatable].blank?
    common_sql =
      if common_opts.size > 0
        common_opts.map{|k, v|
          if k == :translatable
            v ? sprintf("translatable_type = '%s' AND translatable_id = %d", v.class.name, v.id) : nil
          elsif v.respond_to? :flatten
            v.empty? ? nil : sprintf("%s IN (%s)", k, v.join(", "))
          elsif v.respond_to? :infinite?
            sprintf "%s = %s", k, v
          elsif v.respond_to? :gsub
            sprintf "%s = '%s'", k, v.gsub(/'/, "''")
          else
            raise ArgumentError, "Optional argument (#{k.inspect}) is invalid."
          end
        }.compact.join(' AND ')
      else
        'TRUE'  # Dummy statement
      end

    res = []  # if no methods are given in the arguments, this will be returned.
    accept_match_methods.each do |method|
      res = build_sql_match(method, allkeys, value, common_sql, where: where, joins: joins, not_clause: not_clause)
      if res.exists?
        ret = sort(res)

        class << ret
          attr_accessor :match_method
          attr_accessor :value_searched
          attr_accessor :common_sql
        end
        ret.match_method   = method
        ret.value_searched = value
        ret.common_sql     = common_sql
        return ret
      end
    end

    res
  end


  # Build a SQL query for a combination of columns for a specific query method ("=", ILIKE, etc)
  #
  # @param method [Symbol] (:exact_absolute, :exact, :exact_ilike, :optional_article, :optional_article_ilike, :include, :include_ilike)
  # @param key [Symbol, String] (:title, :alt_title, :ruby, ...)
  # @param value [String] Title to query for. This has to be String.
  # @param common_sql [String] Common SQL query string
  # @param where: [String, Array<String, Hash, Array>, NilClass] Rails where clause. See #{Translation.select_regex} for detail.
  # @param joins: [String, Array<String, Hash, Array>, NilClass] Rails joins clause. See #{Translation.select_regex} for detail.
  # @param not_clause: [String, Array<String, Hash, Array>, NilClass] Rails not.where clause. See #{Translation.select_regex} for detail.
  # @return [ActiveRecord::QueryMethods::WhereChain] Resultant WHERE
  def self.build_sql_match(method, allkeys, value, common_sql, where: nil, joins: nil, not_clause: nil)
    ary = allkeys.map{|i| build_sql_match_one(method, i, value)}
    # self.where(common_sql + ' AND ('+ary.join(' OR ')+')')
    make_joins_where(where, joins, not_clause).where(common_sql + ' AND ('+ary.join(' OR ')+')')
  end
  private_class_method :build_sql_match

  # Build a SQL query for a specific column (:title, :romaji etc) for a specific query method ("=", ILIKE, etc)
  #
  # @param method [Symbol] (:exact_absolute, :exact_absolute, :exact, :exact_ilike, :optional_article, :optional_article_ilike, :include, :include_ilike)
  # @param key [Symbol, String] (:title, :alt_title, :ruby, ...)
  # @param value [String] Title to query for. This has to be String.
  # @return [String] Resultant SQL string to execute in WHERE
  def self.build_sql_match_one(method, key, value)
    tbl = table_name
    value = value.gsub(/'/, "''")
    case method
    when :exact_absolute
      sprintf("%s.%s = '%s'", tbl, key.to_s, value)
    when :exact
      sprintf("%s.%s = '%s'", tbl, key.to_s, definite_article_to_tail(value))
    when :exact_ilike
      sprintf("%s.%s ILIKE '%s'", tbl, key.to_s, definite_article_to_tail(value).gsub(/([%_])/, '\1'*2))
    when :optional_article, :optional_article_ilike, :include, :include_ilike
      re_core = regexp_ruby_to_postgres(ModuleCommon::DEFINITE_ARTICLES_REGEXP_STR)[0].gsub(/'/, "''") # defined in module_common.rb
      re_str = '(?i)(, ('+re_core+'))?$'
      s_stripped = definite_article_stripped(value).gsub(/([%_])/, '\1'*2)
      case method
      when :optional_article, :optional_article_ilike
        operator = ((method == :optional_article) ? 'LIKE' : 'ILIKE')
        sprintf("regexp_replace(%s.%s, '%s', '') %s '%s'",
              tbl,
              key.to_s,
              re_str,
              operator,
              s_stripped )
      when :include, :include_ilike
        # Strip definite articles from both the test and DB strings.
        operator = ((method == :include) ? 'LIKE' : 'ILIKE')
        sprintf("regexp_replace(%s.%s, '%s', '') %s '%%%s%%'",
              tbl,
              key.to_s,
              re_str,
              operator,
              s_stripped )
      end
    else
      raise
    end
  end
  private_class_method :build_sql_match_one

  # Utility method to set {#match_method} and {#matched_attribute}
  #
  # @param kwd [Symbol, String, Array<String>, NilClass] (title|alt_title|ruby|alt_ruby|romaji|alt_romaji|titles|all)
  #    or Array of Symbol|String to evaluate. Note :titles is the alias
  #    for [:title, :alt_title], and :all means all the 6 columns.
  #    If nil, this parameter, as well as value, is not used.
  # @param rela [Relation<Translation>]
  # @return [self]
  def set_matched_method_attribute(kwd, rela)
    self.match_method = rela.match_method
    allkeys = self.class.get_allkeys_for_select_regex(kwd)
    self.matched_attribute =
      if allkeys.size == 1
        allkeys[0]
      else
        self.class.find_matched_attribute_after_find_by_a_title(
          self.match_method,
          allkeys,
          rela.value_searched,
          rela.common_sql+" AND id = #{id}"
        )
      end
    self
  end

  # Returns the matched column name in Symbol
  #
  # This is called from an instance, too, hence public.
  #
  # Perfect algorithm though maybe overkill... (this executes SQL maybe multiple times.)
  #
  # @param method [Symbol] (:exact_absolute, :exact, :exact_ilike, :optional_article, :optional_article_ilike, :include, :include_ilike)
  # @param key [Symbol, String] (:title, :alt_title, :ruby, ...)
  # @param value [String] Title to query for. This has to be String.
  # @param common_sql [String] Common SQL query string
  # @return [Symbol]
  def self.find_matched_attribute_after_find_by_a_title(method, allkeys, value, common_sql)
    allkeys.each do |key|
      return key if build_sql_match(method, [key], value, common_sql).exists?
    end
    raise 'Strange...'
  end
  #private_class_method :find_matched_attribute_after_find_by_a_title

  # Routine to create String-or-Regexp for {Translation.of_title) to
  # feed {Translation.select_regex}
  #
  # @param title [String]
  # @param exact: [Boolean] if true, only the exact match (after {SlimString}) is considered. So far, "exact: true" is similar to "case_sensitive: true", though it is more efficient.
  # @param case_sensitive: [Boolean] if true, only the exact match is considered.
  # @return [String, Regexp] str_or_regex
  def self.str_or_regex_for_of_title(title, exact: false, case_sensitive: false, **kwd)
    title_slim = SlimString.slim_string(title)

    if exact
      title_slim
    else
      Regexp.new('\A'+Regexp.quote(title_slim)+'\z', (case_sensitive ? nil : Regexp::IGNORECASE))
    end
  end
  private_class_method :str_or_regex_for_of_title

  # Returns an Array of {Translations} with the specified title (or alt_title)
  #
  # So far, both {Translation#title} and {Translation#alt_title} are considered.
  #
  # This is a wrapper of {Translation.select_regex}, but "scope" is considered.
  #
  # In the future, more sophisticated algorithm may be implemented.
  # Note {Translation.find_by_a_title} is more sophisticated; more flexible
  # and less DB-intensive.
  #
  # @param title [String]
  # @param exact: [Boolean] if true, only the exact match (after {SlimString}) is considered. So far, "exact: true" is similar to "case_sensitive: true", though it is more efficient.
  # @param case_sensitive: [Boolean] if true, only the exact match is considered.
  # @param scoped: [#pluck, #map] Array (or Relation) of {Translation}-s
  # @param **kwd [Hash] most notably, :langcode and :translatable_type
  # @return [Array<Translation>] maybe empty
  #
  # @todo Consider sort based on Levenshtein distances for more fuzzy matches
  def self.of_title(title_in, exact: false, case_sensitive: false, scoped: nil, **kwd)
    title = preprocess_space_zenkaku(title_in)
    scoped_ids = nil
    scoped_ids = (scoped.respond_to?(:pluck) ? scoped.pluck(:id) : scoped.map(&:id)) if scoped

    str_or_regex = str_or_regex_for_of_title(title, exact: exact, case_sensitive: case_sensitive, **kwd)

    rela = select_regex(:titles, str_or_regex, **kwd)
    return rela if !scoped_ids

    if rela.respond_to? :where
      rela.where('id IN (?)', scoped_ids)
    else
      rela.select{|i| scoped_ids.include? i.id}
    end
  end

  # Wrapper of {Translation.select_regex} to return the single matched Translation
  #
  # where {#matched_attribute} is set.
  #
  # @param example
  #   female_id = Sex['female'].id  # or Sex[2].id
  #   trans = Translation.find_by_regex(:all, /aLe/i, langcode: 'en', translatable_type: Sex,
  #                              where: ['id <> ?', female_id])
  #   trans.matched_attribute # => :title
  #   trans.matched_string    # => 'male'
  #
  # Note {#matched_attribute} is not set in each element object
  # of the returned object of the sister method, {Translation.select_regex},
  # because it can be {Translation::ActiveRecord_Relation}),
  # where "each element" cannot be defined without converting into an Array.
  #
  # @param kwd [Symbol, String, Array<String>, NilClass] (title|alt_title|ruby|alt_ruby|romaji|alt_romaji|titles|all)
  #    or Array of Symbol|String to evaluate. Note :titles is the alias
  #    for [:title, :alt_title], and :all means all the 6 columns.
  #    If nil, this parameter, as well as value, is not used.
  # @param value [Regexp, String, NilClass] e.g., 'male' and /male\z/
  # @param *args #see Translation.select_regex
  # @param **kwds #see Translation.select_regex
  # @return [String, NilClass] nil if not found
  def self.find_by_regex(kwd, value, *args, **opts)
    translation = select_regex(kwd, value, *args, **opts).first || return
    translation.matched_attribute = translation.get_matched_attribute(kwd, value)
    translation
  end


  # wrapper of {Translation.select_regex}
  #
  # The search word is String, as given by a human over a UI.
  # Unlike {Translation.select_regex}, this runs {ModuleCommon#preprocess_space_zenkaku}.
  # All spaces, including newlines, are ignored (both in query string and DB).
  # Also, this deals with definite articles, i.e., both "The Beat" and "Beatles, Th" match
  # "Beatles, The".
  #
  # @example Returning Translations containing "procla" excluding IDs of 5 or 8.
  #    Translation.select_partial_str(:titles, 'Procla', not_clause: [{id: [5, 8]}])
  #
  # @param kwd [Symbol, String, Array<String>, NilClass] See {Translation.select_regex}
  # @param value [String] e.g., "The Beat" and "Beatles, Th"
  #   Preprocessed with {ModuleCommon#preprocess_space_zenkaku}
  # @param ignore_case [Boolean] if true (Def), case-insensitive search
  # @param restkeys [Array] See {Translation.select_regex}
  def self.select_partial_str(kwd, value, ignore_case: true, **restkeys)
    str2re = preprocess_space_zenkaku(value).gsub(/\s+/m, " ").strip
    _, rootstr, article = definite_article_with_or_not_at_tail_regexp(str2re) # in ModuleCommon

    str2re = Regexp.quote(rootstr.gsub(/\s/, ""))#.gsub(/(?<!\\)((?:\\\\)*)\\ /, '\1 ')  # "\ " => " "
    str2re << ".*," << article if !article.blank?
    regex = Regexp.new(str2re, (ignore_case ? Regexp::IGNORECASE : 0))
    #regex = Regexp.new(str2re, Regexp::EXTENDED | Regexp::MULTILINE | (ignore_case ? Regexp::IGNORECASE : 0))
    select_regex(kwd, regex, sql_regexp: true, space_sensitive: false, **restkeys)
  end

  # Gets an array of {Translation}
  #
  # Search for matching {Translation}-s.
  #
  # (1) If the given value is String, SQL is used to search the match (efficient),
  #     and Translation::ActiveRecord_Relation is returned.
  # (2) If Regexp, Ruby engine is used (hence more resource intensive),
  #     and Array<Translation> is returned.
  #
  # Note that the result is not "sorted", as there is
  # no general way to know whether the result is actually sortable.
  # If it is limited to a set of {Translation}s for a single object,
  # it will be sortable.
  #
  # @see Translation.find_all_by_a_title
  #
  # @example
  #   Translation.select_regex(:all, /male/, langcode: 'ja', translatable_type: Sex,
  #                                           where: ['id <> ?', pid], is_orig: true)
  #
  # @param kwd [Symbol, String, Array<String>, NilClass] (title|alt_title|ruby|alt_ruby|romaji|alt_romaji|titles|all)
  #    or Array of Symbol|String to evaluate. Note :titles is the alias
  #    for [:title, :alt_title], and :all means all the 6 columns.
  #    If nil, this parameter, as well as value, is not used.
  # @param value [Regexp, String, NilClass] e.g., 'male' and /male\z/
  #   NOTE this value is NOT {ModuleCommon#preprocess_space_zenkaku}-ed.
  # @param where: [String, Array<String, Hash, Array>, NilClass] Rails "where" clause for complex cases.
  #    An element for "where" can be one of String, Array (String with place holders
  #    for the first element, followed by their contents), and 2-element Array of
  #    [String, Hash] like ["title > :min", {min: xyz}].
  #    Multiple "where" clauses can be specified as an Array that contains
  #    an arbitrary number of the Array elements described above
  #    Note if you want to pass multiple simple strings, give a doulbe Array like
  #      [["a > b"], ["c <> d"]]
  #    because otherwise they are treated as a String followed by place-fillers like
  #      ["a > ? AND ? <> d", 'x', 'y']
  # @param joins: [String, Array<String, Hash, Array>, NilClass] Rails joins clause.
  #    See "where" for detail.
  #    Example: to join {Engage} for the translatable {Music}
  #       joins: 'INNER JOIN engages ON translations.translatable_id = engages.music_id'
  # @param not_clause: [String, Array<String, Hash, Array>, NilClass] Rails where.not clause.
  #    See "where" for detail.
  # @param sql_regexp [Boolean] If true (Def: false), and if value is Regexp, PostgreSQL +regexp_match()+ is used. Efficient!
  # @param space_sensitive [Boolean] This is referred to ONLY WHEN +value+ is Regexp and +sql_regexp+ is true.
  #    If true (Def; n.b., the default in {Translation.select_regex_string} is false!),
  #    spaces in DB entries are significant.
  #    Note that even if false (Def), this method does nothing to the input +value+ (Regexp)
  #    and so it is the caller's responsibility to set the Regexp +value+ accordingly.
  # @param langcode: [String, NilClass] Optional argument, e.g., 'ja'. If nil, all languages.
  # @param translatable_type: [Class, String] Corresponding Class of the translation.
  # @param **restkeys: [Hash] Any other (exact) constraints to pass to {Translation}
  #    For example,  is_orig: true
  # @return [Translation::ActiveRecord_Relation, Array<Translation>]
  # @note To developers. Technically, option +space_sensitive+ can be taken into account
  #    for any Regexp +value+, regardless of +sql_regexp+
  #def self.select_regex(kwd, value, langcode: nil, translatable_type: nil, where: nil, joins: nil, not_clause: nil, **restkeys)
  def self.select_regex(kwd, value, where: nil, joins: nil, not_clause: nil, sql_regexp: false, space_sensitive: true, **restkeys)
    allkeys = get_allkeys_for_select_regex(kwd)
    common_opts = init_common_opts_for_select(**restkeys)

    if allkeys.empty? || value.blank? || value.respond_to?(:gsub) || (sql_regexp && value.respond_to?(:named_captures))
      select_regex_string(common_opts, allkeys, value, where, joins, not_clause, space_sensitive: space_sensitive, **restkeys) # => Translation::ActiveRecord_Relation
    elsif value.respond_to?(:named_captures)
      select_regex_regex( common_opts, allkeys, value, where, joins, not_clause, **restkeys) # => Array<Translation>
    else
      msg = "Contact the code developer. value is strange: "+value.inspect
      logger.error msg
      raise ArgumentError, msg
    end
  end

  # Returns the initialized Hash for #{Translation.select_regex}
  #
  # @param langcode: [String, NilClass] Optional argument, e.g., 'ja'. If nil, all languages.
  # @param translatable_type: [Class, String] Corresponding Class of the translation.
  # @param **restkeys: [Hash] Any other (exact) constraints to pass to {Translation}
  #    For example,  is_orig: true
  # @return [Hash] e.g., {langcode: 'en', translatable_type: 'Country, is_orig: true}
  def self.init_common_opts_for_select(langcode: nil, translatable_type: nil, **restkeys)
    common_opts = {}.merge restkeys
    common_opts[:langcode] = langcode.to_s if langcode
    common_opts[:translatable_type] = (%i(where name).all?{|i| translatable_type.respond_to?(i)} ? translatable_type.name : translatable_type) if translatable_type
    common_opts
  end
  private_class_method :init_common_opts_for_select

  # Wrapper of {#get_matched_attribute}. Set {#matched_attribute}.
  #
  # @return [Symbol, NilClass] as set at {#matched_attribute}
  def set_matched_attribute(kwd, value)
    self.matched_attribute = get_matched_attribute(kwd, value)
  end

  # Returns the Attribute (e.g., :title, :alt_title) whose content matches the given condition.
  #
  # Note that you should use {#set_matched_attribute}, which sets
  # the instance variable {#matched_attribute}, if you want to
  # reuse the result.
  #
  # @example When one of the attributes matches /aLe/i
  #   trans = Sex['female'].best_translation[:en]
  #   attr = trans.get_matched_attribute(:all, /aLe/i)  # => :title
  #   trans.send attr  # => 'female'
  #
  # @param kwd [Symbol, String, Array<String>, NilClass] (title|alt_title|ruby|alt_ruby|romaji|alt_romaji|titles|all)
  #    or Array of Symbol|String to evaluate. Note :titles is the alias
  #    for [:title, :alt_title], and :all means all the 6 columns.
  #    If nil, this parameter, as well as value, is not used.
  # @param value [Regexp, String, NilClass] e.g., 'male' and /male\z/
  # @return [Symbol, NilClass] nil if not found (basically when the combination of [kwd, value] is inconsistent with those used to select self)
  def get_matched_attribute(kwd, value)
    allkeys = self.class.send(:get_allkeys_for_select_regex, kwd)

    return :title if allkeys.empty? || value.blank?
    if value.respond_to?(:gsub)
      cmp_method = :==
    elsif value.respond_to?(:named_captures)
      cmp_method = :match
    else
      msg = "(#{__method__}) Contact the code developer. value is strange: "+value.inspect
      logger.error msg
      raise ArgumentError, msg
    end

    allkeys.each do |method|
      s = send(method)
      return method if value.send(cmp_method, s)
    end

    return nil
  end

  # Internal utility method
  #
  # (though it can be called from an instance method, hence public.)
  #
  # @param kwd [Symbol, String, Array<String>, NilClass] (title|alt_title|ruby|alt_ruby|romaji|alt_romaji|titles|all)
  #    Note :titles and :all must be specified on its own and must not be contained within an Array.
  #    Valid examples: :titles OR :all OR :ruby OR %i(ruby romaji)
  # @return [Array<Symbol>] like %i(title alt_title)
  def self.get_allkeys_for_select_regex(kwd)
    if !kwd
      []
    elsif kwd.respond_to? :map
      kwd.map(&:to_sym)
    else
      case kwd.to_sym
      when :all
        TRANSLATED_KEYS 
      when :titles
        %i(title alt_title)
      else
        [kwd.to_sym]
      end
    end
  end
  # private_class_method :get_allkeys_for_select_regex


  # Core routine for {Translation.select_regex} for String input
  #
  # Search for matching {Translation}-s
  # for a given value of String (or nil). SQL is used to search the match.
  # If Regexp, Ruby engine is used (hence more resource intensive) as in {Translation.select_regex_regex}.
  #
  # The created SQL is like (alltrans.to_sql):
  #
  #   SELECT "translations".* FROM "translations" WHERE "translations"."langcode" = $1
  #     AND "translations"."translatable_type" = $2
  #     AND ((((("translations"."title" = $3 OR "translations"."alt_title" = $4)
  #           OR "translations"."ruby" = $5)
  #           OR "translations"."alt_ruby" = $6)
  #           OR "translations"."romaji" = $7)
  #           OR "translations"."alt_romaji" = $8) LIMIT $9
  #    [["langcode", "en"], ["translatable_type", "Sex"],
  #     ["title", "male"], ["alt_title", "male"], ["ruby", "male"],
  #     ["alt_ruby", "male"], ["romaji", "male"], ["alt_romaji", "male"], ["LIMIT", 11]]
  #
  # This routine is separate from {Translation.select_regex_regex}
  # just to utilize the SQL more efficiently.
  #
  # @param common_opts [Hash<Symbol, Object>] e.g., {:langcode=>"en", :translatable_type=>"Country"}
  # @param allkeys [Array<Symbol>] %i(title alt_title) etc
  # @param value [String, Regexp] e.g., 'female', /ab.*kg/. If Regexp, PostgreSQL Regexp is used (experimental!)
  #    Note that PostgreSQL does NOT support the full power of Ruby Regexp!
  #    Make sure your Regexp is PostgreSQL compatible!
  # @param where: [String, Array<String, Hash, Array>, NilClass] See {Translation.select_regex} for detail.
  # @param joins: [String, Array<String, Hash, Array>, NilClass] See {Translation.select_regex} for detail.
  # @param not_clause: [String, Array<String, Hash, Array>, NilClass]
  # @param space_sensitive [Boolean] This is referred to ONLY WHEN +value+ is Regexp.
  #    If true (Def: false), spaces in DB entries are significant.
  #    Note that even if false (Def), this method does nothing to the input +value+
  #    and so it is the caller's responsibility to adjust Regexp +value+ accordingly.
  # @param **restkeys [Hash] Any other (exact) constraints to pass to {Translation}
  # @return [Translation::ActiveRecord_Relation]
  def self.select_regex_string(common_opts, allkeys, value, where, joins, not_clause=nil, space_sensitive: false, **restkeys)
    base_rela = make_joins_where(where, joins, not_clause, parent: self.where(common_opts))
    return base_rela if (allkeys.empty? || value.blank?)

    if value.respond_to?(:named_captures)
      re_str, reopts = regexp_ruby_to_postgres(value) # defined in ./module_common.rb
    end

    rela2ors = allkeys.map{ |ek|
      if value.respond_to?(:named_captures)
        _psql_where_regexp(base_rela, ek, re_str, reopts, space_sensitive: space_sensitive)
      else
        base_rela.where({ek => value})
      end
    }

    # ActiveRecord converts "(A && B && C) || (A && B && D)"
    #                  into "A && B && (C || D)"
    # where "A && B" corresponds to "common_opts"
    alltrans = rela2ors.shift
    rela2ors.each do |ei|
      alltrans = alltrans.or(ei)
    end

    alltrans
  end
  private_class_method :select_regex_string

  # Core routine for searching with PostgreSQL (this will be OR-ed)
  #
  # All spaces are removed from the DB entries, *unless* space_sensitive is
  # true (Def: false).
  #
  # @param key [Symbol, String]
  # @param re_str [String] of PostgreSQL Regexp expressions
  # @param reopts [String] of PostgreSQL Regexp options
  # @param space_sensitive [Boolean] If true (Def: false), spaces in DB entries are significant.
  # @return [Translation::ActiveRecord_Relation]
  def self._psql_where_regexp(alltrans, key, re_str, reopts, space_sensitive: false)
    expre = _psql_where_regexp_core(key, space_sensitive: space_sensitive)
    alltrans.where(expre, re_str, reopts)
  end
  private_class_method :_psql_where_regexp

  # Returns the String expressoin for Regexp where
  #
  # All spaces are removed from the DB entries, *unless* space_sensitive is
  # true (Def: false).
  #
  # @param key [Symbol, String]
  # @param space_sensitive [Boolean] If true (Def: false), spaces in DB entries are significant.
  # @return [String]
  def self._psql_where_regexp_core(key, space_sensitive: false)
    if space_sensitive
      "regexp_match(#{table_name}.#{key.to_s}, ?, ?) IS NOT NULL"
    else
      "regexp_match(translate(#{table_name}.#{key.to_s}, ' ', ''), ?, ?) IS NOT NULL"
    end
  end
  private_class_method :_psql_where_regexp_core

  # Core routine for {Translation.select_regex} for Regexp input
  #
  # Search {Translation} to find matching {BaseWithTranslation}-s
  # for a given value of Regexp. 
  # Ruby engine is used.
  #
  # @param common_opts [Hash<Symbol, Object>] e.g., {:langcode=>"en", :translatable_type=>"Country"}
  # @param allkeys [Array<Symbol>] %i(title alt_title) etc
  # @param regex [Regexp] e.g., /male\z/ (which would match 'female')
  # @param where: [String, Array<String, Hash, Array>, NilClass] See {Translation.select_regex} for detail.
  # @param joins: [String, Array<String, Hash, Array>, NilClass] See {Translation.select_regex} for detail.
  # @param not_clause: [String, Array<String, Hash, Array>, NilClass]
  # @param **restkeys: [Hash] Any other (exact) constraints to pass to {Translation}
  # @return [Array<BaseWithTranslation>]
  def self.select_regex_regex(common_opts, allkeys, regex, where, joins, not_clause=nil, **restkeys)
    alltrans =
      if common_opts.empty?
        make_joins_where(where, joins, not_clause).all
      else
        make_joins_where(where, joins, not_clause).where(common_opts)
      end

    alltrans.select{ |ea_tr|
      allkeys.any?{ |ea_k|
        val = ea_tr.send ea_k
        val && (regex =~ val)
      }
    }
  end
  private_class_method :select_regex_regex

  # Returns Rails where clause.
  #
  # See {Translation.select_regex} for detail of each parameter.
  #
  # @param where: [String, Array<String, Hash, Array>, NilClass]
  # @param joins: [String, Array<String, Hash, Array>, NilClass]
  # @param not_clause: [String, Array<String, Hash, Array>, NilClass]
  # @param parent [Translation::ActiveRecord_Relation, NilClass]
  # @return [Translation::ActiveRecord_Relation]
  def self.make_joins_where(where, joins, not_clause=nil, parent: nil)
    ret = (parent || self.where('true'))
    ret = make_joins_where_core(ret, :joins, joins) if joins
    ret = make_joins_where_core(ret, :where, where) if where
    ret = make_joins_where_core(ret, :not  , not_clause) if not_clause
    ret
  end
  private_class_method :make_joins_where

  # Returns Rails where or join or where.not clause.
  #
  # @param obj [Translation, Translation::ActiveRecord_Relation]
  # @param kind [Symbol] either :where or :join
  # @param clause [String, Array<Array, String, Hash>, NilClass] for Rails where/join clause.
  #    See the "where" option in {Translation.select_regex} for detail.
  # @return [Translation, Translation::ActiveRecord_Relation]
  def self.make_joins_where_core(obj, kind, clause)
    return obj if clause.blank?
    return make_where_not(obj, kind, clause) if clause.respond_to?(:gsub)
    return make_where_not(obj, kind, clause) if clause.respond_to?(:each_pair)

    # now, Array === clause
    if clause.size == 2 && clause[0].respond_to?(:gsub) && clause[1].respond_to?(:each_pair)
      # now, clause: [String, Hash]
      return make_where_not(obj, kind, clause[0], **(clause[1]))
    end

    if !clause[0].respond_to?(:flatten)
      return make_where_not(obj, kind, *clause)
    end

    clause.each do |ec|
      obj = send(__method__, obj, kind, ec)
    end
    obj
  end
  private_class_method :make_joins_where_core


  # Returns Rails where or join clause.
  #
  # @param obj [Translation, Translation::ActiveRecord_Relation]
  # @param kind [Symbol] either :where or :join
  # @param *args [Array] parameters to passs to where etc.
  #    Multiple String elements or 1 String element with/without opts or None.
  # @param **opts [Hash] parameters to passs to where etc.
  # @return [Translation, Translation::ActiveRecord_Relation]
  def self.make_where_not(obj, kind, *args, **opts)
    return obj.where.not(*args, **opts) if kind == :not
    obj.send(kind, *args, **opts)
  end
  private_class_method :make_where_not


  # Similar to `find_or_create_by!` but update instead of find
  #
  # The arguments are similar to {Translation.select_regex} but additional
  # parameters to pass to {Translation.create!} or {Translation.update!}
  # are also accepted.
  #
  # The optional parameters langcode and translatable (or alternatively,
  # translatable_type and translatable_id) are not mandatory;
  # however, if no existing record is found to satisfy the conditions,
  # RuntimeError is raised; in other words, this method does not create
  # a new record with unknown langcode or translatable.
  #
  # If kwd is :titles or :all or Array, or value is Regexp, and if no existing
  # record is found, what to pass to {Translation.create!} is ambiguous.
  # Two solutions are provided:
  #
  # (1) if kwd or value is nil, nothing is taken from these parameters to pass.
  # (2) if kwd is Symol except for :titles or :all or String, they are passed
  #     as they are.
  # (3) if kwd is Array, the first element is interpreted as the parameter.
  # (4) the user can give a block, in which the parameters to the record
  #     must be defined. If value is Regexp, this is the only way.
  # (5) if the block is not given and if kwd is :titles or :all,
  #     {#title} is set to have the value.
  # (6) if all fails, nothing is passed, which is likely to raise an Exception
  #     somewhere in the subsequent processing.
  #
  # Note that the block is ignored for {Translation.update!} 
  #
  # There is a chance the final save! raises an Exception,
  # mainly because the given parameters are invalid, but potentially
  # because a competing process writes a record in between the process.
  # If an error is raised, the DB rollbacks and exception is raised.
  #
  # Unless an Exception is raised, the new or updated record (not reloaded,
  # but id and updated_at are filled) is returned.
  #
  # Then you can use it like
  #   model = Translation.update_or_create_regex! prms, [:id_unique1, :id_unique2]
  #   model.saved_change_to_updated_at?  # => true/false
  #
  # @example
  #   prms = {lang_code: 'en', country: Country['Japan', 'en'], note: 'new note'}
  #   trans = Translation.update_or_create_regex!(:titles, 'Tokyo', **prms)
  #   trans.saved_change_to_created_at?  # => true/false
  #   trans.saved_change_to_updated_at?  # => true/false
  #   # Creates or updates of a {Translation} of Prefecture of Tokyo.
  #
  # See {Translation.select_regex} for detail of the parameters: (kwd, value,
  # langcode, translatable, where, join), in addition to the other columns of
  # {Translation}. You usually should specify either translatable or
  # translatable_type and translatable_id.
  #
  # @param kwd [Symbol, String, Array<String>, NilClass] (title|alt_title|ruby|alt_ruby|romaji|alt_romaji|titles|all)
  #    or Array of Symbol|String to evaluate. Note :titles is the alias
  #    for [:title, :alt_title], and :all means all the 6 columns.
  #    If nil, this parameter, as well as value, is not used.
  # @param value [Regexp, String, NilClass] e.g., 'male' and /male\z/
  #   Note this value is NOT {ModuleCommon#preprocess_space_zenkaku}-ed.
  # @param langcode: [String, NilClass] Optional argument, e.g., 'ja'. If nil, all languages.
  # @param translatable_type: [Class, String] Corresponding Class of the translation.
  # @param parent [BaseWithTranslation] The parent class
  # @param prms [Hash] The data to insert (update or create)
  # @return [Translation] (you need to "reload")  If the given condition is identical with an existing one, the existing one is returned; {Translation#saved_changes?} returns false.
  # @raise [ActiveRecord::RecordInvalid, ActiveModel::UnknownAttributeError] etc
  # @yield Called only when create. Model is passed as the argument.
  def self.update_or_create_regex!(kwd, value, **prms)
    # value = preprocess_space_zenkaku(value_in) # NOT {ModuleCommon#preprocess_space_zenkaku}-ed so far
    ar4unique = %i(langcode translatable translatable_type translatable_id where join)
    create_opts, new_opts = split_hash_with_keys(prms, ar4unique)
    existings = select_regex(kwd, value, **create_opts)

    if (existings.count rescue existings.size) > 0
      # update!
      base_opts = {}
      record = existings[0]

      return record if new_opts.empty? # Nothing to be updated

      record.update!(**new_opts)
      return record
    end

    # creates! (practically)
    mainarg = {}
    if kwd
      keymain =
        if kwd.respond_to? :rotate
          kwd[0]
        elsif %i(titles all).include? kwd.to_sym
          :title
        else
          kwd
        end
      # If value is Regexp or nil, it is not passed to create.
      mainarg[keymain.to_sym] = value unless !value || value.respond_to?(:named_captures) || block_given?
    end

    base_opts, _ = split_hash_with_keys(prms, %i(langcode translatable translatable_type translatable_id))
    if (base_opts.key?(:langcode) &&
        (base_opts.key?(:translatable) ||
         ((%i(translatable_type translatable_id) & base_opts.keys).size == 2) && base_opts[:translatable_type] && base_opts[:translatable_id])) 
      # do nothing
    else
      msg = "(#{__method__}): Contact the code developer (Not both (langcode translatable (or _type & _id)) are specified to create in Translation: #{base_opts.inspect})."
      raise MultiTranslationError::AmbiguousError, msg
    end
    self.create!(**(mainarg.merge(base_opts).merge(**new_opts))){ |record|
      yield record if block_given?
    }
  end

  # Simpler method of update or create
  #
  # Wrapper of either {Translation.update_or_create_regex!} or
  # {ModuleCommon#update_or_create_by_with_notouch!}
  #
  # Less flexible, but this method handles the options in the same way
  # as {Translation.new} and automatically picked up the candidate to update
  # if there is any.
  #
  # The optional parameters langcode and translatable (or alternatively,
  # translatable_type and translatable_id) are not mandatory;
  # however, if no existing record is found to satisfy the conditions,
  # RuntimeError is raised; in other words, this method does not create
  # a new record with unknown langcode or translatable.
  #
  # == Algorithm to pick up the original record
  #
  # (1) If the argument inprms has both title and alt_title keys,
  #     then search for the record with the same combinations.
  # (2) If not, search for the key that exsits in inprms one by one
  #     from title, then alt_title, ruby, and once found,
  #     look for a single match in the existing record.
  #     For example, if the title key does not exist in inprms
  #     but alt_title does, then all the rest (ruby, romaji etc)
  #     are ignored, but it looks for the match for alt_title alone.
  #
  # @example
  #   prms = {title: 'Tokyo', lang_code: 'fr', country: Country['Japan', 'en'], note: 'new note'}
  #   trans = Translation.update_or_create_by!(**prms)
  #   trans.saved_change_to_created_at?  # => true/false
  #   trans.saved_change_to_updated_at?  # => true/false
  #   # Creates or updates of a {Translation} of Prefecture of Tokyo.
  #
  # @param nkeys [Integer, Symbol] If :auto (Default), [:title, :alt_title]
  #   is used to identify an existing {Translation}. If Integer, it is the size
  #   of the Array of the keys for it according to the order of 
  #   {Translation::TRANSLATED_KEYS}.
  #   For example, if nkeys==2, and inkeys==[:romaji, :alt_title, :ruby, :naiyo]
  #   [:alt_title, :ruby] is returned.
  # @param inprms [Hash] Should contain one of title, alt_tile, ruby etc, in addiotn
  #   to langcode and translatable (or translatable_type and translatable_id)
  # @return [Translation] (you need to "reload")
  # @raise [ArgumentError, ActiveRecord::RecordInvalid, ActiveModel::UnknownAttributeError] etc
  # @yield Called only when create. Model is passed as the argument.
  def self.update_or_create_by!(nkeys=:auto, **inprms, &bl)
    begin
      arkeys = keys_to_identify(inprms.keys, nkeys)
      # arkeys is guaranteed to have 1 or 2 elements.
    rescue
      raise ArgumentError, "(#{__method__}) Contact the code developer. inprms does not have the essential keys (nkeys=#{nkeys.inspect}): #{inprms.inspect}."
    end

    firstprms, prms = split_hash_with_keys(inprms, arkeys)

    szfi = firstprms.size
    if szfi == 1
      ar = firstprms.first
      update_or_create_regex!(ar[0], ar[1], **prms, &bl)
    elsif szfi > 1
      # both title and alt_title are specified.
      allkeys = firstprms.keys + %i(langcode translatable translatable_type translatable_id)
      update_or_create_by_with_notouch!(inprms, allkeys, &bl)
    else
      raise 'Should not happen.'
    end
  end

  # Find {Translation}-s from the main parameters
  #
  # In the argument inprms, title, langcode, translatable or
  # (translatable_type, translatable_id) are always taken into account.
  # In default (nkeys==:auto), alt_title is also taken into account.
  # However, any other parameters will be igonored, unless neither title
  # nor alt_tile exists or nkey is larger than 2 (or 1 in some cases).
  #
  # Returns {Translation::ActiveRecord_Relation}. If you want to know
  # if a {Translation} exists or not, do like
  #   Translation.find_by_mains(title: 'Japan', langcode: 'en', translatable_type: Country.name).count
  #
  # The following two are equivalent
  #   Translation.find_all_by_mains(title: 'Japan', langcode: 'en', translatable_type: Country.name)
  #   Country.select_translations_regex(:title, 'Japan', langcode: 'en')
  #
  # The following three are equivalent
  #   Translation.find_all_by_mains(title: 'Japan', langcode: 'en', translatable_type: Country.name)[0]
  #   Country.select_translations_regex(:title, 'Japan', langcode: 'en')[0]
  #   Translation.find_by_mains(    title: 'Japan', langcode: 'en', translatable_type: Country.name)
  #
  # The following two are similar, but returns [Country] as opposed to [Translation]
  #   Country.select_regex(:title, 'Japan', langcode: 'en')[0]
  #   Country['Japan', 'en']
  #
  # Note the following will find a {Translation} associated with a particular {Country} object,
  # which may have multiple English {Translation}-s
  #   cntry = Country.find(1)
  #   Translation.find_by_mains(title: 'Japan', langcode: 'en', translatable: cntry).count
  #
  # In short, the search conditions for {BaseWithTranslation.select_translations_regex} 
  # are much more inclusive than this method, as obvious from the fact the former
  # accepts even Regexp.
  #
  # @example difference 1: the former is searching title AND alt_title, whereas the latter, title OR alt_title. The last one is an alias of the second last one.
  #   Translation.find_all_by_mains(    title:  'Japan', alt_title: 'jp', langcode: 'en', translatable_type: Country.name)
  #   Country.select_translations_regex(:title, 'Japan', alt_title: 'jp', langcode: 'en')
  #   Country.select_translations_regex(:titles, 'Japan', langcode: 'en')
  #
  # @example difference 2: the former takes into accout title AND ruby with romaji ignored, because 2 is given, wheras the latter takes searches title OR ruby OR romaji.
  #   Translation.find_all_by_mains( 2, title:  'Japan', ruby: 'ジャパン', romaji: 'zyapan', langcode: 'en', translatable_type: Country.name)
  #   Country.select_translations_regex(:title, 'Japan', ruby: 'ジャパン', romaji: 'zyapan', langcode: 'en')
  #
  # @param nkeys [Integer, Symbol] If :auto (Default), [:title, :alt_title]
  #   is used to identify an existing {Translation}. If Integer, it is the size
  #   of the Array of the keys for it according to the order of 
  #   {Translation::TRANSLATED_KEYS}.
  #   For example, if nkeys==2, and inkeys==[:romaji, :alt_title, :ruby, :naiyo]
  #   [:alt_title, :ruby] is returned.
  # @param inprms [Hash] Should contain at least one of title, alt_tile, ruby etc, in addiotn
  #   to langcode and translatable (or translatable_type and translatable_id)
  # @return [Translation::ActiveRecord_Relation]
  # @raise [RuntimeError]
  def self.find_all_by_mains(nkeys=:auto, **inprms)
    arkeys = keys_to_identify(inprms.keys, nkeys)
    firstprms, _ = split_hash_with_keys(inprms, arkeys+%i(langcode translatable translatable_type translatable_id))
    Translation.where(firstprms)
  end

  # Wrapper of {Translation.find_all_by_mains} but returns the first element.
  #
  # If none is found, nil is returned.
  #
  # @param (see #Translation.find_all_by_mains)
  # @param inprms [Hash] Should contain one at least of title, alt_tile, ruby etc, in addiotn
  #   to langcode and translatable (or translatable_type and translatable_id)
  # @return [Translation, NilClass]
  # @raise [RuntimeError]
  def self.find_by_mains(*arg, **inprms)
    find_all_by_mains(*arg, **inprms)[0]
  end

  # Gets the first key(s) to identify {Translation}-s
  #
  # Convenience method to get a require main key(s) of
  # {Translation} and returns an array of a Symbol(s).
  #
  # @param inkeys [Array] of keys. Should contain at least one of title, alt_tile, ruby etc.
  #   It can contain any other keys.
  # @param nkeys [Integer, Symbol] if Integer, it is Array.size of the return.
  #   If :auto (Default), [:title, :alt_title] or an Array of a single Symbol.
  #   For example, if nkeys==2, and inkeys==[:romaji, :alt_title, :ruby, :naiyo]
  #   [:alt_title, :ruby] is returned according to the order of 
  #   {Translation::TRANSLATED_KEYS}.
  # @return [Array<Symbol>] e.g., [:title, :alt_title] and [:ruby]
  # @raise [RuntimeError]
  def self.keys_to_identify(inkeys, nkeys=:auto)
    if (nkeys == :auto) && inkeys.include?(:title) && inkeys.include?(:alt_title)
      # Special case of [:title, :alt_title] b/c the combination has to be unique.
      return [:title, :alt_title]
    end

    nkeys = 1 if nkeys == :auto
    arret = []
    TRANSLATED_KEYS.each do |ek|
      next if !inkeys.include? ek
      arret.push ek
      return arret if arret.size >= nkeys
    end

    msg = "(#{__method__}) Contact the code developer. Failed to find all the parameters (nkeys=#{nkeys.inspect}) in #{inkeys.inspect}."
    raise RuntimeError, msg
  end


  # Comparison operator
  #
  # Sort according to is_orig, I18n.available_locales and weights
  # in this order.
  # It is undefined for comparison with different parent objects.
  def <=>(other)
    return nil if !same_parent?(other)

    # Note that if langcode is not among the registered one, their order is undefined.
    lang_order_a = ( self.langcode && I18n.available_locales.find_index( self.langcode.to_sym) || Float::INFINITY)
    lang_order_b = (other.langcode && I18n.available_locales.find_index(other.langcode.to_sym) || Float::INFINITY)

    [( self.is_orig ? 0 : 1), lang_order_a, ( self.weight || Float::INFINITY)] <=> \
    [(other.is_orig ? 0 : 1), lang_order_b, (other.weight || Float::INFINITY)]
  end

  # Sort an Array of Hash-es each of which will be fed to create a {Translation}
  #
  # This is used in {Country#after_first_translation_hook} and
  # {Prefecture#after_first_translation_hook}, where the first associated
  # {Translation} matters, because if its is_orig==true, is_orig of the
  # created UnknownPrefecture (etc) is also is_orig, whereas that for the
  # other languages are false.
  #
  # @param ary [Array] of Hash-es
  # @return [Array]
  def self.array_sort(ary)
    ary.sort{ |a, b|
      if !a.kind_of?(self) || !b.kind_of?(self)
        nil
      else
        # Note that if langcode is not among the registered one, their order is undefined.
        lang_order_a = ((a[:langcode] && I18n.available_locales.find_index(a[:langcode])) || Float::INFINITY)
        lang_order_b = ((b[:langcode] && I18n.available_locales.find_index(b[:langcode])) || Float::INFINITY)

        [(a[:is_orig] ? 0 : 1), lang_order_a, (a[:weight] || Float::INFINITY)] <=> \
        [(b[:is_orig] ? 0 : 1), lang_order_b, (b[:weight] || Float::INFINITY)]
      end
    }
  end

  # True if belongs_to a same parent
  def same_parent?(other)
    self.translatable == other.translatable
  end

  # True if the original translation
  def original?
    !!is_orig
  end

  # Returns [title, alt_title]
  #
  # @return [Array<String, NilClass>] size=2. Elements can be nil.
  def titles
    [title, alt_title]
  end

  # Returns title or alt_title
  #
  # If neither is found, an empty string "" is returned.
  #
  # @param prefer_alt: [Boolean] if true (Def: false), alt_title is preferably
  #    returned as long as it exists.
  # @return [String]  Note it is guaranteed to be String, never nil.
  def title_or_alt(prefer_alt: false)
    cands = titles
    cands.reverse! if prefer_alt
    cands.compact.first || ""
  end

  # Get the sorted {Translation} Array belonging to the same parent for the language
  #
  # If langcode is nil, the same as the langcode of self.
  # If exclude_self: is true, self will be excluded in the returned Array.
  #
  # @param lcode [String, NilClass] The redundant (same-meaning) argument to "langcode:"
  # @param langcode: [String, NilClass] e.g., 'ja'
  # @param exclude_self: [Boolean] (Def: false)
  # @return [ActiveRecord::AssociationRelation]
  def siblings(lcode=nil, langcode: nil, exclude_self: false)
    lcode = (lcode || langcode || self.langcode).to_s
    return [] if !translatable.respond_to? :translations  # Practically: translatable.nil?
    ret = translatable.translations.where(langcode: lcode)
    ret = ret.where.not(id: id) if exclude_self
    ret = self.class.sort(ret)
  end

  # Wrapper for {BaseWithTranslation:orig_translation}
  #
  # @return [Translation, Nilclass] nil if no {Translation} has {Translation#is_orig}==true 
  def orig_translation
    return self if is_orig
    return nil if !translatable.respond_to? :translations  # Practically: translatable.nil?
    translatable.send __method__
  end
  alias_method :original_translation, :orig_translation if ! self.method_defined?(:original_translation)

  # Wrapper for {BaseWithTranslation:orig_langcode}
  #
  # @return [Translation, Nilclass] nil if no {Translation} has {Translation#is_orig}==true 
  def orig_langcode
    return self.langcode if is_orig
    return nil if !translatable.respond_to? :translations  # Practically: translatable.nil?
    translatable.send __method__
  end
  alias_method :original_langcode, :orig_langcode if ! self.method_defined?(:original_langcode)

  # Returns a String of (Yes(True), No(False), &mdash;(nil))
  #
  # @return [String]
  def is_orig_str
    case is_orig
    when nil
      "&mdash;".html_safe
    when false
      "No"
    else
      "Yes"
    end
  end

  # Returns the {Translation#weight} to set in create.
  #
  # It is the current best-score {Translation} in current_user's role minus 1.
  # However, the value has to be larger than the senior-role's (highest, i.e. worst) weight.
  # If the value-1 violates it, a middle (Float) value between the current lowest
  # of current_user's {Role} and the highest of the immediate senior Role.
  #
  # For sysadmin, since the {Role#weight} is zero, which is the lowest value,
  # and since there is a unique constraint (that all the {Translation#weight}
  # must be unique), any new translation is given a positive but very small value of weight.
  #
  # @note
  # Maybe the admin's {Role#weight} is set 1. Then it would be simpler.
  #
  # @return [Numeric] Default weight for the user. Float::INFINITY if no user or if user has no {Role} for Translation.
  def def_weight(user=Translation.whodunnit)
    return Float::INFINITY if !user
    role = user.highest_role_in(RoleCategory[RoleCategory::MNAME_TRANSLATION])
    return Float::INFINITY if !role
    return role.weight if !translatable  # only possible when this is a new_record

    immediate_superior = role.superiors[-1]  # If current_user is sysadmin, it is nil
    higher_than = (immediate_superior ? immediate_superior.weight : 0)  # returned weight is guaranteed to be higher than this value
    best_trans = self.class.sort(self.class.where(translatable: translatable, langcode: langcode).where('weight > ?', higher_than)).first
    if !best_trans  # i.e., if there are no other translations for the term in the language by people including current_user at the same rank as current_user
      return ((role.weight > 0) ? role.weight : 1) # the latter is for sysadmin only (role.weight == 0).
    end
    btw = (best_trans.weight ? best_trans.weight : 0)
    ((btw-1 > higher_than) ? [role.weight, (btw-1)].min : (higher_than + btw).quo(2))
  end

  # Callback before_validation and before_save
  #
  # {#slim_opts} is taken into account.
  def move_articles_to_tail
    return if defined?(@skip_preprocess_callback) && @skip_preprocess_callback
    @backup_6params = preprocess_6params(article_to_tail: :check)
  end

  # Callback before_create
  #
  # Set create_user_id
  # Skipped if {Translation.skip_set_user_callback} is true.
  def set_create_user
    if self.class.skip_set_user_callback
      self.weight ||= Float::INFINITY
      return
    end
    self.create_user ||= Translation.whodunnit
    self.weight ||= def_weight
  end

  # Callback before_save
  #
  # Set update_user_id
  # Skipped if {Translation.skip_set_user_callback} is true.
  def set_update_user
    return if self.class.skip_set_user_callback
    self.update_user = Translation.whodunnit if !update_user_id_changed?
  end

  # Callback after_save
  def reset_backup_6params
    @backup_6params = nil
  end

  # Callback after_validation
  #
  # Revert 6 parameters to the state before before_validation
  # Significant only before create
  def revert_articles
    return if defined?(@skip_preprocess_callback) && @skip_preprocess_callback
    return if !@backup_6params  # should neve be the case...
    @backup_6params.each_pair do |ek, ev|
      next if ev.blank?
      send ek.to_s+'=', ev
    end
    @backup_6params = nil
  end

  ################################################
  private
  ################################################

    # Call after_first_translation_hook if it exists in the parent.
    #
    # For example, whenever a new first entry for a Prefecture is created,
    # a new Translation for Place 'UnknonwPlace' is created.
    def call_after_first_translation_hook
      parent = translatable
      ### This does not work for some reason! Must use 'where()' apparently.
      #if (parent.translations.size == 1) && parent.respond_to?(:after_first_translation_hook)
      if (Translation.where(translatable: parent).count == 1) && parent.respond_to?(:after_first_translation_hook)
          parent.after_first_translation_hook
      end
    end

    # @return [Float, NilClass] nil if a user is not logged in or weight is not defined.
    def weight_by_role_user
      return if !respond_to?(:user_signed_in?) || !user_signed_in?  # perhaps run by the system or via Console.
      role_moderator = RoleCategory[RoleCategory::MNAME_HARAMI].roles[0]  # Highest in the RoleCategory HARAMI

      return if !current_user
      allroles = current_user.roles.select{|i| (role_moderator <= i) rescue nil}
      # non-nil means they are "related"
      # Note the roles in RoleCategory "ROOT" are excluded, because
      # they should not change the weight without explicitly specifying it.

      role_weight = (allroles.empty? ? Float::INFINITY : allroles.map{|i| i.weight}.min)
      user_weight = (1.quo(current_user.score_edit) rescue Float::INFINITY)
      ret = [role_weight, user_weight].min
      (ret == Float::INFINITY) ? nil : ret
    end

    # false if en-title or romaji contains Asian characters
    #
    # false if ruby contains kanji
    def asian_char_validator
      fmt = 'contains %s characters (%s)'
      if langcode && !(%w(ja ko zh).include?(langcode.to_s))
        mat = self.class.contained_asian_chars(title)
        errors.add :title,     sprintf(fmt, 'Asian', mat[0]) if mat
        mat = self.class.contained_asian_chars(alt_title)
        errors.add :alt_title, sprintf(fmt, 'Asian', mat[0]) if mat
      end

      mat = self.class.contained_asian_chars(romaji)
      errors.add :romaji, sprintf(fmt, 'Asian', mat[0]) if mat

      mat = self.class.contained_kanjis(ruby)
      errors.add :ruby,   sprintf(fmt, 'Kanji', mat[0]) if mat
    end
end

class << Translation
  # Setter/getter of {Translation.whodunnit}
  attr_accessor :whodunnit

  # Skip {#set_create_user} and {#set_update_user} (before_create and before_save) callbacks if true.
  # This is set especially for processing from Harami1129, as the translations populated
  # from the table are NOT set by the signed-in user.
  attr_accessor :skip_set_user_callback
end

