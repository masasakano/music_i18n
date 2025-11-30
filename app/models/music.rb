# coding: utf-8
# == Schema Information
#
# Table name: musics
#
#  id                                         :bigint           not null, primary key
#  memo_editor(Internal-use memo for Editors) :text
#  note                                       :text
#  year                                       :integer
#  created_at                                 :datetime         not null
#  updated_at                                 :datetime         not null
#  genre_id                                   :bigint           not null
#  place_id                                   :bigint           not null
#
# Indexes
#
#  index_musics_on_genre_id  (genre_id)
#  index_musics_on_place_id  (place_id)
#
# Foreign Keys
#
#  fk_rails_...  (genre_id => genres.id)
#  fk_rails_...  (place_id => places.id)
#
class Music < BaseWithTranslation

  # polymorphic many-to-many with Url
  include Anchorable

  # Used for the instance method {#unknown?} whereas the class method #{unknown} is overwritten.
  #
  # {Mucic.unknown} has {Genre.unknown} (and probably {Place.unknown} and undefined year).
  include ModuleUnknown

  include ModuleDefaultPlace # add_default_place (callback) etc

  # CSV format; used in ModuleCsvAux etc
  # NOTE: This MUST come before: include ModuleCsvAux
  MUSIC_CSV_FORMAT = %i(row music_ja ruby romaji music_en year country artist_ja artist_en langcode genre how memo)

  # CSV-related. Also defining Music::ResultLoadCsv 
  include ModuleCsvAux

  # For the translations to be unique (required by BaseWithTranslation).
  # MAIN_UNIQUE_COLS = %i(year place_id)  # More complicated - it depends on Artist

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" when "The Beatles" is passed.  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = true

  # Optional constant for a subclass of {BaseWithTranslation}. The unique constraint for
  # Translations of Music is more complex than ordinary models, given that it depends
  # on many-to-many associated Artist-s. For example, famously there are two songs, "M".
  # Therefore, the standard unique Translation constraints should be disabled.
  TRANSLATION_UNIQUE_SCOPES = :disable

  # Contexts to examine whether Music#place is updated to Japan-Unknown-Place
  CONTEXTS_TO_UPDATE_TO_JAPAN = %w(lang_ja artist_jp)

  # If the place column is nil, insert {Place.unknown} and {Genre.unknown}
  # where the callbacks are defined in the parent class.
  # Note there is no DB restriction, but the Rails valiation prohibits nil.
  # Therefore this method has to be called before each validation.
  before_validation :add_default_place
  before_validation :add_default_genre

  belongs_to :place
  belongs_to :genre
  has_many :engages, dependent: :destroy

  has_many :artists, through: :engages
  has_many :artist_translations, through: :artists, source: "translations"

  has_many :harami_vid_music_assocs, dependent: :destroy
  has_many :harami_vids, through: :harami_vid_music_assocs
  has_many :harami1129s, through: :engages  # Please nullify Harami1129#engage_id before deleting self (for now)

  has_one :prefecture, through: :place
  has_one :country, through: :prefecture

  has_many :artist_music_plays, dependent: :destroy  # dependent is a key
  %i(event_items play_roles instruments).each do |esym|
    has_many esym, -> {distinct}, through: :artist_music_plays
  end
  has_many :play_artists, -> {distinct}, through: :artist_music_plays, source: "artist"

  validates :year, numericality: { allow_nil: true, greater_than: 0, message: "(%{value}) must be positive." }

  # for controller's sake
  attr_accessor :artist_name
  attr_accessor :engage_hows
  attr_accessor :year_engage
  attr_accessor :contribution
  attr_accessor :wiki_url
  attr_accessor :fetch_h1_wiki

  UNKNOWN_TITLES = UnknownMusic = {
    "ja" => '何かの曲',
    "en" => 'UnknownMusic',
    "fr" => 'MusiqueInconnue',
  }

  # Scope to get Musics based on their "lead artist" determined by EngageHow#weight
  #
  # @param cntries [Country, Array<Country>, NilClass] the Country of the lead Artist. If nil, no filtering is applied.
  scope :with_lead_artist, ->(cntries) do
    # Define the lead artist subquery (lateral join)
    # This finds the Engage record whose associated EngageHow has the minimum weight for each Music
    lead_artist_engage_sql = <<-SQL
      INNER JOIN LATERAL (
        SELECT e_inner.*
        FROM engages AS e_inner
        INNER JOIN engage_hows AS eh_inner ON eh_inner.id = e_inner.engage_how_id
        INNER JOIN artists AS art_inner ON art_inner.id = e_inner.artist_id
        WHERE e_inner.music_id = musics.id
        ORDER BY #{Music.sql_order_artists(engages: 'e_inner', engage_hows: 'eh_inner', artists: 'art_inner')}
        LIMIT 1
      ) AS lead_engage ON TRUE
    SQL

    # Join musics to their lead_engage, then to the artist through lead_engage
    ret = joins(Arel.sql(lead_artist_engage_sql))
            .joins(Arel.sql('INNER JOIN artists ON artists.id = lead_engage.artist_id')) # Join to the artist through the lead_engage alias
    if cntries.present?
      #ret = ret.joins(artists: :country)  # NOTE: this would not work because this would freshly join "artists" as opposed to using the above-joined artists
      join_artist_country_sql = <<-SQL
        INNER JOIN places artist_places ON artist_places.id = artists.place_id
        INNER JOIN prefectures artist_prefectures ON artist_prefectures.id = artist_places.prefecture_id
      SQL
      ret = ret.joins(join_artist_country_sql).where("artist_prefectures.country_id": cntries)  # n.b., joining countries is unnecessary.
    end
    ret.distinct
  end

  # SQL for ORDER Artists
  #
  # In the order of
  #   EngageHow#weight, Engage#year, contribution, birth_year, Artist#creatd_at
  # so the result has no ambiguity.
  #
  # Note that "year" should not come before EngageHow#weight.  For example,
  # a Composer may have composed a song a year before it was officially released
  # as a song by a singer; then the song is usually recognised as the singer's song.
  #
  # An exception is that the music was first composed as an instrumental piece
  # and lyrics was added (years) later.  The case is not dealt well in this framework currently.
  #
  # A fundamental difficulty is whom a song is known with may vary sometimes;
  # e.g., "Jupiter" is definitely Holst's piece, but a Japanese song "Jupiter"
  # with new Japanese lyrics is known as Ayaka Hirahara's song, which is not wrong.
  # Hirahara did not "cover" it, so she is technically the "original singer" of the song.
  #
  # @param enagages: [String, NilClass] SQL alias for Engage
  def self.sql_order_artists(engages: nil, engage_hows: nil, artists: nil)
    engages     ||= "engages"
    engage_hows ||= "engage_hows"
    artists     ||= "artists"
    arret = [
      [engage_hows+".weight",   "ASC",  "NULLS LAST"],
      [engages+".year",         "ASC",  "NULLS LAST"],
      [engages+".contribution", "DESC", "NULLS FIRST"],  # DESC & NULLS FIRST means that null comes LAST
      [artists+".birth_year",   "ASC",  "NULLS LAST"],
      [artists+".created_at",   "ASC",  "NULLS LAST"]
    ].map{|ea|
      ea.join(" ")
    }.join(", ")
  end

  # NOTE: Music#artists cannot be followed by "distinct"; you must use "uniq" to
  #   obtain the list of unique Artists.  In default, it contains all the Engages,
  #   which some artists have more than one (like a composer and lyricist)
  #
  # @note For some reason, NULLS FIRST|LAST does not work...
  #
  def sorted_artists
    #artists.joins(engages: :engage_how).order("engage_hows.weight NULLS LAST", "engages.contribution DESC NULLS LAST", "engages.year NULLS FIRST")  # This seems to work
    #artists.joins(engages: :engage_how).order(Arel.sql('CASE WHEN engage_hows.weight IS NULL THEN 1 ELSE 0 END, engage_hows.weight')).order(Arel.sql("CASE WHEN engages.year IS NULL THEN 0 ELSE 1 END, engages.year")).order(Arel.sql("CASE WHEN engages.contribution IS NULL THEN 1 ELSE 0 END, engages.contribution DESC"))  # This works.
    # artists.joins(engages: :engage_how).order(Arel.sql(...))  ## NOTE: This would DOUBLY join engages like "INNER JOIN engages ON artists.id = engages.artist_id INNER JOIN engages engages_artists ON engages_artists.artist_id = artists.id" and hence would join lots of unnecessary rows and mess up the result!!  This is because Music#artists would internally join engages and then joins(engages: :engage_how) would INDEPENDENTLY join engage_hows for which the WHERE clause (WHERE engages.music_id = ?) is irrelevant!!
    artists.joins("JOIN engage_hows ON engages.engage_how_id = engage_hows.id").order(Arel.sql(self.class.sql_order_artists))  # This _should_ sort in the order of EngageHow#weight and then Engage#contribution (DESC) etc.  # I am pretty sure that  joins(engages: :engage_how) would not work well with this ordering.
  end

  # Returns the most significant artist
  #
  # sorted in order of {EngageHow#weight}, {Engage#contribution}, {Engage#year}, {Artist#birth_year}
  #
  # @note in case you want the whole list, "distinct" is unsable. Use Ruby uniq instead.
  # @return [Artist, NilClass]
  def most_significant_artist
    sorted_artists.first
  end
  # Returns the unknown {Music} with {Genre.unknown}
  #
  # @return [Music]
  def self.unknown
    # SELECT translations.id,translations.title,translations.translatable_type,translations.translatable_id,trans2.id,trans2.translatable_type,trans2.translatable_id
    #   FROM translations
    #   INNER JOIN musics ON translations.translatable_id = musics.id
    #   INNER JOIN genres ON musics.genre_id = genres.id
    #   INNER JOIN translations trans2 ON musics.genre_id = genres.id
    #   WHERE translations.translatable_type = 'Music' AND translations.title = 'UnknownMusic' AND translations.langcode = 'en' AND
    #         trans2.translatable_type = 'Genre' AND trans2.title = 'UnknownGenre' ORDER BY translations.id ASC;
    @music_unknown ||=
      find_by_regex(:title, UnknownMusic["en"], langcode: "en",
                   where: sprintf("trans2.translatable_type = 'Genre' AND trans2.title = '%s' AND trans2.langcode = 'en'", Genre::UnknownGenre["en"]),
                   joins: "INNER JOIN musics ON translations.translatable_id = musics.id INNER JOIN genres ON musics.genre_id = genres.id INNER JOIN translations trans2 ON musics.genre_id = genres.id")
  end

  # Return Music-Relation of Country.unknown that should be updated to Japan
  #
  # @param context [String, Symbol]
  # @param musics [NilClass, Integer, Music, Array<Integer, Music>] to check only this (or these) Music(s)
  # @return [Music::Relation]
  def self.world_to_update_to_japan(context, musics: nil)
    if !CONTEXTS_TO_UPDATE_TO_JAPAN.include?(context.to_s)
      raise ArgumentError, "unsupported context: #{context}"
    end

    music_where = (musics.present? ? {"musics.id": musics} : nil)
    jp = Country.primary
    jp_place = jp.unknown_prefecture.unknown_place

    ret = 
      case context.to_sym
      when :lang_ja
        joins(:translations).where("translations.is_orig": true, "translations.langcode": "ja")
      when :artist_jp
        with_lead_artist(jp)
      else
        raise  # should never happen
      end

    ret = ret.where("musics.place_id": Place.unknown)  # Music of Place.unknown only, exlucding Musics with more precice Places associated
    ret = ret.where(**music_where) if music_where
    ret = ret.distinct
  end

  # If self is at Country.unknown that should be updated to Japan?
  def world_to_update_to_japan?(contexts=nil)
    contexts ||= CONTEXTS_TO_UPDATE_TO_JAPAN
    [contexts].flatten.any?{ |cont|
      self.class.world_to_update_to_japan(cont, musics: self).exists?
    }
  end

  # Wrapper of +Music.engages << mus+, and retursn the created Engage
  #
  # If found, contribution and note are updated, IF non-nil is given.
  # If nil note is given, for example, note will not be updated
  # (because once set, it has to be always present (even if empty) and should never be nullified).
  # If an empty String is given, the value is updated.
  #
  # @param artist [Artist, Integer] can be pID
  # @param engage_how [EngageHow, Integer]]
  # @param year [Numeric, NilClass]
  # @param contribution [Numeric, NilClass]
  # @param note [String, NilClass]
  # @return [Engage]
  def find_and_update_or_add_engage(artist, engage_how, year: nil, contribution: nil, note: nil, bang: false)
    eng_new = Engage.find_or_initialize_by(
      music_id: id,
      artist_id:     (artist.respond_to?(:id)     ? artist.id     : artist),
      engage_how_id: (engage_how.respond_to?(:id) ? engage_how.id : engage_how),
      year: year
    )
    eng_new.contribution = contribution if contribution
    eng_new.note         = note         if note

    (bang ? eng_new.save! : eng_new.save)
    engages.reset
    eng_new
  end

  # Same as {#find_and_update_or_add_engage} but uses save!
  def find_and_update_or_add_engage!(*rest, bang: nil, **kwds)
    find_and_update_or_add_engage(*rest, bang: true, **kwds)
  end

  # Returns a Title, possibly associated with Artist name but only if there are multiple matches for the returned title.
  #
  # Regardless of `lang_fallback_option` and other optional arguments, Artist name is expressed in its original language.
  #
  # @example
  #    mus.title_maybe_with_artist(langcode: I18n.locale, lang_fallback_option: :either, article_to_head: true, prefer_shorter: true)
  #
  # @param kwds [Hash] passed to {BaseWithTranslation#title_or_alt} for Music
  # @return [String]
  def title_maybe_with_artist(**kwds)
    mu_tit = title_or_alt(**kwds)
    if Music.find_all_by_a_title(:all, mu_tit, uniq: true).size <= 1
      return mu_tit
    else
      art_tit = most_significant_artist.title_or_alt(langcode: nil, lang_fallback_option: :either, article_to_head: true)
      sprintf "%s [by %s]", mu_tit, art_tit
    end
  end

  # Wrapper of the standard self.find_all_by, considering {Translation}
  #
  # @param titles [Array<String>] Array of "title"-s of the singer (maybe in many languages) to search for.
  # @option kwd [Symbol, String, Array<String>, NilClass] (title|alt_title|ruby|alt_ruby|romaji|alt_romaji|titles|all)
  #    or Array of Symbol|String to evaluate. Note :titles is the alias
  #    for [:title, :alt_title], and :all means all the 6 columns.
  #    If nil, this parameter, as well as value, is not used.
  # @param uniq: [Boolean] If true, the returned Array is uniq-ed based on <BaseWithTranslation#id>
  # @param artists: [Artist, Array<Artist>, NilClass] if specified, the result is scoped for the Artists.
  # @param **transkeys: [Hash] e.g., match_method_upto, langcode. Passed to {Translation.find_all_by_a_title} for detail.
  # @return [Array] maybe empty.
  #   {Music#match_method} and {Music#matched_attribute} are set
  #   in each element and so {Music#matched_string} can be used.
  def self.find_all_by_title_plus(
        titles,
        kwd=:titles,
        *args,
        uniq: false,
        match_method_upto: :optional_article_ilike,
        artists: nil,
        id: nil,
        year: nil,
        place_id: nil,
        place: nil,
        genre_id: nil,
        genre: nil,
        note: nil,     # This is ignored (b/c not used for identification).
        **transkeys
      )

    where = joins = nil
    if artists
      joins = 'INNER JOIN engages ON translations.translatable_id = engages.music_id'
      where = ['engages.artist_id IN (?)', [artists].flatten.map(&:id)]
    end

    place ||= Place.find(place_id) if place_id  # Could raise Exception hypothetically
    genre ||= Genre.find(genre_id) if genre_id  # Could raise Exception hypothetically
    ret = super(titles, kwd, *args, uniq: uniq, match_method_upto: match_method_upto, where: where, joins: joins, id: id, place: place, **transkeys){|mus|
      next false if year && mus.year && (year != mus.year)
      next false if genre && !genre.not_disagree?(mus.genre, allow_nil: true)
      true
    }
    return ret if !ret.empty?

    # Search for candidates regardless of Genre when there are no matches.
    ret = super(titles, kwd, *args, uniq: uniq, match_method_upto: match_method_upto, where: where, joins: joins, id: id, place: place, **transkeys){|mus|
      next false if year && mus.year && (year != mus.year)
      true
    }
  end

  # Wrapper of {Music.find_all_by_title_plus}
  #
  # Returns a single {Music}, or nil if not found.
  #
  # This method is identical to {Article.find_by_title_plus}.
  # Note that technically this can be iplemented in base_with_translation.rb
  # but the internal algorithm would be far too complex (moving back and
  # forward between {BaseWithTranslation} and its subclasses) and so
  # it would not be a good idea.
  #
  # @param titles [Array<String>] Array of "title"-s of the singer (maybe in many languages) to search for.
  # @option kwd [Symbol, String, Array<String>, NilClass] (title|alt_title|ruby|alt_ruby|romaji|alt_romaji|titles|all)
  #    or Array of Symbol|String to evaluate. Note :titles is the alias
  #    for [:title, :alt_title], and :all means all the 6 columns.
  #    If nil, this parameter, as well as value, is not used.
  # @param **restkeys: [Hash] e.g., match_method_upto, langcode. Passed to {Translation.find_all_by_a_title} for detail.
  # @return [Music, NilClass]
  #   {Music#match_method} and {Music#matched_attribute} are set
  #   and so {Music#matched_string} can be used.
  def self.find_by_title_plus(*args, **opts)
    find_all_by_title_plus(*args, **opts).first
  end

  # @param titles [Array<String>] Array of "title"-s of the singer (maybe in many languages) to search for.
  # @param **opts: [Hash] e.g., match_method_upto, langcode. Passed to {Translation.find_all_by_a_title} for detail.
  # @return [Music]
  #   If found, a single Music is returned, where
  #   {Music#match_method} and {Music#matched_attribute} are set
  #   and so {Music#matched_string} can be used, and where
  #   the parameters are updated but *unsaved*.
  #   If not found, a new (unsaved) record of {Music} is returned.
  #   Either way, {Translation} are NOT updated.
  def self.updated_by_title_plus_or_initialized(
        titles,
        *args,
        artists: nil,
        year: nil,
        place: nil,
        genre: nil,
        note: nil,     # This is ignored in identification.
        **opts)

    mainprms = {
      year:  year,
      place: place,
      genre: genre,
      note: note,
    }

    prms_to_find = (artists ? {artists: artists} : {})  # Option-name: artist"s"

    super(mainprms, titles, *args, prms_to_find: prms_to_find, **opts)
  end

  # Populate the data to several DB tables received as a CSV file
  #
  # CSV format is defined in {Music::MUSIC_CSV_FORMAT}
  #
  # WARNING: the use of double-quotations in the CSV must be valid!
  #
  # If the corresponding record ({Music} or {Artist}) does not exist,
  # they are added with translations (ja and en, if specified).
  # The main language may be specified in the CSV, but if not,
  # and if the title looks like Japanese, the language is set so.
  # {Translation#is_orig} is set according to the specified or guessed language.
  # If the {Place} is not given in the CSV but if the language is Japanese,
  # {Place} is set to be "Somewhere in Japan".
  #
  # The default {Genre} is J-POP. The default {Engage} is "Singer (Original)"
  #
  # If the record exists, the significant attribute is not updated.
  # Null attributes are updated. The World-unknown {Place} may be replaced.
  # If a Japanese or English tranlation that does not exist in the record,
  # the translation is added, although is_orig is set false in thise case.
  #
  # == Error cases
  #
  # If a translation is wrong with an Artist in the CSV, neither Artist nor Music is craeted
  # (i.e., even if there is nothing wrong in the Japanese title, if an English
  # translation is wrong, the Artist is not created and the Japanese title is
  # simply discarded).
  # If Artist is not specified, {Artist.unknown} is returned.
  # If a translation is wrong with an Music in the CSV, it is not created,
  # though the associated Artist may be craeted.
  # If "How" is wrong, an Engage between the Artist and Music would be still
  # created unless it already exists.
  #
  # If an Exception is raised, which of course shouldn't, everything rolls back.
  #
  # @return [Hash<Array>, NilClass] Keys:
  #   { changes: Array, csv: Array, artists: Array, musics: Array, engages: Array}
  #   Use Array[0].errors.present? to see if it has been really saved.
  #   Elements can be nil if they have not been even attempted to be saved;
  #   for example, if Artist fails to be saved, Music is not processed.
  #   The array index corresponds to the line number (start from 0).  Therefore,
  #   if the first line is a comment line, csv[0] is nil.
  #   "changes" has an Array of [old, new]
  #   "csv" has an Array of Hash with the keys as in #{Music::MUSIC_CSV_FORMAT}
  #   NOTE!!: to access {#translations} you must {#reload}
  def self.populate_csv(strin)
    artists = []
    musics  = []
    engages = []
    arret = []
    arcsv = []
    input_lines = []
    iline = -1
    #ActiveRecord::Base.transaction do
    #
    ### NOTE: This transaction decorator results in a weird behaviour.
    # Basically, a new_record (with @errors set) is somehow saved in the DB
    # (without associated translations), which should have not been.
    # Because this method relies on the situations where the returned objects
    # can be saved or a new_record?, this is bad.  Hence the transaction is
    # not activated at the moment.  Records say a similar thing happened
    # in the past like Rails 3.1.0.
    # http://alwayscoding.ca/momentos/2012/06/05/transactions-and-new-record/
    # However in the case of Rails 3.1.0, a new_record was NOT saved even though
    # new_record? returns false, whereas in this case of
    # Rails 6.1, the record is actually saved in the DB.
    strin.each_line do |ea_li|
    #CSV.parse(strin) do |csv|  # this would raise an Exception when a comment line contains an "invalid" format (i.e., "misuse" of double quotations).
      iline += 1
      ea_li.chomp!
      input_lines[iline] = ea_li
      #next if !csv[0] || '#' == csv[0].strip[0,1]  # for the last line, csv==[]
      next if '#' == ea_li.strip[0,1]
      csv = CSV.parse(ea_li.strip)[0] || next  # for the blank line, csv.nil? (n.b. without strip, a line with a space would be significant.)

      hsrow = convert_csv_to_hash(csv)  # defined in ModuleCsvAux
      # Guaranteed there is no "" but nil.

      arcsv[iline] = hsrow

      rlc = ResultLoadCsv.new
      arret[iline] = rlc

      # Create/Update an Artist
      is_artist_only = [hsrow[:music_ja], hsrow[:music_en]].compact.empty?
      is_music_only = [hsrow[:artist_ja], hsrow[:artist_en]].compact.empty?

      if is_artist_only
        birth_year = hsrow[:year]
        place      = hsrow[:country]
      end
      mainprms = {  # Sex is guessed before validation.
        birth_year: birth_year,
        place: place,
      }
      mainprms[:note] = hsrow[:memo] if is_artist_only

      if is_music_only
        artist = Artist.unknown if is_music_only
      else
        artist = update_or_create_from_a_csv('artist', hsrow, mainprms, rlc)
      end

      artists[iline] = artist
      next if artist.errors.present?
      next if is_artist_only

      # Create/Update a Music
      mainprms = {
        year:  hsrow[:year],
        place: hsrow[:country],
        genre: hsrow[:genre],
        note:  hsrow[:memo]
      }

      artist2pass = artist if !artist.unknown?
      # This means if there is a Music title with an existing Artist,
      # it will be picked, even if the music intended is traditional with no associated Artist.

      music = update_or_create_from_a_csv('music', hsrow, mainprms, rlc, artists: artist2pass, ruby: hsrow[:ruby], romaji: hsrow[:romaji])
      musics[iline] = music
      next if music.errors.present?

      # Create/Update an Engage
      eh2save = (artist.unknown? ? EngageHow.unknown : hsrow[:how]) # maybe nil.
      hs2pass = {music: music, artist: artist} # maybe Artist.unknown; n.b., if nil, it would violate the DB constraint (DRb::DRbRemoteError).
      hs2pass[:engage_how] = eh2save if eh2save
      engs = Engage.where(**hs2pass)
      if engs.exists?
        # "year" may be updated if the year in the existing Engage is nil
        next if !hsrow[:year]
        next if engs.where(year: hsrow[:year]).exists?
        rela = engs.where(year: nil)
        if rela.exists?
          eng = rela.first
          eng.update!(year: hsrow[:year]) if !eng.year
        end
        next
      end
begin
      if eng = Engage.create(music: music, artist: artist, engage_how: eh2save, year: hsrow[:year])
        rlc.how = [nil, (eh2save ? eh2save.title : ResultLoadCsv::EngageHowInvalid)]
        engages[iline] = eng
      else
        next if eng.errors.present?
      end
rescue
print "DEBUG(rescue)(#{__method__}):mus:artist:";p artist
raise
end
    end
    #end

    { input_lines: input_lines, changes: arret, csv: arcsv, artists: artists, musics: musics, engages: engages}
  end

  # Internal routine to update/create Artist or Model.
  #
  # @param mname [String] Either 'artist' or 'model'
  # @param mainprms [Hash] to identify and update the existing model.
  #   This is assumed to include the kyy :place (the value may be nil).
  # @param rlc [Music::ResultLoadCsv] this object is updated.
  # @return [Artist, Music] Created/updated one
  def self.update_or_create_from_a_csv(mname, hsrow, mainprms, rlc, artists: nil, ruby: nil, romaji: nil)
    mname = mname.to_s
    tit = %w(ja en).map{|i| [i.to_sym, hsrow[(mname+'_'+i).to_sym]]}.to_h
    prms_to_find = (artists ? {artists: artists} : {})  # Option-name: artist"s"
    model = mname.capitalize.constantize.updated_by_title_plus_or_initialized(
      [tit[:ja], tit[:en]].compact,
      prms_to_find: prms_to_find,
      **mainprms
    )

    attr_name = ((mname == 'artist') ? :birth_year : :year)
    if model.attribute_changed? attr_name
      rlc.year = model.changes_to_save['year']
    end

    ## TODO: maybe this should not be processed for Artist UNLESS it is Artist-only,
    ##  i.e. 'year' in the CSV is for Artist.birth_year, rather than for Music.year.
    if model.attribute_changed? :place_id
      rlc.country = model.changes_to_save['place_id']
      rlc.country[1] = mainprms[:place].title if mainprms[:place]
      rlc.country[0] &&= Place.find(rlc.country[0]).country.title
    end

    orig_lc = hsrow[:langcode]
    orig_lc ||= guess_lang_code(tit[:ja]) if tit[:ja]
    orig_lc ||= guess_lang_code(tit[:en]) if tit[:en]
    if orig_lc == 'ja' && (!model.place || model.place == Place.unknown)
      model.place = Place.unknown(country: Country['JPN'])
    end

    %w(ja en).each do |elc|
      ek = (mname+'_'+elc).to_sym
      if (word = hsrow[ek])
        hs2passs = {title: word, langcode: elc,}
        hsruby = {}
        if elc == 'ja'
          hsruby[:ruby]   = ruby if ruby
          hsruby[:romaji] = romaji if romaji
        end
        hs2passs.merge! hsruby
        if model.new_record?
          model.unsaved_translations << Translation.new(is_orig: (elc == orig_lc), **hs2passs)
        else
          if (tra = model.find_translation_by_a_title(:titles, word, langcode: elc))
            next if hsruby.empty? || tra.matched_string != preprocess_space_zenkaku(word)
            hsruby.each_pair do |ek, ev|
              next if !ev || tra.send(ek)
              tra.update!(ek => ev)
              rlc.send ek.to_s+'=', [nil, ev]
            end
            next
          end
          model.translations         << Translation.new(is_orig: false, **hs2passs)
        end
        rlc.send ek.to_s+'=', [nil, word]
      end
    end

    if model.changed? || model.new_record?  # If new_record?, changed?==true unless every attribute is nil.
      if !model.save
        msg = "(#{__method__}) Failed in saving an #{mname.capitalize}: "+model.errors.full_messages.join(". ")
        logger.debug msg
      end
    end

    model
  end
  private_class_method :update_or_create_from_a_csv

end

