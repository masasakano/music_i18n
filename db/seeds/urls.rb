# coding: utf-8

require_relative("common.rb")  # defines: module Seeds
#require_relative("channel_platforms.rb")
#require_relative("site_categories.rb")
require_relative("domain_titles.rb")
require_relative("domains.rb")

# Model: Url
#
# NOTE: SiteCategory must be loaded beforehand!
module Seeds::Urls
  extend Seeds::Common

  # Corresponding Active Record class
  RECORD_CLASS = self.name.split("::")[-1].singularize.constantize # Domain

  # Everything is a function
  module_function

  # Data to seed
  SEED_DATA = {
  }.with_indifferent_access  # SEED_DATA

  weights = {
    base: {},
    lang: {},
  }.with_indifferent_access

  # Constructing seeds from Domain, using DomainTitle
  Seeds::Domains::SEED_DATA.each_pair do |epk, hs_domain|
    next if /_short$/ =~ epk.to_s
    url_langcode = nil
    if /_([a-z]{2})$/ =~ epk.to_s && I18n.available_locales.map(&:to_s).include?($1)
      url_langcode = $1
    end

    key_dt = hs_domain[:domain_title_key]
    cur_weight =
      if url_langcode
        weights[:lang][key_dt] = (weights[:lang][key_dt] ? weights[:lang][key_dt] + 500 : 500)
      else
        weights[:base][key_dt] = (weights[:base][key_dt] ? weights[:base][key_dt] + 10 : 10)
      end  # Setting non-duplicate weights

    hs_dt = Seeds::DomainTitles::SEED_DATA[key_dt]
    raise "ERROR: inconsistent! No DomainTitles data found for the key #{[epk, key_dt].inspect}" if !hs_dt

    u_url = "https://" + hs_domain[:domain]
    u_norm = Url.normalized_url(u_url)
    next if SEED_DATA.find{ |_, val| u_norm == val[:url_normalized] }  # Virtually identical urls for the top-level URI for a Doamin are excluded (like www.youtube.com and youtube.com and youtu.be, while twitter.com and x.com are regarded separate)

    SEED_DATA[epk] = { 
      orig_langcode: hs_dt[:orig_langcode],
      url: u_url,
      url_normalized: u_norm,
      domain:     Proc.new{Domain.find_by(domain: hs_domain[:domain])},
      domain_key: epk,
      url_langcode: url_langcode,
      weight: cur_weight,
      # published_date: nil,
      # last_confirmed_date: nil,
      # create_user: nil,
      # update_user: nil,
      # note: nil,
      # memo_editor: nil,
    }

    ## adds Translation-s to SEED_DATA
    I18n.available_locales.each do |lc|
      if :unknown == epk.to_sym
        SEED_DATA[epk][lc] = RECORD_CLASS::UNKNOWN_TITLES[lc]
        next
      end

      ref = Seeds::DomainTitles::SEED_DATA[key_dt][lc]
      next if ref.blank?
      if !url_langcode
        SEED_DATA[epk][lc] =
          if SEED_DATA.find{ |_, val| ref == val[lc] }
            sprintf('%s (%s)', ref, epk.to_s.camelize)  # DomainTitle's Translation has been already taken because of multiple domains like the case of x.com and twitter.com
          else
            ref
          end
        next
      end

      SEED_DATA[epk][lc] = [ref].flatten.map{|es|
        sprintf('%s (%s)', es, url_langcode)
      }
    end
  end  # Seeds::Domains.each_pair do |epk, hs_domain|

  # this is properly set by load_seeds (the contents may be existing ones or new ones)
  MODELS = SEED_DATA.keys.map{|i| [i, nil]}.to_h

  #SEED_DATA.each_pair{|k, ehs|
  #  ehs[:domain_key] ||= k.to_sym
  #}

  # Main routine to seed.
  #
  # Constant Hash MODELS is set so that the seeded models are accessible.
  #
  # @return [Integer] Number of created/updated entries
  def load_seeds
    _load_seeds_core(%i(url url_normalized domain url_langcode weight published_date last_confirmed_date create_user update_user note memo_editor), find_by: :url_normalized)  # defined in seeds/common.rb, using RECORD_CLASS
      
  end

end  # module Seeds::Channels

