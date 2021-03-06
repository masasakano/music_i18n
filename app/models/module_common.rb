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

  DEFINITE_ARTICLES_REGEXP_STR = DEFINITE_ARTICLES.join '|'


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
      when /[??????]????\z/
        return Sex[:female]
      when /[??????????????????????????????]\z/
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
    match_kanji_kana(zenkaku_to_ascii(instr, Z: 1)) ? 'ja' : 'en'
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
  # @param opts: [Hash] Options to pass to {SlimString.slim_string}. See above.
  # @return [Object] If String, {String#preprocessed} is set to true.
  def preprocess_space_zenkaku(inobj, article_to_tail=false, **opts)
    return inobj if !inobj.respond_to? :gsub

    newopts = COMMON_DEF_SLIM_OPTIONS.merge opts
    ret = zenkaku_to_ascii(SlimString.slim_string(inobj, **newopts), Z: 1)
    ret = (article_to_tail ? definite_article_to_tail(ret) : ret)
    ret
  end

  # Returns root and definite article, e.g., ["Beatles", "The"], ["Queen", ""]
  #
  # Assumes the DB entry-style, namely the article comes at the tail.
  #
  # @param instr [String]
  # @return [String]
  def partition_root_article(instr)
    mat = /,\s+(#{DEFINITE_ARTICLES_REGEXP_STR})\Z/i.match instr
    mat ? [mat.pre_match, mat[1]] : [instr, ""]
  end

  # Returns a string without a definite article
  #
  # The article may be at the head or tail.
  #
  # @param instr [String]
  # @return [String]
  def definite_article_stripped(instr)
    instr.sub(/\A(#{DEFINITE_ARTICLES_REGEXP_STR})\b\s*(\S)/i, '\2').sub(/,\s+(#{DEFINITE_ARTICLES_REGEXP_STR})\Z/i, '')
  end

  # Move a definite article to the head
  #
  # In the DB entry, the definite article is placed at the tail.
  # This routine returns the string in the "normal" order.
  #
  # @example
  #   definite_article_to_head("Beatles, The") # => "The Beatles"
  #
  # @param instr [String]
  # @return [String]
  def definite_article_to_head(instr)
    instr.sub(/\A(.+), (#{DEFINITE_ARTICLES_REGEXP_STR})\z/i){$2+" "+$1}
  end

  # Move a definite article to the tail
  #
  # String is assumed to have been already stripped.
  #
  # @example
  #   definite_article_to_tail("The Beatles") # => "Beatles, The"
  #
  # @param instr [String]
  # @return [String]
  def definite_article_to_tail(instr)
    instr.sub(/\A(#{DEFINITE_ARTICLES_REGEXP_STR})\b\s*(\S.*)/i){$2+", "+$1}
  end

  # Returns matching Regexp for DB and root-part of user-string
  #
  # String is assumed to have been already stripped.
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
  # @example With a definite article
  #   definite_article_with_or_not_at_tail_regexp("tHe Beatles")
  #   # => [/\A(Beatles)(, (tHe))?\z/i, "Beatles, tHe"]
  #
  # @example With no definite article
  #   definite_article_with_or_not_at_tail_regexp("Beatles")
  #   # => [/\A(Beatles)(, (the|le|la|les|el|los|las|lo|der|das|des|dem|den))?\z/i, 'Beatles', ""]
  #
  # @param instr [String]
  # @return [Array<Regexp, String, String>] Regexp to match DB, root-String, article-String
  def definite_article_with_or_not_at_tail_regexp(instr)
    mat1 = /\A(#{DEFINITE_ARTICLES_REGEXP_STR})\b\s*(\S.*)\z/i.match instr
    mat2 = /\A(.+), (#{DEFINITE_ARTICLES_REGEXP_STR})\z/i.match instr
    ret3 = (mat1 && mat1[1] || mat2 && mat2[2] || "")
    ret2 = (mat1 && mat1[2] || mat2 && mat2[1] || instr)
    ret1 = (ret3.empty? ? /\A(#{Regexp.quote ret2})(, (#{DEFINITE_ARTICLES_REGEXP_STR}))?\z/i : /\A(#{Regexp.quote ret2})(, (#{ret3}))?\z/i)
    [ret1, ret2, ret3]
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
  #   zenkaku_to_ascii('?????????', Z: 1)  # => '(???)'
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
      # Without "-W", "Comt??Inconnu" would become "Comt???Inconnu"
      opts[:nkfopt] = ("-w -W "+opts[:nkfopt]).strip
    end

#print "DEBUG(zen00300): "; p opts; p instr.encoding; p instr[0..100]
    instr.split(/(\p{So}+)/).map.with_index{|es, i|
      i.odd? ? es : NKF.nkf("-m0 -Z#{z_spaces}} #{opts[:nkfopt]}", es)   # [-Z2] Convert a JIS X0208 space to 2 ASCII spaces, as well as Zenkaku alphabet/number/symbol to Hankaku.
    }.join
  end

  # @return [MatchData, NilClass] of the first sequence of kanji, kana (zenkaku/hankaku), but NOT zenkaku-punct
  def match_kanji_kana(instr)
    /(?:\p{Hiragana}|\p{Katakana}|[??????]|[???-?????????-???])+/ =~ instr
  end

  # @return [MatchData, NilClass] of the first sequence of hankaku-kana. nil if no match.
  def match_hankaku_kana(instr)
    /[???-???]+/.match instr  # [\uff61-\uff9f]
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
    /(\p{Hiragana}|\p{Katakana}|[?????????]|[???-??????])+/.match instr # Most punctuations are not considered.
  end

  # True if String contains a kanji character.
  #
  # @param instr [String]
  def contain_kanji?(instr)
    !!contained_kanjis(instr)
  end

  # Returns the matched (first) kanji characters in the String.
  #
  # kanji/?????? <https://easyramble.com/japanese-regex-with-ruby-oniguruma.html>
  #
  # @param instr [String]
  # @return [MatchData, NilClass] if non-nil, returned[0] is the matched String.
  def contained_kanjis(instr)
    /([???-??????])+/.match instr
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
  # @param langcode [String] e.g., 'ja'
  # @param term [String] e.g., 'w.wiki/3cyo', 'Kohmi_Hirose'
  # @return [String] e.g., 'https://w.wiki/3cyo', 'https://en.wikipedia.org/wiki/Kohmi_Hirose'
  def get_wiki_uri(langcode, term)
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
  def split_hash_with_keys(inhash, arkey)
    [inhash.select{|k,_|  arkey.include? k}.to_h,
     inhash.select{|k,_| !arkey.include? k}.to_h]
  end
  private :split_hash_with_keys

  # Similar to `find_or_create_by!` but update instead of find
  #
  # This method accepts all the parameters to update/create, together
  # with the keywords to get a potential existing one, and also accepts
  # a block, where {ApplicationRecord} is passed as the parameter,
  # the result of which does not change the updated_at column
  # (though a user could change it inside the block if they dared).
  #
  # There is a chance the final save! raises an Exception,
  # mainly because the given parameters are invalid, but potentially
  # because a competing process writes a record in between the process.
  # If an error is raised, the DB rollbacks and exception is raised.
  #
  # Unless an Exception is raised, the new record (not reloaded, but
  # id and updated_at are filled) is returned.
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
  # @return [ActiveRecord] nil if failed. Otherwise {Harami1129} instance (you need to "reload")
  # @raise [ActiveRecord::RecordInvalid, ActiveModel::UnknownAttributeError] etc
  def update_or_create_by_with_notouch!(prms, uniques, if_needed: {})
    unique_opts, new_opts = split_hash_with_keys(prms, [uniques].flatten)

    record = find_or_initialize_by(**unique_opts)

    err = nil
    ActiveRecord::Base.transaction do
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

    raise err if err
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
end

