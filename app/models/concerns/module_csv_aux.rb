# -*- coding: utf-8 -*-

# Common module for handling a CSV file
#
# @example
#   include ModuleCsvAux
#
# == NOTE
#
module ModuleCsvAux
  #def self.included(base)
  #  base.extend(ClassMethods)
  #end
  extend ActiveSupport::Concern  # In Rails, the 3 lines above can be replaced with this.

  # Allowed maximum lines (including blank lines!)
  MAX_LINES = 250

  # Defines a Hash holding statistical information
  #
  # It can be accessed either +obj.stats[KEY]+ or +obj.KEY+ for the KEY like +:musics+
  #
  # @example
  #    allstats = StatsSuccessFailure.new
  #    allstats.stats[:attempted_rows] += 1
  #    # or # allstats.attempted_rows += 1
  #    allstats.stats[:musics][:created] += 1
  #
  class StatsSuccessFailure
    attr_accessor :stats

    def initialize
      @stats = {
        attempted_rows: 0,
        attempted_models: 0, # Models attempted to create or update.
        rejected_rows: 0,  # The number of the CSV rows that are totally rejected and ignored, e.g., matched Record is Not Found.
        unchanged_rows: 0,  # The number of the CSV rows that changed nothing on DB, perhaps no need to change (b/c identical) or perhaps partially rejected.
      }.with_indifferent_access

      %i(musics artists engages harami_vid_music_assocs artist_music_plays translations).each do |ek|
        add_key_to_stats_success_failure(ek)
      end
    end

    # @return [Integer] Total number. The sum of this and :rejected_rows and :unchanged_rows should be equal to :attempted_rows
    def success_rows
      ret = 0
      @stats.each_value do |ev|
        next if !ev.respond_to? :each_value  # such as, when the key is :attempted_rows
        next if !ev[:created].respond_to? :floor  # should be Integer. Alternatively you may design this to raise an Exception/Error?
        ret += ev[:created] + ev[:updated]
      end
      ret
    end

    # @return [Integer] Total number
    def failed_models
      ret = 0
      @stats.each_value do |ev|
        next if !ev.respond_to? :each_value  # such as, when the key is :attempted_rows
        next if !ev[:failed].respond_to? :floor  # should be Integer. Alternatively you may design this to raise an Exception/Error?
        ret += ev[:failed]
      end
      ret
    end

    # Add mathematically {StatsSuccessFailure.initial_hash_for_key} to a key, e.g., +:musics+
    #
    # @param stat_hash [Hash] This Hash should contain all the kyes in {StatsSuccessFailure.initial_hash_for_key} and nothing else except :warning and :notice
    # @param key_model [String, Symbol] like :musics
    # @return [Boolean] true if @stats[key_model] changes, i.e., stat_hash contains a non-zero Integer.
    def add_stat_hash_to(stat_hash, key_model)
      allkeys = @stats[key_model].keys.sort
      raise "Strange! #{allkeys.inspect} != #{stat_hash.keys.sort.inspect}" if allkeys != stat_hash.keys.sort
      is_changed = false
      allkeys.each do |ek|
        is_changed = true if stat_hash[ek] != 0
        @stats[key_model][ek] += stat_hash[ek]
      end
      is_changed
    end

    # Returns Hash for a key like :musics and :engages
    #
    # * created, updated, destroyed
    # * consistent (no need to update DB records)
    # * rejected (not attempted to save because of inconsistency etc)
    # * failed (ActiveRecord#save attempted but failed)
    #
    # @example
    #   StatsSuccessFailure.initial_hash_for_key(created: 1)
    #    # => {created: 0, updated: 0, destroyed: 0, consistent: 0, rejected: 0, failed: 0}.with_indifferent_access
    # @return Hash (.with_indifferent_access)
    def self.initial_hash_for_key(created: 0, updated: 0, destroyed: 0, consistent: 0, rejected: 0, failed: 0)
      {created: created, updated: updated, destroyed: destroyed, consistent: consistent, rejected: rejected, failed: failed}.with_indifferent_access
    end

    # Helper method to add a key to {StatsSuccessFailure#stats}
    #
    # The keys are:
    #
    #   created, updated, failed_update, destroyed
    #
    # where +:failed+ means the attempt of create/update failed.
    #
    # @return [Hash] or falsy if the key is already defined.
    def add_key_to_stats_success_failure(key)
      @stats[key] = self.class.initial_hash_for_key if !@stats.has_key?(key)
    end

    # {StatsSuccessFailure#attempted_rows} returns {StatsSuccessFailure#stats}[:attempted_rows] 
    #
    # Writer method is also defined.
    def method_missing(metho, *args, **opts, &block)
      if "=" == metho.to_s[-1]
        metho_writer = metho.to_s[0..-2]
      else
        metho_reader = metho.to_s
      end

      if (metho_reader && args.present?) || opts.present? || block_given?
        return super
      else
        return super if !@stats.has_key?(metho_writer || metho_reader)
      end

      metho_reader ? @stats[metho_reader] : @stats.send(:[]=, metho_writer, *args)
    end
  end

  # Container class to hold statistical information
  STATS_SUCCESS_FAILURE = {
    attempted_rows: 0,
    attempted_models: 0,
    rejected_rows: 0,  # The number of the CSV rows that are totally rejected and ignored, e.g., matched Record is Not Found.
    rejected_models: 0,
  }.with_indifferent_access

  # Helper method to add a key to {STATS_SUCCESS_FAILURE}
  #
  # The keys are:
  #
  #   created, updated, failed_update, destroyed
  #
  # where +:failed+ means the attempt of create/update failed.
  #
  # @param key [Symbol, String] like :musics
  def self.add_key_to_stats_success_failure(key)
    STATS_SUCCESS_FAILURE[key] = {created: 0, updated: 0, failed: 0, destroyed: 0}.with_indifferent_access
  end


  # This hook/callback runs immediately when a class (like Music) includes this module.
  #
  # defining the container class Music::ResultLoadCsv or HaramiVid::ResultLoadCsv
  def self.included(base)
    dynamic_class = Class.new do
      # @option hs [Hash] model#changes_to_save (Hash of {str=>[bef, aft]})
      def initialize(hs=nil)
        if hs
          hs.each_pair do |ek, ev|
            instance_variable_set('@'+ek.to_s, ev)
          end
        end
      end
    end

    base.const_set(:ResultLoadCsv, dynamic_class)

    # defines (Music::)ResultLoadCsv::MUSIC_CSV_FORMAT
    base::ResultLoadCsv.const_set(:MUSIC_CSV_FORMAT, base::MUSIC_CSV_FORMAT)  # The right side is that of the enclosing class.

    # String to represent a null EngageHow, because "how" in the CSV is invalid.
    # Note if null is given it will be {EngageHow.default} (="Singer(Original)")
    # as long as Artist is defined (else {EngageHow.unknown}).
    base::ResultLoadCsv.const_set(:EngageHowInvalid, "InvalidHow")

    base::ResultLoadCsv.class_eval do
      self::MUSIC_CSV_FORMAT.each do |k|
        attr_accessor k
      end
    end

    base::ResultLoadCsv.define_method :inspect do
      sprintf "#<#{base.name}::ResultLoadCsv %s>", base::MUSIC_CSV_FORMAT.map{|i| sprintf("@%s=%s", i.to_s, instance_variable_get("@"+i.to_s).inspect)}.join(", ")
    end
  end  # def self.included(base)

  module ClassMethods

    # Converts a row of the loaded CSV to Hash and returns it.
    #
    # nil and an empty string becomes nil.
    # Integer is converted. Place, Genre, EngageHow, are created.
    #
    # @param csv [CSV]
    # @param genre_default: [Genre, FalseClass, NilClass] Specify false to leave it unspecified, i.e., if you don't expect Genre at all.
    # @param engage_how_default: [EngageHow, FalseClass, NilClass] Specify false to leave it unspecified.
    # @return [Hash]
    def convert_csv_to_hash(csv, genre_default: nil, engage_how_default: nil)
      mu_csv_format = self.const_get(:MUSIC_CSV_FORMAT)
      i_of_csv = array_to_hash(mu_csv_format)
      genre_default ||= Genre.default
      engage_how_default ||= EngageHow.default
      mu_csv_format.map{ |ek|
        [ek, convert_csv_to_hash_core(
           ek,
           csv[i_of_csv[ek]],
           genre_default: genre_default,
           engage_how_default: engage_how_default
         )]
      }.to_h
    end

    # Returns a converted Object.
    #
    # Note neither {Genre} nor {EngageHow} should neve be nil.
    # If nil, the input is ill-formatted.
    #
    # @param ek [Symbol] as in {Music::MUSIC_CSV_FORMAT} or {HaramiVid::MUSIC_CSV_FORMAT}
    # @param str_in [String, NilClass] CSV cell
    # @param genre_default: [Genre, FalseClass, NilClass] (to avoid accessing DB every time this is called.) If false (Def), nothing is set. If nil, Default one is set.
    # @param engage_how_default: [EngageHow, FalseClass, NilClass]
    # @return [NilClass, String, Integer, Genre, EngageHow, Place]
    def convert_csv_to_hash_core(ek, str_in, genre_default: false, engage_how_default: false)
      genre_default = Genre.default if genre_default.nil?
      engage_how_default = EngageHow.default if engage_how_default.nil?
      str = (str_in ? str_in.strip : nil)
      str = nil if str.blank?
      case ek.to_s
      when 'row', 'header', /_(ja|en|note)/, 'ruby', 'romaji'
        str
      when 'artist'
        record_or_title_from_integer(str, Artist, search_integer_title: true)
      when 'langcode'
        str ? str.downcase : nil
      when 'memo'
        str ? preprocess_space_zenkaku(str) : nil
      when 'timing'
        hms2sec(str, blank_is_nil: true)   # converts from HH:MM:SS to Integer seconds; defined in ModuleCommon
      when 'year', /_(id)\s*\z/  # event_item_id
        (str && /\A\d+\z/ =~ str) ? str.to_i : nil  # nil if a non-number-like String
      when 'genre'
        if str
          if /^\d+$/ =~ str
            Genre.find_by_id(str.to_i) || nil
          else
            Genre[/#{Regexp.quote(str)}/i]
          end
        elsif !genre_default
          raise ArgumentError, "genre_default must be specified (nil or else)."
        else
          genre_default
        end
      when 'how'
        if str
          if /^\d+$/ =~ str
            EngageHow.find_by_id(str.to_i) || nil
          else
            EngageHow[/#{Regexp.quote(str)}/i]
          end
        elsif !engage_how_default
          raise ArgumentError, "engage_how_default must be specified (nil or else)."
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

    # Returns either String or ActiveRecord from the Integer-like title 
    #
    # If the given title contains anything else, this returns strip-ped String (or nil).
    # In default (+search_integer_title=true+), the record with the Integer-like title
    # is first searched for (e.g., "88888888" by Piki), and returned if found.
    # Then, ActiveRecord with the pID is returned, if present.
    # If not found, finally, regardless of +search_integer_title+, the String title is returned.
    #
    # @param str [String, NilClass] Input String
    # @param klass [Class] like Artist
    # @param search_integer_title: [Boolean] If true (Def), the title with the number only is searched and has a high priority than pID.
    # @return [ActiveRecord, String, NilClass]
    def record_or_title_from_integer(str, klass, search_integer_title: true)
      return nil if str.blank?

      pidstr = str.strip
      return pidstr if /\A\d+\z/ !~ pidstr

      if search_integer_title && (record=klass.select_regex(:titles, pidstr, sql_regexp: true).distinct.first)
        record
      elsif klass.exists?(pidstr)
        klass.find(pidstr)
      else
        pidstr
      end
    end
  end # module ClassMethods

end # module ModuleCsvAux
