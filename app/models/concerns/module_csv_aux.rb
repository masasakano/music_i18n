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
      sprintf "#<#{base.name}::RLC: %s>", self::MUSIC_CSV_FORMAT.map{|i| (res=send(i)) ? sprintf("@%s=%s", i.to_s, res.inspect) : nil}.compact.join(", ")
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
      when 'row', /_(ja|en)/, 'ruby', 'romaji'
        str
      when 'artist'
        model_instance_or_title(str, Artist, search_integer_title: true)
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

    # @param str [String, NilClass] Input String
    # @param klass [Class] like Artist
    # @param search_integer_title: [Boolean] If true (Def), the title with the number only is searched and has a high priority than pID.
    # @return [ActiveRecord, String, NilClass]
    def model_instance_or_title(str, klass, search_integer_title: true)
      return nil if str.blank?

      pidstr = str.strip
      return pidstr if /\A\d+\z/ !~ pidstr

      if search_integer_title && (ret == klass.select_regex(:titles, pidstr, sql_regexp: true).distinct.first)
        ret
      else
        klass.find(pidstr)   # may raise ActiveRecord::RecordNotFound  # you may check it beforehand with  Artist.exists?(pidstr)
      end
    end
  end # module ClassMethods

end # module ModuleCsvAux
