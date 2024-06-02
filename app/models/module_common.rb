# -*- coding: utf-8 -*-

require 'nkf'

# Common utility routines
#
# Part of the routines are also found in
# https://github.com/masasakano/japanese_utils
module ModuleCommon
  attr_accessor :validation_messages

  # A set of options having special meanings and their default values
  # used in #{create_translation!} and #{create_translations!}
  # They are removed before being passed to #{Translation.create!} etc.
  #
  # Slightly modified {SlimString::DEF_SLIM_OPTIONS} so newlines are
  # converted (and truncated), assuming words to be translated should not
  # contain newlines in the first place. Classes that include this module
  # may overwrite it, or it (usually) can be specified in each method call.
  COMMON_DEF_SLIM_OPTIONS = SlimString::DEF_SLIM_OPTIONS.merge({convert_spaces: true})

  ERR_MSG_FMT_COMMON = {
    'comparison' => "comparison of %s with %s failed%s",
  }

  ERR_CLASS_SEND_COMMON = {
    'comparison' => ArgumentError,
  }

  # English, French, Spanish, and German are considered,
  # though German "die" is not considered.
  DEFINITE_ARTICLES = %w(the l' le la les el los las lo der das des dem den)

  # Regular expression. Name "La La xyz" is a special case, where "la" is NOT an article.
  #
  # @note This is used for both Ruby and PostgreSQL!  For Ruby, it is preferrable
  #   to appern "\b" (i.e., a word boundary, *except* inside a range) at the tail.
  #   However, "\b" means a backspace in PostgreSQL! Therefore, it is not included.
  #   Technically, {#regexp_ruby_to_postgres} can deal with it (n.b., "\b" in Ruby is
  #   equivalent to "\y" in PostgreSQL).
  # @see https://www.postgresql.org/docs/current/functions-matching.html#POSIX-ESCAPE-SEQUENCES
  DEFINITE_ARTICLES_REGEXP_STR = "(?:"+DEFINITE_ARTICLES.reject{|i| i == "la"}.join('|')+"|la(?! +la +))"

  # Mapping between each destination correct characters and unstandard ones.
  # 
  # Retrieve the value with {#chars_ja_char_mappings}
  # for the given destination characters for a given level
  # so that the fallback routine works.
  # 
  # The keys for each element should be one of [:conservative, :standard, :aggressive]
  JA_CHAR_MAPPINGS = {
    "\u301C" => {  # wave dash "波ダッシュ" (JIS X 0213: 1-1-33 "〜")
      conservative: ["\uFF5E"], # FULLWIDTH TILDE "全角チルダ"(SJIS) (JIS X 0213: 1-2-18 "～")
      standard:     ["\uFF5E", "\u223C", "\u2053"], # TILDE OPERATOR (∼), SWUNG DASH (⁓)
      aggressive:   nil,  # fallback to :standard
    }
  }

  # Default start_year of {EventGroup} etc
  DEF_EVENT_START_YEAR = TimeAux::DEF_FIRST_DATE_TIME.year  # defined in /lib/time_aux.rb

  # Default end_year of {EventGroup} etc
  DEF_EVENT_END_YEAR   = TimeAux::DEF_LAST_DATE_TIME.year   # defined in /lib/time_aux.rb

  extend ActiveSupport::Concern
  module ClassMethods
    # Returns a new unique weight (used for new)
    #
    # The returned weight is lower than that of +unknown+ unless a higher
    # weight already exists.
    #
    # @example
    #   ChannelType.new_unique_max_weight
    #
    # @return [Float]
    # @raise [TypeError] if Class does not have a method of weight
    def new_unique_max_weight
      raise TypeError, "(#{__method__}) Class #{self.name} not supporting weight. Contact the code developer." if !(self.attribute_names.include?("weight") || (self.first && self.first.respond_to?(:weight)))

      unknown_weight = ((self.respond_to?(:unknown) && (unk=self.unknown)) ? unk.weight : nil)
      last_model = self.where.not(weight: nil).where.not(weight: unknown_weight).order(:weight).last
      highest_weight = (last_model ? last_model.weight : 490)  # returning 500 in an unlikely case where there is no existing model

      return highest_weight+10 if !unknown_weight || unknown_weight < highest_weight
      if highest_weight + 10 < unknown_weight
        highest_weight + 10
      else
        (highest_weight + unknown_weight).quo(2)
      end
    end
  end

  # For model that has the method +place+
  #
  # @return [String] "県 — 場所 (国)"
  def txt_place_pref_ctry(langcode: I18n.locale, prefer_alt: true, **opts)
    ar = place.title_or_alt_ascendants(langcode: langcode, prefer_alt: prefer_alt, **opts);
    sprintf '%s %s(%s)', definite_article_to_head(ar[1]), (ar[0].blank? ? '' : '— '+definite_article_to_head(ar[0])+' '), definite_article_to_head(ar[2])
  end

  # Returns I18n Date-string from Date with potentiallyy unknown elements
  #
  # The nil part is displayed in either '——' or '??' (or '????' for the year)
  #
  # @param year  [Date, Integer, NilClass]
  # @param month [Integer, NilClass]
  # @param day   [Integer, NilClass]
  # @param langcode: [String, Symbol] Default: +I18n.locale+
  # @param lower_end_str: [String, NilClass] if     nil  or Year <  100, this String is returned (html_safe).
  # @param upper_end_str: [String, NilClass] if non-nil and Year > 9000, this String is returned (html_safe).
  # @return [String]
  def date2text(year, month=nil, day=nil, langcode: I18n.locale, lower_end_str: nil, upper_end_str: nil)
    if year.respond_to? :today?  # Date is given; n.b., Integer#month is defined in Rails...
      day = year.day
      month = year.month
      year = year.year
    end

    if year.blank?
      return lower_end_str if lower_end_str
      year  = nil 
    elsif year <  100
      return lower_end_str if lower_end_str
    elsif year > 9000
      return upper_end_str if upper_end_str
    end

    month = nil if month.blank?
    day   = nil if day.blank?
    case langcode.to_s
    when "ja"
      sprintf("%s年%s月%s日", *([year, month, day].map{|i| (i ? i : '——')}))
    else
      if year || !month
        sprintf('%s-%s-%s', (year ? sprintf("%4d", year) : '????'), *([month, day].map{|i| (i ? sprintf("%02d", i) : '??')}))
      else
        d2 = (day ? day : 28)
        ret = I18n.l(Date.new(DEF_EVENT_END_YEAR,month,d2), format: :long, locale: "en").sub(/\b#{DEF_EVENT_END_YEAR}\b/, '????')
        (day ? ret : ret.sub(/\b28\b/, '??'))
      end
    end
  end

  # Returns I18n Date-string from Date and Hour-Min with potentiallyy unknown elements
  #
  # The nil part is displayed in either '——' or '??' (or '????' for the year),
  # depending on langcode.  If the given time is simply nil, "&mdash;" is returned.
  #
  # @example
  #   time = Time.new(1984,2,3,4,5,1)
  #   time_err2uptomin(time, 70.minute, langcode: "ja")
  #     # => "1984年2月3日 04:——"
  #   time_err2uptomin(time, 70.minute, langcode: "en")
  #     # => February 03, 1984 — 04:??
  #   time_err2uptomin(time, 13.month,  langcode: "en")
  #     # => "1984-??-?? ??:??"
  #   time_err2uptomin(time, nil, langcode: "xx")
  #     # => "February 03, 1984 — 04:05"
  #
  # @param time  [Time, TimeWithError, NilClass]
  # @param err [ActiveSupport::Duration, Integer, NilClass] in seconds in in Integer
  # @param langcode [String, Symbol] Default: +I18n.locale+
  # @return [String]
  def time_err2uptomin(time, err=nil, langcode: I18n.locale)
    return "&mdash;".html_safe if !time
    if  err.blank?
      err = time.error if time.respond_to?(:error)
      err ||= 0.second
    end
    err = err.second if !err.respond_to? :in_seconds
    year   = time.year

    if err < 12.month
      month = time.month
      if err < 31.day
        day = time.day
        if err < 24.hour
          hour = time.hour
          if err < 60.minute
            minute = time.min
          end
        end
      end
    end

    ret_h = sprintf('%s:%s', *(_arstr_sprintf_int([hour, minute])))
    case langcode.to_s
    when "ja"
      ar = _arstr_sprintf_int([month, day], fmt: "%s", fallback: "——")
      sprintf("%s年%s月%s日 ", year, *ar) + ret_h.gsub(/\?\?/, "——")  # eg, "1984年2月3日 04:——"
    else
      if !month
        sprintf('%4d-%s-%s ', year, *(_arstr_sprintf_int([month, day]))) + ret_h  # eg, "1999-??-?? ??:??"
      else
        d2 = (day ? day : 28)
        ret_d = I18n.l(Date.new(year, month, d2), format: :long, locale: "en")
        ret_d.sub!(/\b28\b/, '??') if !day
        ret_d + " — " + ret_h  # eg. January 01, 0001 — 04:??
      end
    end
  end # def time_err2uptomin(time, err, langcode: I18n.locale)

  # @example
  #   time_in_units(event.start_time_err)
  #    # => "0.5 [days] | 12 [hrs] | 720 [mins]"
  #
  # @return [String] time expressed in three or so units.
  def time_in_units(time, units: [:day, :hour, :min], langcode: I18n.locale, for_editor: false)
    arret = units.map{|eunit|
      case eunit.to_sym
      when :day
        [(time ? time.second.in_days.to_s : nil),    I18n.t(:days,          locale: langcode)]
      when :hour
        [(time ? time.second.in_hours.to_s : nil),   I18n.t(:hours_short,   locale: langcode)]
      when :min
        [(time ? time.second.in_minutes.to_s : nil), I18n.t(:minutes_short, locale: langcode)]
      else
        raise "not yet supported..."
      end
    }
    str2add = ((for_editor && arret.map(&:first).compact.empty?) ? " (<em>UNDEFINED</em>)" : "")

    retstr = arret.map{|ea|
      sprintf("%s [%s]", (ea[0] || "&mdash;"), ERB::Util.html_escape(ea[1]))
    }.join(" | ") + str2add
    retstr.html_safe
  end

  # Returns {TimeWithError} of {#start_time} with {#start_time_err}  in the application Time zone
  #
  # In the DB, time is saved in UT, perhaps corrected from the app
  # timezone; i.e., if a user-input Time is in JST (+09:00), its saved time
  # in the DB is 9 hours behind.
  #
  # This method returns {TimeWithError} with the app-timezone, likely JST +09:00,
  # as set in /config/application.rb
  #
  # Used in Event and EventItem.
  #
  # @return [TimeWithError]
  def start_app_time
    return nil if !start_time

    t = TimeWithError.at(Time.at(start_time), in: Rails.configuration.music_i18n_def_timezone_str)
    ## Note: TimeWithError.at(start_time) would fail with
    ##   TypeError: can't convert ActiveSupport::TimeWithZone into an exact number

    t.error = start_time_err
    t.error &&= t.error.second 
    t
  end


  # See {#string_time_err2uptomin} for detail.
  #
  # Used in Event and EventItem.
  #
  # @return [String] formatted String of Date-Time
  def string_time_err2uptomin(time=start_app_time, langcode: I18n.locale)
    time_err2uptomin(time, langcode: langcode)
  end

  # Returns String Array from ojbect Array, with formating
  #
  # nil is converted to String +fallback+
  #
  # @param arstr [Array<Object>]
  # @return [Array<String>]
  def _arstr_sprintf_int(arobj, fmt: "%02d", fallback: "??")
    arobj.map{|i| (i ? sprintf(fmt, i) : fallback)}
  end
  private :_arstr_sprintf_int

  # Returns HTML <a> string from a root string like either '"w.wiki/3JVi' or 'http://w.wiki/3JVi'
  #
  # Calling Rails link_to internally
  #
  # @param label_str [String] HTML label
  #    You may run "label_str.html_safe" before passing it to this method.
  # @param root_str [String]
  # @param opts: [Hash] passed to link_to
  # @return [String, NilClass]
  def link_to_from_root_str(label_str, root_str, **opts)
    return nil if root_str.blank?
    http = root_str.sub(%r@\A(https?://)?@, 'https://')
    ActionController::Base.helpers.link_to label_str, http, **opts
  end


  # Guess the Sex from the name
  #
  # If an Array (of the candidate String) is given,
  # this returns the male or female as soon as it identifies one,
  # and else returns :unknown.
  # In other words, this method does not care even if the given array
  # contains potentially some contradictions like ['Mary', 'Bob'],
  # in which case :female {Sex} is returned.
  #
  # @param instr [String, Array<String>]
  # @return [Sex]
  def guess_sex(instr)
    [instr].flatten.each do |es|
      case es.strip.split[0]
      when /\A(?:Claire|Diana|Elizabeth|Helen|Joanna|Linda|Lucy|Mary|Paula|Sarah?)\b/i
        return Sex[:female] # (iso5218: 2)
      when /\A(?:Adam|Alan|Andrew|Bob|Dick|Graham|Ian|James|Jim|John|Paul|Robert|Simon|William)\b/i
        return Sex[:male]   # (iso5218: 1)
      end

      case es.strip
      when /[子美]恵?\z/
        return Sex[:female]
      when /[夫雄男豪剛太郎朗一二]\z/
        return Sex[:male]
      end
    end

    Sex[:unknown] # (iso5218: 0)
  end


  # Guess the place to be somewhere in Japan from the name
  #
  # @param instr [String]
  # @return [String] "ja" or "en"
  def guess_japan_from_char(instr)
    country = ((guess_lang_code(instr || '') == 'ja') ? 'JPN' : nil)
    Place.unknown(country: country)
  end

  # Guess the langcode based on the character code
  #
  # Note that Zenkaku numbers and some symbols (like parentheses)
  # are converted into ASCII before the judgement.
  #
  # @param instr [String]
  # @return [String] "ja" or "en"
  def guess_lang_code(instr)
    match_kanji_kana(zenkaku_to_ascii(instr || "", Z: 1)) ? 'ja' : 'en'
  end

  # Standard preprocess method of an input, mainly for {Translation}
  #
  # Similar to {#any_zenkaku_to_ascii} but combine SlimString
  # to strip extra spaces. Note that in default any newlines are converted
  # into spaces, i.e., {convert_spaces: false}, unlike the default SlimString,
  # meaning "abc \n def" becomes "abc def", for example.
  # To preserve newlines, call this like:
  #   preprocess_space_zenkaku(
  #     instr,
  #     **(COMMON_DEF_SLIM_OPTIONS.merge({convert_spaces: false})))
  #
  # This is similar to {#any_zenkaku_to_ascii} and a wrapper of
  # {#zenkaku_to_ascii}.
  #
  # The argument can be any Object. If it is not String,
  # it is returned unmodified.
  #
  # If the second argument is given and TrueClass, a definite article
  # in inobj is moved to the tail. Else, not.
  # See {Translation.get_article_to_tail} for detail.
  #
  # The optional arguments are passed to {SlimString.slim_string}
  #
  # @param inobj [Object] If not String, it is returned as it is.
  # @param article_to_tail [Boolean] If true, the definite article, if exists, is moved to the tail.
  # @param sym_level: [Symbol] Option to pass to {#converted_ja_chars}
  # @param mappings: [Hash] Option to pass to {#converted_ja_chars}
  # @param strip_all: [Boolean] If true (Def: false), the head and tail are stripped and also multiple consecutive spaces in the middle are also (agressively) truncated.  This is probably desirable for a short title like a person's name but maybe unsuitable for a long text.
  # @param opts: [Hash] Options to pass to {SlimString.slim_string}. See above.
  # @return [Object] If String, {String#preprocessed} is set to true.
  def preprocess_space_zenkaku(inobj, article_to_tail=false, sym_level: :standard, mappings: {}, strip_all: false, **opts)
    return inobj if !inobj.respond_to? :gsub

    newopts = COMMON_DEF_SLIM_OPTIONS.merge opts
    ret = zenkaku_to_ascii(SlimString.slim_string(inobj, **newopts), Z: 1)
    ret = converted_ja_chars(ret, sym_level: sym_level, mappings: mappings, zenkaku_to_ascii: false)
    ret = (article_to_tail ? definite_article_to_tail(ret) : ret)
    if strip_all
      ret.strip!
      ret.gsub!(/\s+/m, " ")
    end
    ret
  end

  # Returns root and definite article, e.g., ["Beatles", "The"], ["Queen", ""]
  #
  # Assumes the DB entry-style, namely the article comes at the tail.
  #
  # @param instr [String]
  # @return [String] never includes nil
  def partition_root_article(instr)
    mat = /,\s+(#{DEFINITE_ARTICLES_REGEXP_STR})\Z/i.match instr  # In the DB, a space follows a comma!
    mat ? [mat.pre_match, mat[1]] : [instr, ""]
  end

  # Returns a string without a definite article
  #
  # The article may be at the head or tail.
  #
  # String is assumed to have been already stripped.
  #
  # @param instr [String]
  # @return [String]
  def definite_article_stripped(instr)
    instr.sub(/\A(#{DEFINITE_ARTICLES_REGEXP_STR})\b\s*(\S)/i, '\2').sub(/,\s*(#{DEFINITE_ARTICLES_REGEXP_STR})\Z/i, '')
  end

  # Move a definite article to the head
  #
  # In the DB entry, the definite article is placed at the tail.
  # This routine returns the string in the "normal" order.
  #
  # String is assumed to have been already stripped.
  # A space between the final comma and an article is not mandatory.
  #
  # If nil is given, returns nil.
  #
  # @example
  #   definite_article_to_head("Beatles, The") # => "The Beatles"
  #
  # @param instr [String, NilClass]
  # @return [String, NilClass]
  def definite_article_to_head(instr)
    return instr if !instr
    instr.sub(/\A(.+),\s*(#{DEFINITE_ARTICLES_REGEXP_STR})\z/i){$2+" "+$1}
  end

  # Move a definite article to the tail
  #
  # String is assumed to have been already stripped.
  #
  # If an article is already at the tail, the spaces (or no spaces)
  # before the article are unchanged; e.g.,  "ab,  the" => "ab,  the".
  #
  # @example
  #   definite_article_to_tail("The Beatles") # => "Beatles, The"
  #
  # @example not doubly moved to the tail.
  #   definite_article_to_tail("the abc, La") # => "the abc, La"
  #
  # @param instr [String]
  # @return [String]
  def definite_article_to_tail(instr)
    return instr if /\A(.+),\s*(#{DEFINITE_ARTICLES_REGEXP_STR})\z/i =~ instr
    instr.sub(/\A(#{DEFINITE_ARTICLES_REGEXP_STR})\b\s*(\S.*)/i){$2+", "+$1}
  end

  # Returns matching Regexp for DB and root-part of user-string
  #
  # String is 
  #
  # Return is as follows:
  # The 1st element is Regexp to suit the Regexp in DB.
  # The 2nd element is String in the format of String in DB,
  # namely, the article part comes at the tail.
  # The 3rd element is the article in the user string (maybe an empty String).
  #
  # Basically, we consider either or neither or both of the
  # user string and DB String have a definite article.
  #
  # To reproduce the DB-formated String (with the article
  # placed at the tail: ret[1]+", "+ret[2]
  #
  # @note The input String is assumed to be UTF-8 normalized and
  #   UTF-8 space characters are normalized to ASCII spaces
  #   AND all those whitespace characters are assumed to have been
  #   already stripped; i.e.,
  #   Zenkaku-Spaces (+\u3000) etc are not recognized as spaces
  #   and hence, for example, "abc,\u3000 The" is interpreted as
  #   a string without an article.
  #
  # @example With a definite article
  #   definite_article_with_or_not_at_tail_regexp("tHe Beatles")
  #   # => [/\A(Beatles)(,\s*(tHe))?\z/i, "Beatles", "tHe"]
  #
  # @example With no definite article
  #   definite_article_with_or_not_at_tail_regexp("Beatles")
  #   # => [/\A(Beatles)(,\s*((?:the|l'|le|les|el|los|las|lo|der|das|des|dem|den|la(?! +la +))\b))?\z/i, 'Beatles', ""]
  #
  # @param instr [String]
  # @return [Array<Regexp, String, String>] Regexp to match DB, root-String, article-String
  def definite_article_with_or_not_at_tail_regexp(instr)
    mat1 = /\A(#{DEFINITE_ARTICLES_REGEXP_STR})\b\s*(\S.*)\z/i.match instr
    mat2 = /\A(.+),\s*(#{DEFINITE_ARTICLES_REGEXP_STR})\z/i.match instr
    ret3 = (mat1 && mat1[1] || mat2 && mat2[2] || "")
    ret2 = (mat1 && mat1[2] || mat2 && mat2[1] || instr)
    ret1 = (ret3.empty? ? /\A(#{Regexp.quote ret2})(,\s*(#{DEFINITE_ARTICLES_REGEXP_STR}))?\z/i : /\A(#{Regexp.quote ret2})(,\s*(#{ret3}))?\z/i)
    [ret1, ret2, ret3]
  end

  # Method to convert strange Japanise characters to standard ones
  #
  # This is a wrapper for {#zenkaku_to_ascii} and more.
  # Note {#zenkaku_to_ascii} is not called if :zenkaku_to_ascii is given false.
  #
  # For example, in default, this converts a FULLWIDTH TILDE (\uFF5E),
  # a SJIS-specific character, to a wave dash (\u301C), the original JIS
  # character.
  #
  # The conversion rule It is defined in {ModuleCommon::JA_CHAR_MAPPINGS}
  # but you can overwrite any of the components in the argument.
  #
  # Unfortunately NKF does not handle emojis very well.
  # So, this routine excludes emoji parts during processing,
  # and recover (i.e., concat) the whole string in the end.
  #
  # @example
  #   convert_ja_chars("（あ）～", Z: 1)  # => '(あ)〜'
  #
  # @param instr [String] input String
  # @param sym_level [Symbol] One of :conservative, :standard (Default), :aggressive
  # @param zenkaku_to_ascii [Boolean] if false (Def: true), {#zenkaku_to_ascii} is not called.
  # @param mappings [Hash<Hash<Array<String>>>] Def: {ModuleCommon::JA_CHAR_MAPPINGS}
  # @param opts [Hash] passed to {#zenkaku_to_ascii}
  # @return [String] String where dubious characters are replaced with standard ones.
  def converted_ja_chars(instr, sym_level: :standard, mappings: {}, zenkaku_to_ascii: true, **opts)
    mappings = JA_CHAR_MAPPINGS.merge(mappings || {})
    ret = instr.clone
    mappings.each_key do |dest_char|
      ary_char = chars_ja_char_mappings(dest_char, sym_level: sym_level.to_sym, mappings: mappings)
      next if ary_char.blank?
      ary_char.each do |ec|
        ret.tr!(ec, dest_char)
      end
    end
    ret = zenkaku_to_ascii(ret, **opts) if zenkaku_to_ascii
    ret
  end

  # @param skey [String] (usually a single) destination character
  # @param sym_level [Symbol] One of :conservative, :standard (Default), :aggressive
  # @param mappings [Hash<Hash<Array<String>>>] Def: {ModuleCommon::JA_CHAR_MAPPINGS}
  # @return [Array, NilClass] Always Array of characters (maybe empty), unless skey is invalid.
  def chars_ja_char_mappings(skey, sym_level: :standard, mappings: JA_CHAR_MAPPINGS)
    return nil if !mappings[skey]
    [sym_level, :standard, :conservative, :aggressive].uniq.compact.each do |ek|
      ar = mappings[skey][ek]
      return ar if ar.respond_to?(:flatten)
    end
    []
  end

  # Wrapper of {#zenkaku_to_ascii} with :Z=>1, accepting any Object as the input.
  #
  # String is also strip-ped.
  #
  # @param inobj [Object]
  # @return [Object]
  def any_zenkaku_to_ascii(inobj)
    if inobj.respond_to? :gsub
      zenkaku_to_ascii(inobj, Z: 1).strip
    else
      inobj
    end
  end

  # Method to convert Zenkaku alphabet/number/symbol to Hankaku.
  #
  # A JIS space is converted to 2 ASCII spaces in default (option :Z == 2).
  # The other NKF options should be given as the option keyword: :nkfopt
  #
  # Unfortunately NKF does not handle emojis very well.
  # So, this routine excludes emoji parts during processing,
  # and recover (i.e., concat) the whole string in the end.
  #
  # @example
  #   zenkaku_to_ascii('（あ）', Z: 1)  # => '(あ)'
  #
  # @param instr [String]
  # @return [String]
  def zenkaku_to_ascii(instr, **opts)
    if !instr
      raise TypeError, "(#{__method__}) Given string is nil but it has to be a String."
    end
    opts = _getNkfRelatedOptions(opts)
    z_spaces = (opts[:Z] || 2)

    if /(^| )-[jesw]/ !~ opts[:nkfopt]
      # Without "-W", "ComtéInconnu" would become "Comt辿Inconnu"
      opts[:nkfopt] = ("-w -W "+opts[:nkfopt]).strip
    end

    instr.split(/(\p{So}+)/).map.with_index{|es, i|
      i.odd? ? es : NKF.nkf("-m0 -Z#{z_spaces}} #{opts[:nkfopt]}", es)   # [-Z2] Convert a JIS X0208 space to 2 ASCII spaces, as well as Zenkaku alphabet/number/symbol to Hankaku.
    }.join
  end

  # @return [MatchData, NilClass] of the first sequence of kanji, kana (zenkaku/hankaku), but NOT zenkaku-punct
  def match_kanji_kana(instr)
    /(?:\p{Hiragana}|\p{Katakana}|[ー−]|[一-龠々｡-ﾟ])+/ =~ instr
  end

  # @return [MatchData, NilClass] of the first sequence of hankaku-kana. nil if no match.
  def match_hankaku_kana(instr)
    /[｡-ﾟ]+/.match instr  # [\uff61-\uff9f]
  end

  # True if String contains a definite Asian character.
  #
  # Most punctuations are not considered.
  #
  # @param instr [String]
  def contain_asian_char?(instr)
    !!contained_asian_chars(instr)
  end

  # Returns the matched (first) Asian characters in the String.
  #
  # @param instr [String]
  # @return [MatchData, NilClass] if non-nil, returned[0] is the matched String.
  def contained_asian_chars(instr)
    /(\p{Hiragana}|\p{Katakana}|[ー、。]|[一-龠々])+/.match instr # Most punctuations are not considered.
  end

  # True if String contains a kanji character.
  #
  # @param instr [String]
  def contain_kanji?(instr)
    !!contained_kanjis(instr)
  end

  # Returns the matched (first) kanji characters in the String.
  #
  # kanji/漢字 <https://easyramble.com/japanese-regex-with-ruby-oniguruma.html>
  #
  # @see https://qiita.com/Takayuki_Nakano/items/8d38beaddb84b488d683
  # @see https://github.com/k-takata/Onigmo/blob/master/doc/UnicodeProps.txt
  #
  # @param instr [String]
  # @return [MatchData, NilClass] if non-nil, returned[0] is the matched String. returned[0][0] is the first character.
  def contained_kanjis(instr)
    #/([一-龠々])+/.match instr
    /(\p{Han}+)/.match instr
  end

  # Returns Hash of {abc: 1, def: 1, ghi: 3, jkl: 4}
  #
  # The values indicate the number in the ordered list.
  #
  # @example
  #   number_ordered_keys({ghi: 'G', jkl: 'J', abc: nil, def: nil, mno: 'G'})
  #    # => {abc: 1, def: 1, ghi: 3, mno: 3, jkl: 5}
  #
  # @param hs [Hash]
  # @param nil_is_minimum [Boolean] if true (Def), nil is treated as the minimum.
  #   Similar to the PostgreSQL "NULLS FIRST" (though the behaviour in the reverse
  #   order may differ).
  # @param reverse [Boolean] if true (Def: false), sort in the reversed order (maximum first).
  # @return [Hash] keys are the same as the input, but the values are numbers.
  def number_ordered_keys(hs, nil_is_minimum: true, reverse: false)
    f_nil     = (nil_is_minimum ? 1 : -1)
    f_reverse = (reverse ? -1 : 1)
    ar2 = hs.to_a.sort{|a,b|
      if a[1].nil? && b[1].nil?
        0
      elsif a[1].nil?
        -1 * f_nil * f_reverse
      elsif b[1].nil?
         1 * f_nil * f_reverse
      else
        (a[1] <=> b[1]) * f_reverse
      end
    }
    ar2.each_with_index{|ea, i|
      if (i != 0) && ((ea[1] <=> ar2[i-1][1]) == 0)
        ea.push(ar2[i-1][2])
      else
        ea.push(i+1)
      end
    }
    ar2.map{|i| [i[0], i[2]]}.to_h
  end

  # @param kind [String] Key for {ModuleCommon::ERR_MSG_FMT_COMMON} 
  # @param *args [Array<String>] Parameters
  # @return [String]
  def get_err_msg(kind, *args)
    sprintf(ERR_MSG_FMT_COMMON[kind], *args) 
  end

  # @param kind [String] Key for {ModuleCommon::ERR_MSG_FMT_COMMON} 
  # @param *args [Array<String>] Parameters
  # @return [String]
  def raise_with_msg(kind, *args)
    raise ERR_CLASS_SEND_COMMON[kind], get_err_msg(kind, *(args+['']*10))
  end

  # Returns a Wikipedia URI for the specified language
  #
  # Based on the attributes of wiki_ja or wiki_en
  #
  # @param langcode [String] e.g., 'ja'
  # @return [String, NilClass] nil if not defined
  # @raise [NoMethodError] if "wiki_ja" etc is not defined in the model class
  def wiki_uri(langcode)
    main = public_send('wiki_'+langcode)
    main.blank? ? nil : get_wiki_uri(langcode, main)
  end

  # Returns a Wikipedia URI for the specified language
  #
  # Note that wiki_en may already contain a Spanish or German link etc.
  # In that case, langcode is ignored.
  #
  # @param langcode [String] e.g., 'ja'
  # @param term [String] e.g., 'w.wiki/3cyo', 'Kohmi_Hirose'
  # @return [String] e.g., 'https://w.wiki/3cyo', 'https://en.wikipedia.org/wiki/Kohmi_Hirose'
  def get_wiki_uri(langcode, term)
    return term if %r@\Ahttps?://@ =~ term
    return 'https://'+term if %r@\A[a-z]{2}\.wikipedia\.org/@ =~ term
    'https://' + ((%r(\.wiki/) =~ term) ? "" : langcode + '.wikipedia.org/wiki/') + term
  end
  private :get_wiki_uri

  # Removes the beginning and/or end of String constraint in Regexp
  #
  # Considers '\A', '^', '$', '\Z', '\z'
  # Only the simple cases are handled; e.g., /(\A|abc)/ would not be.
  #
  # @example
  #   remove_az_from_regexp(/\Axyz?$/i)  # => /xyz?/i
  #
  # @param re [Regexp]
  # @return [Regexp]
  def remove_az_from_regexp(re, remove_first: true, remove_last: true)
    str_re   = re.source
    str_opts = re.options
    str_re.sub!(/\A(?:\\A|\^)/, '')  if remove_first
    str_re.sub!(/(?:\\[Zz]|\$)/, '') if remove_last

    Regexp.new str_re, str_opts
  end

  # Returns a 2-element Array of String of begin/end HTML tags
  #
  # The returned array consists of Arrays of the begin and end tags.
  #
  # @example
  #   get_pair_tags_from_css('div.entry-content table tr')
  #    # => ["<div class=\"entry-content\">\n<table>\n<tr>",
  #    #     "</tr>\n</table>\n</div>"]
  #
  # This handles only ID and class selectors aprt from the Tag selector!!
  #
  # @param str_css [String] e.g., 'div.entry-content table tr'
  # @return [Array<String, String>]
  def get_pair_tags_from_css(str_css)
    arret = [[], []]
    str_css.split.each do |css|
      beg, fin = get_pair_tags_from_a_css(css)
      arret[0] << beg
      arret[1].unshift fin
    end
    arret.map{|i| i.join("\n")}
  end

  # Core routine of {#get_pair_tags_from_css} to handle just 1 tag
  #
  # Returned (Array of) String does not contain nuewlines.
  #
  # @example
  #   get_pair_tags_from_a_css('div.entry-content')
  #    # => ["<div class=\"entry-content\">", "</div>"]
  #
  # This handles only ID and class selectors aprt from the Tag selector!!
  #
  # @param css [String] A single element Tag&Attr-selector, e.g., 'div.entry-content'
  # @return [Array<String, String>]
  def get_pair_tags_from_a_css(css)
    css_split = css.split(/([\.#])/)
    hsattr = { id: [], klass: [] }
    next_attr = nil
    css_split[1..-1].each do |ec|
      case ec
      when '#'
        next_attr = :id
      when '.'
        next_attr = :klass
      else
        hsattr[next_attr] << ec
      end
    end

    if hsattr[:id].size > 1
      msg = "More than one id is specified for a tag in a CSS selector: #{css.inspect}"
      logger.warn msg
      warn  msg
    end

    s_beg = "<" +
            css_split[0] +
            (hsattr[:id].empty? ? '' : sprintf(' id="%s"', hsattr[:id][0])) + 
            (hsattr[:klass].empty? ? '' : sprintf(' class="%s"', hsattr[:klass].join(" "))) + 
            ">"

    [s_beg, "</"+css_split[0]+">"]
  end
  private :get_pair_tags_from_a_css

  # Split a Hash for the given set of keys
  #
  # @example
  #   hs = {a: 12, b: 34, c: 56, d: 78, e: 90}
  #   split_hash_with_keys(hs, %i(b d))
  #   # => [{b: 34, d: 78}, {a: 12, c: 56, e: 90}]
  #
  # @param inhash [Hash]
  # @param arkey [Array] Array of keys to separate from inhash. This may include non-existent keys.
  # @return [Array<Hash, Hash>] 1st element is Hash with the keys contained in arkey, the 2nd is the rest.
  # @raise [NoMethodError] if inhash is nil or not Hash
  def split_hash_with_keys(inhash, arkey)
    [inhash.select{|k,_|  arkey.include? k}.to_h,
     inhash.select{|k,_| !arkey.include? k}.to_h]
  end
  private :split_hash_with_keys

  # Similar to `find_or_create_by!` but update instead of find
  #
  # This method accepts all the parameters to update/create, together
  # with the keywords to get a potential existing one, and also accepts
  # a block, where {ApplicationRecord} is passed as the parameter.
  #
  # There is a chance the record to save is {#invalid?}
  # mainly because the given parameter combination is invalid, but potentially
  # because a competing process writes a record in between the process.
  # In this case, if the optional key-value Hash +if_needed+ is given,
  # the key-value pairs are inserted to the record before {#save!}.
  #
  # If the {#save!} still raises an Exception,
  # the DB rollbacks and the standard exception is raised.
  #
  # After the first {#save!} (which updates +updated_at+ as long as
  # there are any changes), if a block is given, {ApplicationRecord}
  # is passed as the parameter, and the record can be further modified
  # in the block (n.b., the return value of the block is simply discarded)
  # and then it {#save!}+(touch: false)+; i.e., any change inside the block
  # would not affect +updated_at+ of the record
  # (obviously, a caller could save the record or explicitly change +updated_at+
  #  inside the block if they dared).
  #
  # If an Exception is raised, complete rollback is guaranteed.
  # Otherwise, the new record (not reloaded, but id and updated_at are filled)
  # is returned.
  #
  # == Workflow summary
  #
  # 1. An (maybe first?) existing record having +uniques+ is identified.
  #    1. If not found, a new record is created (not yet saved).
  # 2. The record is updated according to +prms+
  # 3. If the record is invalid, the record is further modified according to +if_needed+ is given.
  # 4. {#save!}.
  #    1. If still fails, (usually; i.e., +if record.changed?+) this raises an Exception, with rollback.
  # 5. If +block_given?+, the record is passed to the block.
  #    1. {#save!}+(touch: false)+ (i.e., `updated_at+ unchanges)
  #    2. If the save fails, raises an Exception accordingly (with complete rollback)
  # 6. Returns the record
  #
  # See @example below for a working example.
  #
  # == Use
  #
  # Use by extend-ing it in the class.
  #   extend ModuleCommon
  #
  # Then you can use it like
  #   model = MyModel.update_or_create_by_with_notouch! prms, [:id_unique1, :id_unique2]
  #   model.saved_change_to_updated_at?  # => true/false
  #
  # Note the following returns false always if a block is given:
  #   model.saved_change_to_created_at?
  #
  # @example
  #   prms = {id_unique1: 5, id_unique2: 8, singer: 'Beatles', song: 'Yesterday'}
  #   MyModel.update_or_create_by_with_notouch!(prms, [:id_unique1, :id_unique2]){ |record|
  #     record.inserted_at = (record.saved_change_to_updated_at? ? record.updated_at : Time.now)
  #   }
  #   # Creates or updates a record that has a unique key combination of
  #   # {id_unique1: 5, id_unique2: 8} with the singer and song columns.
  #   # If they are different from an existing one, updated_at is updated
  #   # and the value is copied to inserted_at.  If not, updated_at unchanges,
  #   # while inserted_at is set at Time.now
  #
  # @param prms [Hash] The data to insert
  # @param uniques [Symbol, Array] Unique key words to find an existing record
  # @param if_needed: [Hash] Hash of Key=>Value to rescue an invalid save.
  # @return [ActiveRecord] nil if failed. Otherwise {Harami1129} instance (you need to "reload")
  # @raise [ActiveRecord::RecordInvalid, ActiveModel::UnknownAttributeError] etc
  def update_or_create_by_with_notouch!(prms, uniques, if_needed: {})
    unique_opts, new_opts = split_hash_with_keys(prms, [uniques].flatten)

    record = find_or_initialize_by(**unique_opts)

    err = nil
    ActiveRecord::Base.transaction(requires_new: true) do
      begin
        if !new_opts.empty?
          begin
            # upd = (record.updated_at || Time.new(0))
            new_opts.each_pair do |att, v|
              record.send(att.to_s+'=', v) # NoMethodError is raised if the key in the given prms is inappropriate for the model
            end
            if record.invalid?
              if_needed.each_pair do |att, v|
                record.send(att.to_s+'=', v) # NoMethodError is raised if the key in the given if_needed is inappropriate for the model
              end
            end
            # record.update!(**new_opts)  # Ruby 3.0 would raise ArgumentError if empty?
            record.save!
          rescue ActiveRecord::RecordInvalid
            raise if record.changed?  # no update if record unchanged
          end
        end
        if block_given?
          yield record #, upd
          record.save!(touch: false) if record.changed?
        end
      rescue => err
        raise ActiveRecord::Rollback, "Force rollback."
      end
    end

    raise err if err  # StandardError raised after all if any error has been raised.
    record
  end
  private :update_or_create_by_with_notouch!

  # Returns the options suitable to be passed to NKF
  #
  # @param opts_in [Hash]
  def _getNkfRelatedOptions(opts_in)
    opts =
      defOpts = {
       :nkfopt => '',
       :encoding_in  => nil,
       :encoding_out => nil
      }.merge(opts_in)

    if opts[:encoding_in]
      opts[:nkfopt] += ' ' + NKF.guessed_option(opts[:encoding_in])
      opts[:nkfopt].strip!
    end

    if opts[:encoding_out]
      opts[:nkfopt] += ' ' + NKF.guessed_option(opts[:encoding_out], :input => false)
      opts[:nkfopt].strip!
    end

    opts
  end
  private :_getNkfRelatedOptions


  # Transfer Errors from "other" model to self
  #
  # @param other [ActiveModel]
  # @param prefix: [String] Prefix for each error message, if any.
  def transfer_errors(other, prefix: '')
    #other.errors.group_by_attribute.each_pair do |ek, ea_errs|
    other.errors.messages.each_pair do |ek, ea_messages|
      # ek: Error_Type(e.g., :title), ea_err: Array[<ActiveModel::Errors>, ...]
      next if !ea_messages  # Should not be needed, but play safe.
      ea_messages.each do |message|
        errors.add ek, prefix+message
      end
    end
  end

  # Returns 2-element Array of PostgreSQL Regexp String and Options converted from Ruby Regexp
  #
  # In PostgreSQL, *ARE* (Advanced Regexp) is assumed to be used in default.
  #
  # An important point is the behaviour of +Regexp::MULTILINE+ is very different!
  # There is no option in Ruby corresponding to the PostgreSQL default ("s").
  # Ruby Regexp **without** +Regexp::MULTILINE+ (Ruby Default) is
  # PostgreSQL "n" (=non-newline-sensitive; alias is "m") option, whereas the Ruby with "m" is
  # PostgreSQL "w" (=weird!) option.
  # PostgreSQL has another "p" option (which Ruby does not have), which is the reverse of "w".
  #
  # == Experimental
  #
  # Ruby-specific expressions are not supported. Note +\z+ in Ruby is equivalent to
  # +\Z+ in PostgreSQL and +\Z+ in Ruby has no simple counterpart in PostgreSQL.
  # However, +\z+ and +\Z+ are converted in most cases (I think
  # they cover almost all cases, unless they are used in a lookahead/lookbehind feature?).
  #
  # == Most important points that this method handles.
  #
  # * Supported
  #   * Regexp options: "i", "m" (=> "w")
  #   * \n, \&, \1, "^", "\A", "\Z" (NOTE: \z should be OK in most cases, but not 100% (see above))
  #   * lazy match (except "{,m}?"), \b (=> \y), \B (=> \Y), [:alnum:], \w, \W, [:blank:], [:space:]
  #   * lookahead:   "(?=re)",  "(?!re)"
  # * Unsupported
  #   * lookabehind: "(?<=re)", "(?<!re)"
  #   * "\z"
  #   * [:word:], [:ascii:]
  #   * named captures
  #   * \p{...}
  #
  # == Reference
  #
  # Best gist for comparison: https://gist.github.com/glv/24bedd7d39f16a762528d7b30e366aa7
  #
  # @return [Array<String, String>] Regexp.to_s, Option-String for PostgreSQL
  def regexp_ruby_to_postgres(regex)
    mat = /\A\(\?([a-z]*)(?:\-([a-z]*))?:(.+)\)\z/.match regex.to_s # separate Regexp options and contents.
    raise "Contact the code developer: regex=#{regex.inspect}" if !mat # sanity check
    opts = ""
    opts << ?i if  mat[1].include? ?i
    opts << ((mat[1].include?(?m)) ? ?w : ?n)  # the meanings are very different!
    opts << ?x if  mat[1].include? ?x
    restr = mat[3].gsub(/(?<!\\)((?:\\\\)*)(\\)z/, '\1'+"\uFFFD").  # \z => \uFFFD
                   gsub(/(?<!\\)((?:\\\\)*)(\\)Z/, '\1\s*\2Z').     # \Z => \Z ish
                   gsub(/\uFFFD/, '\Z').                            # original(\z) => \Z
                   gsub(/(?<!\\)((?:\\\\)*)\[((?:(?<!\\)(?:\\\\)*(?:\\)\]|[^\]])*)(?<!\\)((?:\\\\)*)(\\)b/, '\1[\2\3'+"\uFFFD").  # [qq\b_] => [qq\uFFFD_];  \[aa\b\_] remains.
                   gsub(/(?<!\\)((?:\\\\)*)(\\)b/, '\1\y').  # other(\b) => \y
                   gsub(/\uFFFD/, '\b')  # replaces back [\b] (i.e., \b inside Range)
    return [restr, opts] 
  end

  # Returns a reversed Hash for the given Array
  #
  # Keyas a content points to the index of the Array.
  # The caller must make sure there are no duplicates in the elements of the Array.
  #
  # @param ary [Array]
  # @return [Hash]
  def array_to_hash(ary)
    ary.map.with_index{|v, i| [v, i]}.to_h
  end

  # Returns "'abc'" or "nil"
  #
  # @param s [String]
  # @return [String]
  def single_quoted_or_str_nil(s)
    s ? s.inspect.sub(/\A"(.*)"\z/, "'"+'\1'+"'") : s.inspect
  end

  # Returns "(Bond Street < London (UK))"
  #
  # @param place [Place]
  # @return [String]
  def inspect_place_helper(str)
    return "" if place.blank?

    s_pla = (place.title_or_alt(str_fallback: "") rescue "")
    s_pref = (place.prefecture.title_or_alt(str_fallback: "") rescue "")
    s_country = ((cnt=place.country; ((s=cnt.iso3166_a3_code).blank? ? s.title : s)) rescue "")
    sprintf("(%s < %s (%s))", s_pla, s_pref, s_country)
  end

  # Routine to add {Translation} information to the String of inspect
  # @param retstr [String] Output String of the default +inspect+
  # @param models [Array<String>] e.g., %w(music, artist)
  def add_trans_info(retstr, models)
    models.each do |ek|
      mdl = self.send(ek)
      tit = 
        if !mdl.respond_to?(:title_or_alt)
          "nil"
        elsif "engage_how" == ek
          mdl.title_or_alt(langcode: "en")
        else
          mdl.title_or_alt
        end
      retstr = retstr.sub(/, #{ek}_id: \d+/,  '\0'+sprintf("(%s)", tit))
    end
    retstr
  end

  # Converts the given date to Time at midday on the day in UTC
  #
  # @param date [Date]
  # @return [Time]
  def convert_date_to_midday_utc(date)
    date.to_time(:utc) + 12.hours # midday in UTC/GMT
  end

  # Returns a String of (minute|hour|day) as the optimum unit from the given second.
  #
  # The latter two are expected to be set in the argument +record+
  #
  # @param second [Numeric, String]
  # @return [String, Nilclass] nil if nil is given.
  def get_optimum_timu_unit(second)
    return if second.blank?
    second = second.to_f
    if second < 3600
      "minute"
    elsif second <= 129600  # 36 hours
      "hour"
    else
      "day"
    end
  end

  # set start_time_err from form_start_err and form_start_err_unit
  #
  # The latter two are expected to be set in the argument +record+
  #
  # @param record [ApplicationRecord] instance variable like @event_item
  # @param with_model: [Boolean] If true (Default), the main argument is ApplicationRecord and is for create; else it is Hash @hsmain for update (set in set_hsparams_main in application_controller.rb)
  #   +with_model+ should be true for create and false for update.
  #   If +with_model+ is true (Def), the value is set for the model.
  # @return [Float, Nilclass] The error value
  def set_start_err_from_form(mdl_or_hs, with_model: true)
    err_raw, unit = (with_model ? [mdl_or_hs.form_start_err, mdl_or_hs.form_start_err_unit] : [mdl_or_hs["form_start_err"], mdl_or_hs["form_start_err_unit"]])
    return if err_raw.blank?

    factor = (_form_start_err_factor(unit) || 1)
    err_val = err_raw.to_f * factor
    mdl_or_hs.start_time_err = err_val if with_model  # for :create
    err_val
  end

  # set form_start_err and form_start_err_unit for a form
  #
  # Each class should define the constant DEF_FORM_TIME_ERR_UNIT (=="day"?)
  #
  # @param record [ApplicationRecord] instance variable like @event_item
  def set_form_start_err(record)
    return if record.start_time_err.present?

    if record.form_start_err_unit.blank?
      record.form_start_err_unit = 
        if self.class.const_defined?(:DEF_FORM_TIME_ERR_UNIT)
          self.class::DEF_FORM_TIME_ERR_UNIT
        else
          ApplicationController::DEF_FORM_TIME_ERR_UNIT
        end
    end

    record.form_start_err = (record.start_time_err ? record.start_time_err.quo(
      _form_start_err_factor(record.form_start_err_unit)
    ) : nil)
  end

  # @param kwd [String] unit for the error (of start time)
  # @return [Integer, NilClass] nil if kwd is blank.
  def _form_start_err_factor(kwd)
    case (kwd || ApplicationController::DEF_FORM_TIME_ERR_UNIT)
    when "minute"
      60
    when "hour"
      3600
    when "day"
      86400  # 3600*24
    else
      raise "Wrong kwd: #{kwd.inspect}"
    end
  end
  private :_form_start_err_factor

  # Returns Float, Integer, nil converted from String or anything else as it is
  #
  # This returns nil if blank?
  #
  # @param str [String, Object] Perhaps from Web interface
  # @return [String]
  def convert_str_to_number_nil(str)
    str = str.presence
    return str if !str.respond_to?(:gsub)  # nil may be returned
    str.strip!

    if /\A([+\-]?((0|[1-9][\d_]*)?\.[0-9][\d_]*|(0|[1-9][\d_]*)\.?)([Ee][+\-]?\d[\d_]*)?)\z/ =~ str
      if /\A[+\-]?[\d_]+\z/ =~ str
        str.to_i  # Integer
      else
        str.to_f  # Float
      end
    else
      str         # String
    end
  end

  # Define singleton accessor method to an Object with an initil value
  #
  # @example
  #    art = Artist.new
  #    art.set_singleton_method_val(:lcode, "en")  # defined in module_common.rb
  #    art.lcode  # => "en"
  #    art.lcode="ja"
  #    art.lcode  # => "ja"
  #    set_singleton_method_val(art, :lcode, "fr")  # => "fr", overwritten
  #    art.lcode  # => "fr"
  #    set_singleton_method_val(art, :lcode, "zh", clobber: false)  # => "fr", no change
  #    art.lcode  # => "fr"
  #
  # @example
  #    mus = Music.new
  #    mus.respond_to?(:ary)   # => false (as we assume)
  #    set_singleton_method_val(mus, :ary, [], clobber: false)  # defined in module_common.rb
  #    mus.ary       # => []
  #    mus.ary << 4  # mus.ary==[4]
  #    set_singleton_method_val(mus, :ary, [], clobber: false)  # => [4], not overwritten, equivalent to mus.ary ||= []
  #    mus.ary << 5  # mus.ary==[4, 5]
  #    set_singleton_method_val(mus, :ary, [])                  # => [], overwritten(!) and re-initialized
  #    mus.ary       # => []
  #
  # @example to a random Object
  #    str = "my random object"
  #    str.set_singleton_method_val(:lcode, "en", target: str)  # defined in module_common.rb
  #    str.lcode  # => "en"
  #
  # @param method [String, Symbol] method name to define
  # @option initial_value [Object] Def: nil
  # @param target: [Object]
  # @option clobber: [Boolean] If false (Def: true), the value is not set if the method is already defined.
  #    "clobber: true/false" practically means "obj.method=5" and "obj.method||=5", respectively.
  # @return [Object]  # the value of {Object#metho}, which is usually initial_value unless the method is already defined and clobber=false
  def set_singleton_method_val(method, initial_value=nil, target: self, clobber: true)
    return target.send(method) if !clobber && target.respond_to?(method)
    target.instance_eval{singleton_class.class_eval { attr_accessor method }}
    target.send(method.to_s+"=", initial_value)
    target.send(method)
  end

  # Returns "/db/seeds/users.rb" etc. from __FILE__
  #
  # Used in /db/seeds.rb and /db/seeds/*.rb
  #
  # @example
  #   seed_fname2print(__FILE__)
  #
  # @param fullpath [String] Perhaps give __FILE__
  # @return [String]
  def seed_fname2print(fullpath)
    fullpath.sub(%r@.*(/db/seeds/)@, '\1')
  end
end

