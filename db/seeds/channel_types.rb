# coding: utf-8

require(File.dirname(__FILE__)+"/common.rb")  # defines: module Seeds

# Model: ChannelTypes
#
module Seeds::ChannelTypes
  extend Seeds::Common

  # Corresponding Active Record class
  RECORD_CLASS = self.name.split("::")[-1].singularize.constantize # ChannelType

  # Everything is a function
  module_function

  # Data to seed
  SEED_DATA = {
    unknown: {
      ja: RECORD_CLASS::UNKNOWN_TITLES['ja'],
      en: RECORD_CLASS::UNKNOWN_TITLES['en'],
      fr: RECORD_CLASS::UNKNOWN_TITLES['fr'],
      orig_langcode: 'en',
      weight: 999,  # DB default
      note: nil,
      #regex: Proc.new{RECORD_CLASS.unknown}  # to check potential duplicates for ChannelTypes
    },
    main: {
      ja: ["主チャンネル", "メイン"],
      en: ["Primary channel", "Primary"],
      fr: ["Chaine principale", "Principal"],
      weight:  10,
      note: nil,
    },
    sub: {
      ja: ["副チャンネル", "サブ"],
      en: ["Side channel", "Secondary"],
      weight:  30,
    },
    staff: {
      ja: "スタッフ",
      en: "Staff",
      weight: 110,
    },
    agent: {
      ja: "事務所",
      en: ["Managing agent", "Agent"],
      weight: 130,
    },
    media: {
      ja: ["メディア"],
      en: "Media",
      weight: 210,
    },
    encyclopedia: {
      ja: ["百科事典"],
      en: "Encyclopedia",
      weight: 310,
    },
    blog: {
      ja: ["ブログ"],
      en: "Blog",
      weight: 410,
    },
    fan: {
      ja: ["ファンサイト", "ファン"],
      en: "Fan",
      weight: 510,
    },
    other: {
      ja: ['その他のチャンネル', 'その他'],
      en: ['Other types', "Other"],
      fr: ["chaine diverse", "Divers"],
      weight: 950,
      note: nil,
      regex: /(^その他|^other|( ?|\b)diverse?)/i,
    },
  }.with_indifferent_access  # SEED_DATA
  SEED_DATA.each_pair do |ek, ev|
    ev[:mname] = ek  # unique key
  end
  SEED_DATA.each_value{|eh| eh.with_indifferent_access}

  # this is properly set by load_seeds (the contents may be existing ones or new ones)
  MODELS = SEED_DATA.keys.map{|i| [i, nil]}.to_h

  # Main routine to seed.
  #
  # Constant Hash MODELS is set so that the seeded models are accessible.
  #
  # @return [Integer] Number of created/updated entries
  def load_seeds
    _load_seeds_core(%i(mname weight note), find_by: :mname)  # defined in seeds_common.rb, using Instrument (==RECORD_CLASS)
  end

end  # module Seeds::ChannelTypes

