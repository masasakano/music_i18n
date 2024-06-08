# -*- coding: utf-8 -*-

#class Harami1129s::InjectFromHarami1129
#  include ActiveModel::Model
class Harami1129s::InjectFromHarami1129 < ApplicationRecord
  self.abstract_class = true  # instantiation would raise NotImplementedError

  extend  ModuleCommon  # guess_sex() etc. in the Constant definition
  #include ModuleCommon  # zenkaku_to_ascii etc

  # Mapping from the column name of harami1129s (as the key) to the main tables
  #
  # The Proc is called with two arguments: the content of the original {Harami1129}
  # with the key for the first element, and the {Harami1129} for the second element
  # in case the Proc needs more flexible manipulation.
  MAPPING_HARAMI1129 = {
    harami_vid: {
      # ["id", "release_date", "duration", "uri", "place_id", "harami_vid_id", "event_itm_id", "uri_playlist_ja", "uri_playlist_en", "note", "created_at", "updated_at"]
      ins_release_date: :release_date,
      ins_link_root: Proc.new{|i| {:uri => (i ? 'youtu.be/'+i : nil)}},
      ins_title: {translations: :title},
    },
    artist: {
      # ["id", "sex_id", "place_id", "birth_year", "birth_month", "birth_day", "wiki_ja", "wiki_en", "note", "created_at", "updated_at"]
      ins_singer: {translations: :title},
      ins_singer__01: Proc.new{|i| (i ? {:sex =>   guess_sex(i)} : nil)},  ## Double "__" means not mandatory to identify a record to update.
      ins_singer__02: Proc.new{|i| (i ? {:place => guess_japan_from_char(i)} : nil)},
    },
    music: {
      # ["id", "year", "place_id", "genre_id", "note", "created_at", "updated_at"]
      ins_song: {translations: :title},
      ins_singer__01: Proc.new{|i| (i ? {:place => guess_japan_from_char(i)} : nil)},  ## Double "__" means not mandatory to identify a record to update.
    },
    engage: {
      # ["id", "music_id", "artist_id", "contribution", "year", "note", "created_at", "updated_at"]
      music: Music,
      artist: Artist,
    },
    harami_vid_music_assoc: {
      # ["id", "harami_vid_id", "music_id", "timing", "completeness", "note", "created_at", "updated_at"]
      harami_vid: HaramiVid,
      music: Music,
      ins_link_time: :timing,
      # completeness:float
    },
    harami_vid_event_item_assoc: {  # Not examined... (put here just for informatin)
      # ["id", "harami_vid_id", "event_item_id", "timing", "note", "created_at", "updated_at"]
      harami_vid: HaramiVid,
      event_item: EventItem,
    },
  }

  # Core routine to interpret each entry of {MAPPING_HARAMI1129}
  #
  # For example, zenkaku alphabets are converted into hankaku.
  # 'youtu.be/' is prefixed to the original string, etc.
  #
  # This returns a one-element Hash of
  #
  # (1) {Symbol(new-key) for the destination => Object to insert/inject},
  # (2) {:translations => {title: Title_String_to_Insert},
  # (3) {Symbol(from-key) => ApplicationRecord}
  #
  # @param harami1129 [Harami1129] model
  # @param ins_key [Symbol] Key in Harami1129, possibly with a postfix of "__02" etc.
  # @param destination [Symbol, Proc, Hash] If Symbol, a simple copy to the key.
  #   If Proc, the original string is converted by calling the Proc.
  #   If Hash, it is for Translation.
  # @param ignore_double_us: [Boolean] if true (Def: false), entries with the keys
  #   containing "__" are ignored; it is used to construct "hsmain" to identify
  #   the (potentially) exiting record(s) to update
  # @return [Hash<Symbol,Object,Hash>, NilClass] e.g., {uri: 'youtu.be/abcdef'} or {translations: {title: 'M'}})
  #   or like {harami_vid: HaramiVid} for some columns in the association model
  #   where the value is for the model-record of the destination,
  #   or nil, if invalid for the case (e.g., the output key 'sex' when input 'singer' is nil).
  def self.interpret_mapping_harami1129_core(harami1129, ins_key, destination, ignore_double_us: false)
    tmp_key  = ins_key.to_s
    from_key = tmp_key.to_s.sub(/__+\d*$/, '')  # Converts :singer__01 into :singer
    return nil if ignore_double_us && tmp_key != from_key
    from_key = from_key.to_sym
    downloaded_key = Harami1129.downloaded_column_key(from_key)

    return {from_key => destination} if destination.is_a?(Class) && destination.ancestors.include?(ApplicationRecord)

    if destination.is_a? Symbol
      # e.g., ins_release_date: :release_date,
      {destination => downloaded_content(harami1129, downloaded_key)}
    elsif destination.respond_to? :call
#print "DEBUG:proc1:";p from_key
#print "DEBUG:proc2:";p downloaded_key
#print "DEBUG:proc3:";p downloaded_content(harami1129, downloaded_key)
#print "DEBUG:proc4:";p destination.call(downloaded_content(harami1129, downloaded_key))
      # e.g., {ins_link_root: Proc{|i| {:uri => 'youtu.be/'+i})}
      # The "value" in the returned 1-element Hash is the one converted from
      # the original downloaded_content; example of a returned value:
      #   {:uri => 'youtu.be/ABCDEF'}  (where the downloaded content is h1.link_root=='ABCDEF')
      destination.call(downloaded_content(harami1129, downloaded_key), harami1129)
    elsif destination.respond_to? :each_pair
      # e.g., ins_title: {translatable: :title},
      dest_method, k_title  = destination.first  # e.g., [:translations, :title]
      if !((dest_method == :translations) && [:title, :alt_title, :titles].include?(k_title))
        raise "(#{__method__}) Contact the code developer: trans: "+{from_key => destination}.inspect
      end
#print "DEBUG:proc5:[tmp_key,dc]=";p [tmp_key, downloaded_content(harami1129, downloaded_key)]
      {translations: {k_title => downloaded_content(harami1129, downloaded_key)}}
    else
      raise "(#{__method__}) Contact the code developer: "+[from_key, destination].inspect
    end
  end

  # Returns the cell content of a column (like :singer as opposed to :ins_singer)
  #
  # Zenkaku Japanese symbols are converted to hankaku.
  #
  # @param harami1129 [Harami1129] model
  # @param downloaded_key [Symbol]
  # @return [Object]
  def self.downloaded_content(harami1129, downloaded_key)
    any_zenkaku_to_ascii(harami1129.send(downloaded_key))
  end
  private_class_method :downloaded_content

  # Returns a Hash from the original Harami1129 column name to String to inject.
  #
  # For example, zenkaku alphabets are converted into hankaku.
  #
  # @param harami1129 [Harami1129] model
  # @return [Hash] e.g.,
  #    {ins_link_root: ['harami_vid', {uri: 'youtu.be/abcdef'}    ],
  #     ins_song:      ['music',      {translations: {title: 'M'}}],}
  def cells2inject(harami1129)
#print "DEBUG:cel:";p harami1129

    reths = {}
    MAPPING_HARAMI1129.each_pair do |model_snake_sym, ea_hs| 
      ea_hs.each_pair do |ins_key, destination|
        hstmp = interpret_mapping_harami1129_core(harami1129, ins_key, destination)
        reths[ins_key] = [model_snake_sym, hstmp]
        #next if !hstmp
        #_, ev = hstmp.first
        #next if ev.is_a? Class
        #reths[ins_key] = [model_snake_sym, (ev.respond_to?(:values) ? ev.values.first : ev)]
      end
    end
    reths
  end

  # Hash to pass to update! (the main Hash, not including the {Translation})
  #
  # @param harami1129 [Harami1129] model
  # @param model_class [ActiveRecord] model class like HaramiVid
  # @param crows [Hash<Symbol, BaseWithTranslation>] crows[model_shake] should be
  #   the current record to update, unless it is a new record (in which case it is nil).
  # @param model_snake [String] snake-case String of the model class like harami_vid
  # @param **opts [Hash] Key :ignore_double_us : TRUE to identify a record to update.
  # @return [Hash] upd_data: # {new-key => [would-be-value, current-value]} (multiple values)
  # @param opts [Hash<Symbol, Boolean>] the key ignore_double_us: true/false. See {interpret_mapping_harami1129_core}
  def self.get_hsmain_to_update(harami1129, model_class, crows, model_snake=nil, **opts) #ignore_double_us: false)
    model_snake ||= model_class.name.underscore
    crow = crows[model_snake]
    upd_data = {}
    MAPPING_HARAMI1129.each_pair do |model_snake_sym, ea_hs| 
      next if model_snake_sym != model_class.name.underscore.to_sym  # or model_class.table_name.singularize.to_sym

#print "DEBUG:ea_hs:"; p [model_snake_sym, ea_hs]
      ea_hs.each_pair do |ins_key, destination|
        hstmp = interpret_mapping_harami1129_core(harami1129, ins_key, destination, **opts)
#print "hstmp for [ins_key, opts]=#{[ins_key, opts].inspect}: hstmp="; p hstmp
        next if !hstmp
if !hstmp
  raise "(#{__method__}) contact the code developer. ins_key=#{ins_key.inspect}, destination=#{destination.inspect}"
end
        ek, ev = hstmp.first
        next if ev.respond_to?(:values)  # Translation, which was separately dealt at the beginning.

        if ev.is_a? Class
          k = ev.name.underscore.to_sym
          if crows.key? k
            upd_data[ek] = crows[k]
          else
            logger.warn "(#{__method__}): Model(#{k}) is not defined for key=#{k} in #{model_snake.inspect}"
          end
          next
        end

        # Standard.
        next if crow && !crow.send(ek).blank?  # Already a significant value is set and it is NOT updated.

        upd_data[ek] = any_zenkaku_to_ascii(ev)
      end
    end

    logger.debug "(#{__method__}): upd_data=#{upd_data.inspect}"
    upd_data
  end

  # Returns a Hash to feed to {BaseWithTranslation#with_translations} or
  # {BaseWithTranslation#select_by_translations}
  #
  # The key(s) are Symbol of langcode.
  #
  # @example "SMAP" is regarded as an English name with a Japanese translation.
  #   tr = hash_for_trans(harami1129, Artist)
  #   # => {en: {title: "SMAP",
  #   #          is_orig: true},
  #   #     ja: {title: "SMAP"} }
  #   Artist.create_with_translations!({place: plac}, translations: tr)
  #
  # @param harami1129 [Harami1129] model
  # @param model_class [Class] ApplicationRecord class
  # @return [Hash] e.g., {ins_link_root: 'youtu.be/abcdef', ins_song: 'M'),
  def self.hash_for_trans(harami1129, model_class)
    MAPPING_HARAMI1129.each_pair do |model_snake_sym, ea_hs| 
      next if model_snake_sym != model_class.name.underscore.to_sym  # or model_class.table_name.singularize.to_sym

#print "DEBUG:hft:harami1129=";p harami1129
#print "DEBUG:hft:ea_hs=";p ea_hs
      ea_hs.each_pair do |ins_key, destination|
#print "DEBUG:hft:[]=";p [ins_key, destination]
        hstmp = interpret_mapping_harami1129_core(harami1129, ins_key, destination)
#print "DEBUG:hft:hstmp=";p hstmp
        _, ev = hstmp.first
        next if ev.is_a? ApplicationRecord
        next if !ev.respond_to?(:values)

        # Assumes the key is :translations
        k_title, v = ev.first
        title_str = any_zenkaku_to_ascii(v)
        next if !title_str

        lc = guess_lang_code title_str

        hs = {
          lc.to_sym => {
            k_title  => title_str,
            :is_orig => true
          }
        }

        # For an English-title song by a Japanese singer, the Japanese translation is added.
        if (Music == model_class) &&
           (lc.to_sym == :en) &&
           (guess_lang_code(title_str).to_sym == :ja)
          hs[:ja] = {
            k_title  => hs[:en][k_title]
          }
        end
        return hs  # Return once a translation has been found.
      end
    end

    logger.warn "Strange! No Translation is defined in MAPPING_HARAMI1129 for #{model_class.name}"
    {}
  end


  # Returns the destination model instance which the record is either
  # newly injected (new_record? is true) to or updated for (if need be).
  #
  #
  # @return [ApplicationRecord]
  # @yield should return the model-record candidate based on the association.
  def self.get_destination_row(harami1129, model_class, crows)
    # Translation-based guess of the existing model record.
    # It uses HaramiVid title as well; therefore this should agree with
    # row_cands_def
    hstrans = hash_for_trans(harami1129, model_class)
    hsmain = get_hsmain_to_update(harami1129, model_class, crows) #, ignore_double_us: true)

    cands = model_class.select_by_translations(hsmain, **hstrans)

    n_cands = cands.count 
    if n_cands > 1
      msg = sprintf "Multiple (n=%d) rows (ID=%s) found from Translations for %s corresponding to Harami1129(id=%d, ins_title=%s)", n_cands, cands.pluck(:id).inspect, model_class.name, harami1129.id, harami1129.ins_title
      logger.warn msg
    end
#print "DEBUG:DEST:cands=#{cands.inspect}\n" if n_cands > 0
    return cands.first if n_cands > 0

#print "DEBUG:DEST:hsmain=#{hsmain.inspect}\n"
    model_class.new(**hsmain)
  end

end

