# coding: utf-8

require_relative("common.rb")  # defines: module Seeds
require_relative("channel_platforms.rb")
require_relative("site_categories.rb")

# Model: DomainTitle
#
# NOTE: SiteCategory must be loaded beforehand!
module Seeds::DomainTitles
  extend Seeds::Common

  # Corresponding Active Record class
  RECORD_CLASS = self.name.split("::")[-1].singularize.constantize # DomainTitle

  # Everything is a function
  module_function

  # Data to seed
  SEED_DATA = {
    unknown: {
      ja: RECORD_CLASS::UNKNOWN_TITLES['ja'],
      en: RECORD_CLASS::UNKNOWN_TITLES['en'],
      fr: RECORD_CLASS::UNKNOWN_TITLES['fr'],
      orig_langcode: 'en',
      weight: 10,
      # site_category: Proc.new{SiteCategory.unknown(reload: true)},
      site_category: Proc.new{SiteCategory.find_by(mname: "unknown") || raise(SiteCategory.all.inspect)},
      site_category_key: :unknown,  # used for test fixtures /test/fixtures/domain_titles.yml
      note: nil,
      memo_editor: nil,
      regex: Proc.new{RECORD_CLASS.unknown}  # to check potential duplicates for DomainTitle
    },
    haramichan_main: {
      ja: ['ハラミちゃんホームページ', 'ハラミちゃん'],
      en: ["HARAMIchan website", 'Harami-chan'],
      orig_langcode: 'ja',
      weight: 10,
      site_category: Proc.new{SiteCategory.find_by(mname: "main")},
      site_category_key: :main,
    },
    kohmi_main: {
      ja: ['広瀬香美ホームページ', '広瀬香美'],
      en: ["Kohmi Hirose Official Website", 'Kohmi Hirose'],
      orig_langcode: 'ja',
      weight: 10,
      site_category: Proc.new{SiteCategory.find_by(mname: "main")},
      site_category_key: :main,
    },
    youtube: {
      ja: Seeds::ChannelPlatforms::SEED_DATA[:youtube][:ja],
      en: Seeds::ChannelPlatforms::SEED_DATA[:youtube][:en],
      fr: Seeds::ChannelPlatforms::SEED_DATA[:youtube][:fr],
      orig_langcode: 'en',
      site_category: Proc.new{SiteCategory.find_by(mname: "main")},
      site_category_key: :main,
    },
    tiktok: {
      ja: Seeds::ChannelPlatforms::SEED_DATA[:tiktok][:ja],
      en: Seeds::ChannelPlatforms::SEED_DATA[:tiktok][:en],
      orig_langcode: 'en',
      site_category: Proc.new{SiteCategory.find_by(mname: "main")},
      site_category_key: :main,
    },
    instagram: {
      ja: Seeds::ChannelPlatforms::SEED_DATA[:instagram][:ja],
      en: Seeds::ChannelPlatforms::SEED_DATA[:instagram][:en],
      orig_langcode: 'en',
      site_category: Proc.new{SiteCategory.find_by(mname: "main")},
      site_category_key: :main,
    },
    twitter: {
      ja: Seeds::ChannelPlatforms::SEED_DATA[:twitter][:ja],
      en: Seeds::ChannelPlatforms::SEED_DATA[:twitter][:en],
      orig_langcode: 'en',
      site_category: Proc.new{SiteCategory.find_by(mname: "main")},
      site_category_key: :main,
    },
    wikipedia: {
      ja: Seeds::ChannelPlatforms::SEED_DATA[:wikipedia][:ja],
      en: Seeds::ChannelPlatforms::SEED_DATA[:wikipedia][:en],
      orig_langcode: 'en',
      site_category: Proc.new{SiteCategory.find_by(mname: "wikipedia")},
      site_category_key: :wikipedia,
    },
    chronicle_harami: {  # Make sure this is the first seeded one in SiteCategory.mname == "chronicle". See /app/controllers/base_anchorables_controller.rb
      ja: Seeds::ChannelPlatforms::SEED_DATA[:harami_event_list][:ja],
      en: Seeds::ChannelPlatforms::SEED_DATA[:harami_event_list][:en],
      orig_langcode: 'ja',
      weight: 10,
      site_category: Proc.new{SiteCategory.find_by(mname: "chronicle")},
      site_category_key: :chronicle,
    },
  }.with_indifferent_access  # SEED_DATA

  # this is properly set by load_seeds (the contents may be existing ones or new ones)
  MODELS = SEED_DATA.keys.map{|i| [i, nil]}.to_h

  # Main routine to seed.
  #
  # Constant Hash MODELS is set so that the seeded models are accessible.
  #
  # @return [Integer] Number of created/updated entries
  def load_seeds
    _load_seeds_core(%i(weight site_category note memo_editor))  # defined in seeds/common.rb, using RECORD_CLASS
  end

end  # module Seeds::Channels

