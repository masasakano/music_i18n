# -*- coding: utf-8 -*-

# Common module to implement "self.primary" for {Artist} and similar
#
# @example
#   include ModulePrimaryArtist
#   ChannelOnwer.primary  # => primary ChannelOnwer
#
module ModuleGuessPlace
  #def self.included(base)
  #  base.extend(ClassMethods)
  #end
  extend ActiveSupport::Concern  # In Rails, the 3 lines above can be replaced with this.

  module ClassMethods
    # Guesses a {Place} from the given String and returns it
    #
    # If nothing is found, unknown Place of the def_country is returned.
    # If it is set nil AND nothing is found, +fallback+ is returned (Default is {Place.unknown})
    #
    # @example If you want nil to be returned if nothing matches
    #    Harami1129.guess_place(strin, def_country: nil, fallback: nil)
    #
    # @param strin [String]
    # @param def_country: [String, NilClass] country code (like "GBR") for the default country. If nil, world.
    # @param fallback: [Object] the last resort if def_country is nil and finding nothing.
    # @return [Place]
    def guess_place(strin, def_country: Rails.application.config.primary_country, fallback: Place.unknown)
      hsbase = {langcode: 'ja', sql_regexp: true}
      cand_hash = _guess_place_data(strin)

      ret = Place.select_regex(:titles, cand_hash[:place], **hsbase).first if cand_hash[:place]
      return ret if ret

      pref =
        if (cond=cond=cand_hash[:prefecture]).respond_to?(:named_captures)
          Prefecture.select_regex(:titles, cond, **hsbase).first
        elsif cond.respond_to?(:divmod) || cond.respond_to?(:gsub)
          Prefecture[cond]
        else
          nil
        end
      return Place.unknown(prefecture: pref) if pref

      cnt =
        if (cond=cand_hash[:country]).respond_to?(:named_captures)
          Country.select_regex(:titles, cond, **hsbase).first
        elsif cond.respond_to?(:divmod) || cond.respond_to?(:gsub)
          Country[cond]
        else
          nil
        end
      return Place.unknown(country: cnt) if cnt

      (def_country.present? && Place.unknown(country: Country[def_country])) || fallback
    end

    def _guess_place_data(strin)
      cand_hash = {
        place: nil,
        prefecture: nil, # For Prefecture, iso3166_loc_code is allowed (in future)
        country: nil,    # For country, the standard code is allowed
      }

      case strin
      when /都庁/
        cand_hash[:place]      = /都庁/
        cand_hash[:prefecture] = /東京/
      when /([\p{Han}]+)(?:駅|空港)/
        matched = $&
        matched_1st = $1
        cand_hash[:place]      = /#{Regexp.quote matched}/
        cand_hash[:prefecture] = /^#{Regexp.quote matched_1st}(県|府)?$/
        cand_hash[:country] = "JPN"
      when /東京|パリ|ロンドン/
        matched = $&
        cand_hash[:prefecture] = /#{Regexp.quote matched}/
        case matched
        when "パリ"
          cand_hash[:country] = "FRA"
        when "ロンドン"
          cand_hash[:country] = "GBR"
        else
        end
      when /フランス/
        cand_hash[:country] = "FRA"
      when /イギリス|英国/
        cand_hash[:country] = "GBR"
      end

      cand_hash
    end
    private :_guess_place_data
  end # module ClassMethods
end

