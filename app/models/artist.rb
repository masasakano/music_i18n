# coding: utf-8
# == Schema Information
#
# Table name: artists
#
#  id          :bigint           not null, primary key
#  birth_day   :integer
#  birth_month :integer
#  birth_year  :integer
#  note        :text
#  wiki_en     :text
#  wiki_ja     :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  place_id    :bigint           not null
#  sex_id      :bigint           not null
#
# Indexes
#
#  index_artists_birthdate    (birth_year,birth_month,birth_day)
#  index_artists_on_place_id  (place_id)
#  index_artists_on_sex_id    (sex_id)
#
# Foreign Keys
#
#  fk_rails_...  (place_id => places.id)
#  fk_rails_...  (sex_id => sexes.id)
#
class Artist < BaseWithTranslation
  ### NOTE
  # To destroy Artist you may do something like this:
  #
  #  if (chow=art1.channel_owner)
  #    if chow && chow.channels.exists?
  #      chow.channels.each do |ea_ch|
  #        ea_ch.harami_vids.destroy_all if ea_ch.harami_vids.exists?
  #        ea_ch.destroy!
  #      end
  #    end
  #    chow.reload.destroy
  #    chow
  #  end
  #  art1.reload.destroy

  include ModuleUnknown

  # defines +self.class.primary+
  include ModulePrimaryArtist

  # For the translations to be unique (required by BaseWithTranslation).
  MAIN_UNIQUE_COLS = %i(birth_day birth_month birth_year wiki_en wiki_ja place_id sex_id)

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" when "The Beatles" is passed.  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = true

  # callback to make sure place and sex are set if nil.
  # Note calling "valid?" would force self to have a {Place} and {Sex}
  before_validation :add_place_for_validation
  before_validation :add_sex_for_validation

  belongs_to :sex   # Withtout allowing nil, this prohibits nil in validation
  belongs_to :place
  has_one :prefecture, through: :place
  has_one :country, through: :prefecture

  has_many :engages, dependent: :destroy
  has_many :musics, through: :engages
  has_many :harami_vids, through: :musics
  has_many :harami1129s, through: :engages  # Please nullify Harami1129#engage_id before deleting self (for now)

  has_many :artist_music_plays, dependent: :destroy  # dependent is a key
  %i(event_items play_roles instruments).each do |esym|
    has_many esym, -> {distinct}, through: :artist_music_plays
  end
  has_many :play_musics, -> {distinct}, through: :artist_music_plays, source: "music"

  has_one :channel_owner, dependent: :restrict_with_exception  # dependent is a key; by default, optional: true 

  validates :birth_year, numericality: { allow_nil: true, greater_than: 0, message: "(%{value}) must be positive." }
  # ...or validates_numericality_of
  # validates :birth_month, inclusion: { allow_nil: true, within: [1..12], message: "(%{value}) is invalid." }
  validates_inclusion_of :birth_month, within: (1..12), only_integer: true, allow_nil: true, message: "(%{value}) is invalid."
  validates_inclusion_of :birth_day,   within: (1..31), only_integer: true, allow_nil: true, message: "(%{value}) is invalid."
  validate :is_birth_date_valid?
  validate :unique_combination?

  # Default Artist names (titles). Used in {Artist.default}
  DEF_ARTIST_TITLES = %w(ハラミちゃん HARAMIchan Harami-chan)

  UNKNOWN_TITLES = UnknownArtist = {
    "ja" => '不明の音楽家',
    "en" => 'UnknownArtist',
    "fr" => 'ArtisteInconnu',
  }

  # Returns the unknown {Artist} with {Place.unknown} and {Sex.unknown}
  #
  # This has a precedence over the same-name method in ModuleUnknown
  #
  # @return [Artist]
  def self.unknown
    # SELECT translations.id,translations.title,translations.translatable_type,translations.translatable_id,trans2.id as trans2_id,trans2.translatable_type,trans2.translatable_id,trans3.id as trans3_id
    #   FROM translations
    #   INNER JOIN artists ON translations.translatable_id = artists.id
    #   INNER JOIN places ON artists.place_id = places.id
    #   INNER JOIN translations trans2 ON artists.place_id = places.id
    #   INNER JOIN sexes ON artists.sex_id = sexes.id
    #   INNER JOIN translations trans3 ON artists.sex_id = sexes.id
    #   WHERE (artists.place_id = 3414
    #     AND trans2.translatable_type = 'Place' AND trans2.translatable_id = 3414 AND trans2.langcode = 'en'
    #     AND trans3.translatable_type = 'Sex'   AND trans3.title = 'not known'    AND trans3.langcode = 'en')
    #     AND translations.langcode = 'en' AND translations.translatable_type = 'Artist' AND translations.title = 'UnknownArtist';
    id_place_unknown = Place.unknown.id
    @artist_unknown ||=
      find_by_regex(:title, UnknownArtist["en"], langcode: "en",
                   where: sprintf("artists.place_id = %d AND trans2.translatable_id = %d AND trans2.translatable_type = 'Place' AND trans2.langcode = 'en' AND trans3.translatable_type = 'Sex' AND trans3.title = '%s' AND trans3.langcode = 'en'", id_place_unknown, id_place_unknown, Sex::UnknownSex["en"]),
                   joins: "INNER JOIN artists ON translations.translatable_id = artists.id INNER JOIN places ON artists.place_id = places.id INNER JOIN translations trans2 ON artists.place_id = places.id INNER JOIN sexes ON artists.sex_id = sexes.id INNER JOIN translations trans3 ON artists.sex_id = sexes.id")
  end

  # Returning a default Model in the given context
  #
  # Both context and place are ignored so far.
  #
  # @option context [Symbol, String]
  # @param place: [Place]
  # @param reload: [Boolean] if true (Def: false), the cache is not used and is updated.
  # @return [Artist]
  def self.default(context=nil, place: nil, reload: false)
    con_s = context.to_s
    @record_default ||= {}
    if reload || !@record_default[con_s]
      @record_default[con_s] = select_regex(:titles, /^(#{DEF_ARTIST_TITLES.map{|i| Regexp.quote(i)}.join('|')})$/i, sql_regexp: true).first
    else
      @record_default[con_s]
    end || self.unknown
  end

  # Wrapper of the standard self.find_all_by, considering {Translation}
  #
  # @param titles [Array<String>] Array of "title"-s of the singer (maybe in many languages) to search for.
  # @option kwd [Symbol, String, Array<String>, NilClass] (title|alt_title|ruby|alt_ruby|romaji|alt_romaji|titles|all)
  #    or Array of Symbol|String to evaluate. Note :titles is the alias
  #    for [:title, :alt_title], and :all means all the 6 columns.
  #    If nil, this parameter, as well as value, is not used.
  # @param uniq: [Boolean] If true, the returned Array is uniq-ed based on <BaseWithTranslation#id>
  # @param **transkeys: [Hash] e.g., match_method_upto, langcode. Passed to {Translation.find_all_by_a_title} for detail.
  # @return [Array] maybe empty.
  #   {Artist#match_method} and {Artist#matched_attribute} are set
  #   in each element and so {Artist#matched_string} can be used.
  def self.find_all_by_title_plus(
        titles,
        kwd=:titles,
        *args,
        uniq: false,
        id: nil,
        birth_day: nil,
        birth_month: nil,
        birth_year: nil,
        place_id: nil,
        place: nil,
        sex_id: nil,
        sex: nil,
        wiki_en: nil,  # This is ignored (b/c not used for identification).
        wiki_ja: nil,  # This is ignored (b/c not used for identification).
        note: nil,     # This is ignored (b/c not used for identification).
        match_method_upto: :optional_article_ilike,
        **transkeys
      )

    place ||= Place.find(place_id) if place_id  # Could raise Exception hypothetically
    sex   ||= Sex.find(sex_id) if sex_id  # Could raise Exception hypothetically
    super(titles, kwd, *args, uniq: uniq, id: id, place: place, match_method_upto: match_method_upto, **transkeys){|art|
      catch(:external){
        # %i(birth_day birth_month birth_year).each do |ek|
        %i(birth_year).each do |ek|  # Month or Date are not considered for matching.
          throw :external, false if (i=binding.local_variable_get(ek)) && (j=art.send(ek)) && (i != j)
        end
        next false if sex && !sex.not_disagree?(art.sex, allow_nil: true)
        true
      }
    }
  end

  # Wrapper of {Artist.find_all_by_title_plus}
  #
  # Returns a single {Artist}, or nil if not found.
  #
  # @param titles [Array<String>] Array of "title"-s of the singer (maybe in many languages) to search for.
  # @option kwd [Symbol, String, Array<String>, NilClass] (title|alt_title|ruby|alt_ruby|romaji|alt_romaji|titles|all)
  #    or Array of Symbol|String to evaluate. Note :titles is the alias
  #    for [:title, :alt_title], and :all means all the 6 columns.
  #    If nil, this parameter, as well as value, is not used.
  # @param **opts: [Hash] e.g., match_method_upto, langcode. Passed to {Translation.find_all_by_a_title} for detail.
  # @return [Artist, NilClass]
  #   {Artist#match_method} and {Artist#matched_attribute} are set
  #   and so {Artist#matched_string} can be used.
  def self.find_by_title_plus(*args, **opts)
    find_all_by_title_plus(*args, **opts).first
  end

  # @param titles [Array<String>] Array of "title"-s of the singer (maybe in many languages) to search for.
  # @param **opts: [Hash] e.g., match_method_upto, langcode. Passed to {Translation.find_all_by_a_title} for detail.
  # @return [Artist]
  #   If found, a single Artist is returned, where
  #   {Artist#match_method} and {Artist#matched_attribute} are set
  #   and so {Artist#matched_string} can be used, and where
  #   the parameters are updated but *unsaved*.
  #   If not found, a new (unsaved) record of {Artist} is returned.
  #   Either way, {Translation} are NOT updated.
  def self.updated_by_title_plus_or_initialized(
        titles,
        *args,
        birth_day: nil,
        birth_month: nil,
        birth_year: nil,
        place: nil,
        sex: nil,
        wiki_en: nil,  # This is ignored in identification.
        wiki_ja: nil,  # This is ignored in identification.
        note: nil,     # This is ignored in identification.
        **opts)

    mainprms = {
      birth_day:   birth_day,
      birth_month: birth_month,
      birth_year:  birth_year,
      place: place,
      sex: sex,
      wiki_en: wiki_en,
      wiki_ja: wiki_ja,
      note: note,
    }

    super(mainprms, titles, *args, **opts)
  end

  # @return [HaramiVid::Relation] where self is a collab-Artist.
  def collab_harami_vids
    HaramiVid.joins(:artist_music_plays).where("artist_music_plays.artist_id" => id).distinct
  end

  # Returns string expression of birthday
  #
  # @return [String]
  def birthday_string
    date2text(birth_year, birth_month, birth_day)  # defined in module_common.rb
  end

  # true if one of birth_SOMETHING is defined.
  #
  def any_birthdate_defined?
    !(birth_year.blank? && birth_month.blank? && birth_day.blank?)
  end

  # Returns an Array of title or alt_title-s of {EngageHow} for the given {Music}
  #
  # Convenience tool for views.
  # See {BaseWithTranslation#title_or_alt} for the optional arguments.
  #
  # @param music [Music]
  # @param with_year: [Integer, NilClass] if a year is given (Def: nil) and if it differs from {Engage#year}, the year is also displayed in the returned String
  # @return [Array<String>]
  def engage_how_titles(music, year: nil, **kwd)
    engages.where(music: music).joins(:engage_how).order('engage_hows.weight').map{|i|  # order(:weight) can do the same (b/c Engage does not have "weight").
      tit = i.engage_how.title_or_alt(**kwd)
      year_db = i.year
      ((year && year != year_db) ? sprintf('%s(%s)', tit, (year_db || '年不明')) : tit)
    }
  end

  # Returns an Array of {EngageHow} information for the given {Music}
  #
  # Convenience tool for views.
  # See {BaseWithTranslation#title_or_alt} for the optional arguments.
  #
  # @param music [Music]
  # @return [Array<Hash>] Array of [Hash<engage,title,year,contribution>, ...] with rows sorted by {EngageHow#weight}
  def engage_how_list(music, langcode: I18n.locale, lang_fallback_option: :either, str_fallback: nil, article_to_head: true, **kwd)
    engages.where(music: music).joins(:engage_how).order('engage_hows.weight').map{|ea_eng|  # order(:weight) can do the same (b/c Engage does not have "weight").
      {
        engage: ea_eng,
        title: ea_eng.engage_how.title_or_alt(langcode: langcode, lang_fallback_option: lang_fallback_option, str_fallback: str_fallback, article_to_head: article_to_head, **kwd),
        year: ea_eng.year,
        contribution: ea_eng.contribution,
      }.with_indifferent_access
    }
  end

  # Returns an Array of {Music} belonging to self with the specified title
  #
  # So far, both {Translation#title} and {Translation#alt_title} are considered.
  #
  # @param title [String]
  # @param exact [Boolean] if true, only the exact match (after {SlimString}) is considered.
  # @param case_sensitive [Boolean] if true, only the exact match is considered.
  # @return [Array<Music>] maybe empty
  #
  # @todo Consider sort based on Levenshtein distances for more fuzzy matches
  def musics_of_title(title, exact: false, case_sensitive: false)
    title_slim = SlimString.slim_string(title)

    return translations.select{|i| i.title == title_slim || i.alt_title == title_slim} if exact

    regex =  Regexp.new('\A'+Regexp.quote(title_slim)+'\z', (case_sensitive ? nil : Regexp::IGNORECASE))
    return translations.select{|i| regex =~ i.title || regex =~ i.alt_title}
  end


  # Returns an HTML wikipedia link
  #
  # @param label_str [String] HTML label
  #    You may run "label_str.html_safe" before passing it to this method.
  # @param langcode: [String, Symbol] locale
  #   If not found and if with_fallback is true, searches for another locale.
  #   Note that any locale is allowed as far as this method is concerned,
  #   though {Artist} model only supports ja and en.
  # @param with_fallback: [Boolean] If true (Default) and if the wikipedia for
  #   the given langcode is not found, returns the fallback.
  # @param opts: [Hash] passed to link_to
  # @return [String, NilClass] HTML of <a> for Wikipedia link or nil if not found
  def link_to_wikipedia(label_str, langcode: I18n.locale, with_fallback: true, **opts)
    langs = [langcode.to_s, 'en', 'ja'].uniq
    langs.each do |lc|
      root_str = _raw_link_to_wikipedia_single(lc)
      return link_to_from_root_str(label_str, root_str, **opts) if root_str  # defined in ModuleCommon
      return nil if !with_fallback
    end

    return nil
  end


  # Core routine for {#link_to_wikipedia}
  #
  # @param langcode [String]
  # @return [String, NilClass] Root of Wikipedia link or nil if not found
  def _raw_link_to_wikipedia_single(langcode)
    method = 'wiki_'+langcode
    return nil if !respond_to? method
    ret = send(method)
    ret.blank? ? nil : ret
  end
  private :_raw_link_to_wikipedia_single

  # Return a Hash to copy the values of the best (or given) Translation
  #
  # Either trans or langcode must be specified
  # This is a wrapper of {Translation#hs_key_attributes}
  #
  # @param trans: [Translatio] if specified, langcode is ignored and this Translation is used as the template.
  # @param langcode: [String, Symbol] if specified, {Artist#best_translations} for this langcode is used as the template.
  # @param additional_cols: [Array<Symbol, String>] Additional column names if any
  # @return [Hash<Symbol, Object>, NilClass] nil if there is no best_translation for the langcode
  def self.hs_best_trans_params(trans: nil, langcode: nil, additional_cols: [])
    if !trans
      raise ArgumentError if langcode.blank?
      trans = best_translations[langcode.to_s]
      return nil if !trans
    end

    trans.hs_key_attributes(*additional_cols)
  end

  # before_validation callback
  #
  # {Place} is forcibly added if not set, yet!
  def add_place_for_validation
    return if place
    self.place = Place.unknown
  end

  # before_validation callback
  #
  # {Sex} is forcibly guessed and set if not set, yet!
  def add_sex_for_validation
    return if sex
    ar_titles = get_ary_titles(with_langcode: false).flatten.compact
    return if ar_titles.empty?

    self.sex = guess_sex(ar_titles)  # defined in ModuleCommon
  end


  # Callback called by Translation after_save callback/hook
  #
  # Basically, the best Translation for the langcode for an Artist
  # has to be synchronized with the counterpart for a ChannelOwner
  # if there is any.  This after_save callback for Translation does it.
  #
  # This method has to be public!
  #
  # @todo
  #   callback after one of the best Translation-s is destroyed to destroy the counterpart of ChannelOwner
  #
  # @paran trans [Translation] which was just saved
  def after_save_translatable_callback(trans)
    return if !channel_owner
    return if !channel_owner.themselves

    reload
    return if best_translations[trans.langcode] != trans  # nothing is done if the saved Translation is not the best one for the langcode.

    tra_other = channel_owner.best_translations[trans.langcode]
    if !tra_other
      # No Translation for the langcode is defined in the corresponding ChannelOwner.  Create one, copying this Translation.
      new_trans = trans.dup
      new_trans.translatable = nil
      channel_owner.translations << new_trans
      return
    end
    
    hsoverwrite = self.class.hs_best_trans_params(trans: trans, additional_cols: %i(update_user_id updated_at))
    tra_other.update_columns(**hsoverwrite)  # Synchronize this translation with the one for ChannelOwner (skipping validations/callbacks)
    # tra_other.update_columns( updated_at: trans.updated_at )
  end

  ##############################
  private
  ##############################
    def is_birth_date_valid?
      if birth_year && birth_month && birth_day
        begin
          Date.new birth_year, birth_month, birth_day
        rescue Date::Error
          msg = sprintf "(%04d-%02d-%02d) is invalid as a date.", birth_year, birth_month, birth_day
          errors.add(:date_combination, msg) 
        end
      end

      if birth_month && birth_day
        flag = false
        case birth_month
        when 1,3,5,7,8,10,12
          ran = (1..31)
        when 4,6,9,11
          ran = (1..30)
        when 2
          ran = (1..29)
        else
          flag = true  # Wrong month.
        end
        flag = true if birth_month != birth_month.to_i

        if flag || (!ran.cover? birth_day)
          msg = sprintf "Month-Day of (%02d-%02d) is invalid as a date.", birth_month, birth_day
          errors.add(:date_combination, msg) 
        end
      end
    end

    # If there is an Artist with unknown Birthday, for example,
    # another Artist with a certain Birthday with the same name at
    # the same place would be invalid.
    # Similarly, if there is an Artist from Liverpool,
    # an Artist from unknown place in the UK with the same name
    # (and same birth-day) would be invalid.
    def unique_combination?
      ar_titles = get_ary_titles(with_langcode: true)
      return if ar_titles.empty?  # No Translations are (or will be in create) defiend.

      hs_titles = {}  # {"en" => ['Queen', 'Queener', 'Kings'], "ja" => [...]}
      ar_titles.each do |ea|
        hs_titles[ea[0]] ||= []
        hs_titles[ea[0]] += ea[1..2].map{|i| i.blank? ? nil : i}.compact
      end

      # Gets the Artists with the same name (for at least one of its translated names
      # in the corresponding language).
      candidates = hs_titles.map{ |ek, ev|
        cands = self.class.find_all_by_title_plus(
          ev,
          :titles,
          uniq: true,
          match_method_upto: :optional_article_ilike,
          langcode: ek
        )
      }.flatten.uniq.select{|artist| (self == artist) ? false : true}

      return if candidates.empty?

      candidates.each do |ecan|
        prms = [ecan, self].map{|model|
          model.slice(:birth_year, :birth_month, :birth_day).values
        }
        if birth_day_not_disagree?(*prms) && ecan.place.not_disagree?(place)
          # Violation of the custom unique constraint.
          msg = ": Artist is not unique in the combination of Title/AltTitle, BirthDate, and Place."
          errors.add(:unique_combination, msg)
          return false
        end
      end
    end

    # Returns all the title and alt_titles from both {#translations} and {#unsaved_translations}
    #
    # @param with_langcode: [Boolean] if true (Def: false), langcode is the 1st element
    # @return [Array]
    def get_ary_titles(with_langcode: false)
      ary2pass = [:title, :alt_title]
      ary2pass.unshift :langcode if with_langcode

      ar_titles = []
      ar_titles += translations.pluck(*ary2pass) if translations && translations.exists?
      ar_titles += unsaved_translations.pluck(*ary2pass) if unsaved_translations && !unsaved_translations.empty?
      # unsaved_translations is referred to only in before_create. However, it can be
      # used for validation during Translation#create (to be implemented in the future).
      ar_titles
    end

    # If the two days are kind of similar, this returns true.
    # For example, Year of 1999 and Day of 1999-02-23
    # do not disagree and hence this returns true.
    # If one of them is nil, this always returns true, unless allow_nil
    # is false, in which case this always returns false.
    #
    # Note "allow_nil" affects only when all the parameters of
    # either day1 or day2 are nil; if one of the year, month, day
    # is nil, it is regarded as "inclusive", that is,
    # for example, Day of 4th and nil would not_disagree.
    #
    # @param day1 [Array<Integer, NilClass>] Year, Month, Date
    # @param day2 [Array<Integer, NilClass>] Year, Month, Date
    def birth_day_not_disagree?(day1, day2, allow_nil: true)
      return allow_nil if day1.compact.empty? || day2.compact.empty?
      return true if (!day1[0] || !day2[0] || day1[0] == day2[0]) &&
                     (!day1[1] || !day2[1] || day1[1] == day2[1]) &&
                     (!day1[2] || !day2[2] || day1[2] == day2[2])
      false
    end
end

class << Artist
  alias_method :create_basic_bwt!, :create_basic! if !self.method_defined?(:create_basic_bwt!)
  alias_method :initialize_basic_bwt, :initialize_basic if !self.method_defined?(:initialize_basic_bwt!)

  # Wrapper of {BaseWithTranslation.create_basic!}
  def create_basic!(*args, sex: nil, sex_id: nil, **kwds, &blok)
    sex_id ||= (sex ? sex.id : (Sex.unknown || Sex.create_basic!).id)
    create_basic_bwt!(*args, sex_id: sex_id, **kwds, &blok)
  end

  # Wrapper of {BaseWithTranslation.initialize_basic!}
  # Unlike {#create_basic!}, an existing Sex is used, which is assumed to exist.
  def initialize_basic(*args, sex: nil, sex_id: nil, **kwds, &blok)
    sex_id ||= (sex ? sex.id : Sex.first.id)
    initialize_basic_bwt(*args, sex_id: sex_id, **kwds, &blok)
  end
end

