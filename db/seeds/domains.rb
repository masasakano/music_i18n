# coding: utf-8

require_relative("common.rb")  # defines: module Seeds
#require_relative("channel_platforms.rb")
#require_relative("site_categories.rb")
require_relative("domain_titles.rb")

# Model: Domain
#
# NOTE: SiteCategory must be loaded beforehand!
module Seeds::Domains
  extend Seeds::Common

  # Corresponding Active Record class
  RECORD_CLASS = self.name.split("::")[-1].singularize.constantize # Domain

  # Everything is a function
  module_function

  # Data to seed
  SEED_DATA = {
    unknown: {
      domain: "www.example.com",
      domain_title: Proc.new{DomainTitle.unknown(reload: true) || raise(DomainTitle.all.inspect)},
      domain_title_key: :unknown,  # used for test fixtures /test/fixtures/domains.yml
      weight: 0,
      note: nil,
      # regex: Proc.new{RECORD_CLASS.unknown}  # to check potential duplicates for Domain
    },
    haramichan_main: {
      domain: "harami-piano.com",
      domain_title: Proc.new{DomainTitle.select_regex(:titles, /^ハラミちゃん(.*(ホームページ|ウェブサイト|Website))$/ || raise(DomainTitle.all.inspect)).first},
      domain_title_key: :haramichan_main,  # defined ./domain_titles.rb ; used for test fixtures /test/fixtures/domains.yml
      weight: 10,
    },
    youtube: {
      domain: "www.youtube.com",
      domain_title: Proc.new{DomainTitle.select_regex(:titles, /\Ayoutube\z/i || raise(DomainTitle.all.inspect)).first},
      # domain_title_key: :youtube,  # set below in one go as the default.
      weight: 10,
    },
    youtube_short: {  # "*_short" is ignored in seeding Uri-s (see uris.rb)
      domain: "youtu.be",
      domain_title: Proc.new{DomainTitle.select_regex(:titles, /\Ayoutube\z/i || raise(DomainTitle.all.inspect)).first},
      # domain_title_key: :youtube,  # set below in one go as the default.
      domain_title_key: :youtube,  # defined ./domain_titles.rb ; used for test fixtures /test/fixtures/domains.yml
      weight: 1000,
    },
    tiktok: {
      domain: "www.tiktok.com",
      domain_title: Proc.new{DomainTitle.select_regex(:titles, /\Atiktok\z/i || raise(DomainTitle.all.inspect)).first},
      weight: 10,
    },
    instagram: {
      domain: "www.instagram.com",
      domain_title: Proc.new{DomainTitle.select_regex(:titles, /\Ainstagram\z/i || raise(DomainTitle.all.inspect)).first},
      weight: 10,
    },
    twitter: {
      domain: "www.twitter.com",
      domain_title: Proc.new{DomainTitle.select_regex(:titles, /\Atwitter(\/X)?\z/i || raise(DomainTitle.all.inspect)).first},
      weight: 100,
    },
    x: {
      domain: "www.x.com",
      domain_title: Proc.new{DomainTitle.select_regex(:titles, /\Atwitter(\/X)?\z/i || raise(DomainTitle.all.inspect)).first},
      domain_title_key: :twitter,  # defined ./domain_titles.rb ; used for test fixtures /test/fixtures/domains.yml
      weight: 90,
    },
    wikipedia: {
      domain: "wikipedia.org",
      domain_title: Proc.new{DomainTitle.select_regex(:titles, /\Awikipedia\z/i || raise(DomainTitle.all.inspect)).first},
      weight: 10,
    },
    wikipedia_en: {  # "*_en" specifies the langcode in seeding Uri-s (see uris.rb)
      domain: "en.wikipedia.org",
      domain_title: Proc.new{DomainTitle.select_regex(:titles, /\Awikipedia\z/i || raise(DomainTitle.all.inspect)).first},
      domain_title_key: :wikipedia,  # defined ./domain_titles.rb ; used for test fixtures /test/fixtures/domains.yml
      weight: 100,
    },
    wikipedia_ja: {  # "*_ja" specifies the langcode in seeding Uri-s (see uris.rb)
      domain: "ja.wikipedia.org",
      domain_title: Proc.new{DomainTitle.select_regex(:titles, /\Awikipedia\z/i || raise(DomainTitle.all.inspect)).first},
      domain_title_key: :wikipedia,  # defined ./domain_titles.rb ; used for test fixtures /test/fixtures/domains.yml
      weight: 110,
    },
    chronicle_harami: {
      domain: "nannohi-db.blog.jp",
      domain_title: Proc.new{DomainTitle.select_regex(:titles, /\A(Harami(\-?chan('?s)?)?\s*Chronicle\z|ハラミちゃん活動の記録(.+Chronicle|\z))/i || raise(DomainTitle.all.inspect)).first},
      weight: 10,
    },
  }.with_indifferent_access  # SEED_DATA

  # this is properly set by load_seeds (the contents may be existing ones or new ones)
  MODELS = SEED_DATA.keys.map{|i| [i, nil]}.to_h

  SEED_DATA.each_pair{|k, ehs|
    ehs[:domain_title_key] ||= k.to_sym
  }

  # Main routine to seed.
  #
  # Constant Hash MODELS is set so that the seeded models are accessible.
  #
  # @return [Integer] Number of created/updated entries
  def load_seeds
    _load_seeds_core(%i(domain domain_title weight note), find_by: :domain)  # defined in seeds/common.rb, using RECORD_CLASS
  end

end  # module Seeds::Channels

