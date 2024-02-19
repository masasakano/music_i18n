# coding: utf-8
# == Schema Information
#
# Table name: musics
#
#  id         :bigint           not null, primary key
#  note       :text
#  year       :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  genre_id   :bigint           not null
#  place_id   :bigint           not null
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

  has_many :harami_vid_music_assocs, dependent: :destroy
  has_many :harami_vids, through: :harami_vid_music_assocs
  has_many :harami1129s, through: :engages  # Please nullify Harami1129#engage_id before deleting self (for now)

  has_one :prefecture, through: :place
  has_one :country, through: :prefecture

  validates :year, numericality: { allow_nil: true, greater_than: 0, message: "(%{value}) must be positive." }

  # For the translations to be unique.
  # MAIN_UNIQUE_COLS = %i(year place_id)  # More complicated - it depends on Artist

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" from "The Beatles".  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = true

  UnknownMusic = {
    "ja" => '何かの曲',
    "en" => 'UnknownMusic',
    "fr" => 'MusiqueInconnue',
  }

  # NOTE: Music#artists cannot be followed by "distinct"; you must use "uniq" to
  #   obtain the list of unique Artists.  In default, it contains all the Engages,
  #   which some artists have more than one (like a composer and lyricist)
  #
  def sorted_artists
    artists.joins(engages: :engage_how).order(Arel.sql('CASE WHEN engage_hows.weight IS NULL THEN 1 ELSE 0 END, engage_hows.weight')).order(Arel.sql("CASE WHEN engages.contribution IS NULL THEN 1 ELSE 0 END, engages.contribution DESC"))  # This _should_ sort in the order of EngageHow#weight and then Engage#contribution (DESC). The latter has not been tested!
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

  # Returns true if self is the unknown {Music}
  #
  # Note: The unknown music has {Genre.unknown} (and probably {Place.unknown} and undefined year).
  def unknown?
    self == self.class.unknown
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

  MUSIC_CSV_FORMAT = %i(row music_ja ruby romaji music_en year country artist_ja artist_en langcode genre how memo)

  # Class to hold the result of a CSV-row load
  class ResultLoadCsv
    # String to represent a null EngageHow, because "how" in the CSV is invalid.
    # Note if null is given it will be {EngageHow.default} (="Singer(Original)")
    # as long as Artist is defined (else {EngageHow.unknown}).
    EngageHowInvalid = 'InvalidHow'

    Music::MUSIC_CSV_FORMAT.each do |k|
      attr_accessor k
    end

    # @option hs [Hash] model#changes_to_save (Hash of {str=>[bef, aft]})
    def initialize(hs=nil)
      if hs
        hs.each_pair do |ek, ev|
          instance_variable_set('@'+ek.to_s, ev)
        end
      end
    end

    def inspect
      sprintf "#<Music::RLC: %s>", Music::MUSIC_CSV_FORMAT.map{|i| (res=send(i)) ? sprintf("@%s=%s", i.to_s, res.inspect) : nil}.compact.join(", ")
    end
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

      hsrow = convert_csv_to_hash(csv)
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


  # Converts a row of the loaded CSV to Hash and returns it.
  #
  # nil and an empty string becomes nil.
  # Integer is converted. Place, Genre, EngageHow, are created.
  #
  # @param csv [CSV]
  # @return [Hash]
  def self.convert_csv_to_hash(csv)
    i_of_csv = array_to_hash(MUSIC_CSV_FORMAT)
    engage_how_default = EngageHow.default
    MUSIC_CSV_FORMAT.map{ |ek|
      [ek, convert_csv_to_hash_core(
         ek,
         csv[i_of_csv[ek]],
         genre_default: Genre.default,
         engage_how_default: engage_how_default
       )]
    }.to_h
  end
  private_class_method :convert_csv_to_hash

  # Returns a converted Object.
  #
  # Note neither {Genre} nor {EngageHow} should neve be nil.
  # If nil, the input is ill-formatted.
  #
  # @param ek [Symbol] as in {Music::MUSIC_CSV_FORMAT}
  # @param str_in [String, NilClass] CSV cell
  # @param genre_default: [Genre] (to avoid accessing DB every time this is called.)
  # @param engage_how_default: [EngageHow]
  # @return [NilClass, String, Integer, Genre, EngageHow, Place]
  def self.convert_csv_to_hash_core(ek, str_in, genre_default: , engage_how_default: )
    str = (str_in ? str_in.strip : nil)
    str = nil if str.blank?
    case ek.to_s
    when 'row', /_(ja|en)/, 'ruby', 'romaji'
      str
    when 'langcode'
      str ? str.downcase : nil
    when 'memo'
      str ? preprocess_space_zenkaku(str) : nil
    when 'year'
      (str && /\A\d+\z/ =~ str) ? str.to_i : nil  # nil if a non-number-like String
    when 'genre'
      if str
        if /^\d+$/ =~ str
          Genre.find_by_id(str.to_i) || nil
        else
          Genre[/#{Regexp.quote(str)}/i]
        end
      else
        Genre.default
      end
    when 'how'
      if str
        if /^\d+$/ =~ str
          EngageHow.find_by_id(str.to_i) || nil
        else
          EngageHow[/#{Regexp.quote(str)}/i]
        end
      else
        engage_how_default
      end
    when 'country'
      if str
        if (cnt = Country[str])
          Place.unknown(country: cnt)
        else
          arg = ((/\A+d+\n/ =~ str) ? str.to_i : Regexp.quote(str))
          (pref = Prefecture[arg]) ? Place.unknown(prefecture: pref) : nil
        end
      else
        nil
      end
    else
      raise "ek is (#{ek.inspect})"
    end
  end
  private_class_method :convert_csv_to_hash_core

end

