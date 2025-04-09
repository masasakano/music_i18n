# coding: utf-8

require_relative("common.rb")  # defines: module Seeds

# Model: SiteCategory
#
# NOTE: This has to be loaded before Uri.
module Seeds::SiteCategories
  extend Seeds::Common

  # Corresponding Active Record class
  RECORD_CLASS = self.name.split("::")[-1].singularize.constantize # SiteCategory

  # Everything is a function
  module_function

  # Data to seed  (mname is later added below, ensuring it coincides with the key name)
  SEED_DATA = {
    unknown: {
      ja: RECORD_CLASS::UNKNOWN_TITLES['ja'],
      en: RECORD_CLASS::UNKNOWN_TITLES['en'],
      fr: RECORD_CLASS::UNKNOWN_TITLES['fr'],
      orig_langcode: 'en',
      weight: 0,
      summary:  "Unknown category",
      note: nil,
      memo_editor: nil,
      #regex: Proc.new{RECORD_CLASS.unknown}  # to check potential duplicates for ...
    },
    main: {
      ja: '主サイト/ホームページ',
      en: ['Primary/Home page'],
      orig_langcode: nil,
      weight: 10,
      summary: "Homepage",
    },
    wikipedia: {
      ja: 'Wikipedia',
      en: ['Wikipedia'],
      orig_langcode: 'en',
      weight: 100,
      summary: nil,
    },
    encyclopedia: {
      ja: '百科事典',
      en: ['Encyclopedia'],
      orig_langcode: nil,
      weight: 120,
      summary: "Encyclopedia except Wikipedia",
    },
    chronicle: {
      ja: '年表',
      en: 'Chronicle',
      orig_langcode: nil,
      weight: 200,
      summary: nil,
    },
    media: {
      ja: ['マスメディア', 'メディア'],
      en: 'Media',
      orig_langcode: nil,
      weight: 500,
      summary: "Press release and public announcements",
    },
    pr: {
      ja: 'プレスリリース',
      en: 'Press release',
      orig_langcode: nil,
      weight: 700,
      summary: nil,
    },
    other: {
      ja: 'その他',
      en: ['Other', 'Miscellaneous'],
      orig_langcode: 'en',
      weight: 999,
      summary: nil,
    },
  }.with_indifferent_access  # SEED_DATA

  SEED_DATA.each_pair do |ek, ev|
    ev[:mname] = ek  # unique key
  end

  # this is properly set by load_seeds (the contents may be existing ones or new ones)
  MODELS = SEED_DATA.keys.map{|i| [i, nil]}.to_h

  # Main routine to seed.
  #
  # Constant Hash MODELS is set so that the seeded models are accessible.
  #
  # @return [Integer] Number of created/updated entries
  def load_seeds
    _load_seeds_core(%i(mname weight summary note), find_by: :mname)  # defined in seeds_common.rb, using Instrument (==RECORD_CLASS)
  end

end  # module Seeds::SiteCategories

