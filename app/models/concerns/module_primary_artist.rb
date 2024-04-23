# -*- coding: utf-8 -*-

# Common module to implement "self.primary" for {Artist} and similar
#
# @example
#   include ModulePrimaryArtist
#   ChannelOnwer.primary  # => primary ChannelOnwer
#
module ModulePrimaryArtist
  #def self.included(base)
  #  base.extend(ClassMethods)
  #end
  extend ActiveSupport::Concern  # In Rails, the 3 lines above can be replaced with this.

  module ClassMethods
    def primary(reload: false)
      if self.const_defined?(:PRIMARY) && self::PRIMARY && !reload
        return self::PRIMARY
      end
      
      rela_base = self.joins(:translations)
      tra = "translations"
      rela = rela_base.where(tra+".langcode" => "ja").where(tra+".romaji" => Rails.application.config.primary_artist_titles[:ja][:romaji])
      %w(title alt_title ruby romaji).each do |ec|
        %w(ja en).each do |lc|
          term = Rails.application.config.primary_artist_titles[lc][ec]
          rela = rela.or(rela_base.where(tra+".langcode" => lc).where(tra+"."+ec => term)) if term
        end
      end
      rela = rela.distinct

      count = rela.count 
      case count
      when 1
        return (self::PRIMARY ||= rela.first)
      when 0
        return nil
      end

      logger.warn("WARNING: Multiple primary #{self.name} are found: #{rela.all}")

      relas = []
      %w(title alt_title ruby).each do |ec|
        %w(ja en).each do |lc|
          term = Rails.application.config.primary_artist_titles[lc][ec]
          relas.push rela_base.where(tra+".langcode" => lc).where(tra+"."+ec => term) if term
          return (self::PRIMARY ||= relas.last) if 1 == relas.last.count
        end
      end

      logger.warn("WARNING: Multiple primary #{self.name} are found with more strict conditions, and the first one is returned.")
      return (self::PRIMARY ||= relas.first)
    end # primary(reload: false)
  end # module ClassMethods
end

