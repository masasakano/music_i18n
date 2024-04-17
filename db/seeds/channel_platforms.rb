# coding: utf-8

require(File.dirname(__FILE__)+"/common.rb")  # defines: module Seeds

# Model: ChannelPlatforms
#
module Seeds::ChannelPlatforms
  extend Seeds::Common

  # Corresponding Active Record class
  RECORD_CLASS = self.name.split("::")[-1].singularize.constantize # ChannelPlatform

  # Everything is a function
  module_function

  # Data to seed
  SEED_DATA = {
    unknown: {
      ja: RECORD_CLASS::UNKNOWN_TITLES['ja'],
      en: RECORD_CLASS::UNKNOWN_TITLES['en'],
      fr: RECORD_CLASS::UNKNOWN_TITLES['fr'],
      orig_langcode: 'en',
      note: nil,
      #regex: Proc.new{RECORD_CLASS.unknown}  # to check potential duplicates for ChannelPlatforms
    },
    youtube: {
      ja: ["Youtube", "ユーチューブ"],
      en: "Youtube",
      fr: "Youtube",
      note: nil,
    },
    tiktok: {
      ja: "Tiktok",
      en: "Tiktok",
    },
    instagram: {
      ja: ["Instagram", "インスタグラム"],
      en: "Instagram",
    },
    twitter: {
      ja: ["Twitter/X", "X(旧ツイッター)"],
      en: "Twitter/X",
    },
    facebook: {
      ja: ["Facebook", "フェイスブック"],
      en: "Facebook",
    },
    wikipedia: {
      ja: ["Wikipedia", "ウィキペディア"],
      en: "Wikipedia",
    },
    harami_event_list: {
      ja: ["ハラミちゃん活動の記録"],
      en: "Harami Chronicle",
    },
    other: {
      ja: 'その他のプラットフォーム',
      en: 'Other platforms',
      fr: 'Estrades inconnues',
      note: nil,
      regex: /(^その他|^other| inconnu)/i,
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
    _load_seeds_core(%i(mname note), find_by: :mname)  # defined in seeds_common.rb, using Instrument (==RECORD_CLASS)
  end

end  # module Seeds::ChannelPlatforms

