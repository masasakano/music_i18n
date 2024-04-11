# coding: utf-8

require(File.dirname(__FILE__)+"/common.rb")  # defines: module Seeds

# Model: Instrument
#
module Seeds::Instrument
  extend Seeds::Common

  # Corresponding Active Record class
  RECORD_CLASS = self.name.split("::")[-1].constantize # Instrument

  # Everything is a function
  module_function

  # Data to seed
  SEED_DATA = {
    unknown: {
      ja: RECORD_CLASS::UNKNOWN_TITLES['ja'],
      en: RECORD_CLASS::UNKNOWN_TITLES['en'],
      fr: RECORD_CLASS::UNKNOWN_TITLES['fr'],
      orig_langcode: 'en',
      weight: 999,  # NOTE: The weight for this must be the DB-default 999.
      note: '楽器を使ったにせよそうでないにせよそれが不明な場合',
      regex: Proc.new{RECORD_CLASS.unknown}  # to check potential duplicates for Instrument
    },
    vocal: {
      ja: "歌手",
      en: "Vocal",
      weight: 10,
      note: nil,
      regex: /^(歌手|singer)/i,
    },
    voice_percussion: {
      ja: ["ボイスパーカッション", "ボイパ"],
      en: "Voice percussion",
      weight: 20,
      regex: /ボイスパーカッション|voice percussion/i,
    },
    piano: {
      ja: "ピアノ",
      en: "Piano",
      weight: 30,
      regex: /^(ピアノ|piano)/i,
    },
    keyboard: {
      ja: "キーボード",
      en: "Keyboard",
      weight: 40,
      note: "including synthesizers", 
      regex: /キーボード|keyboard/i,
    },
    organ: {
      ja: "オルガン",
      en: "Organ",
      weight: 50,
      regex: /オルガン|organ/i,
    },
    guitar: {
      ja: "ギター",
      en: "Guitar",
      weight: 110,
      regex: /ギター|guitar/i,
    },
    bass_guitar: {
      ja: "ベース",
      en: "Bass-guitar",
      weight: 120,
      regex: /ベース|\bbass([\- _]guitar)?/i,
    },
    uklele: {
      ja: "ウクレレ",
      en: "Uklele",
      weight: 130,
      regex: /ウクレレ|uklele/i,
    },
    violin: {
      ja: ["バイオリン", "ヴァイオリン"],
      en: "Violin",
      weight: 210,
      regex: /バイオリン|violin/i,
    },
    viola: {
      ja: ["ヴィオラ", "ビオラ"],
      en: "Viola",
      weight: 220,
      regex: /ヴィオラ|viola/i,
    },
    cello: {
      ja: "チェロ",
      en: "Cello",
      weight: 230,
      regex: /チェロ|cello/i,
    },
    contrabass: {
      ja: ["コントラバス", "ウッドベース"],
      en: ["Double bass", "Bass"],
      weight: 240,
      regex: /^(コントラバス|ウッドベース|(?:double[ \-_]+)?bass)$/i,
    },
    strings: {
      ja: "弦楽器",
      en: "Strings",
      weight: 290,
      regex: /^(弦(楽器)?|strings)$/i,
    },
    flute: {
      ja: "フルート",
      en: "Flute",
      weight: 310,
      regex: /フルート|flute/i,
    },
    woodwind: {
      ja: "木管楽器",
      en: "Woodwind",
      weight: 390,
      regex: /木管楽器|woodwind/i,
    },
    trumpet: {
      ja: "トランペット",
      en: "Trumpet",
      weight: 410,
      regex: /トランペット|trumpet/i,
    },
    brass: {
      ja: ["金管楽器", "ブラス"],
      en: "Brass",
      weight: 490,
      regex: /金管楽器|brass/i,
    },
    drums: {
      ja: "ドラム",
      en: "Drums",
      weight: 510,
      regex: /ドラム|drums?\b/i,
    },
    percussion: {
      ja: "打楽器",
      en: "Percussion",
      weight: 590,
      regex: /打楽器|percussion/i,
    },
    mixer: {
      ja: "ミクサー",
      en: "Mixer",
      weight: 610,
      regex: /ミクサー|mixer/i,
    },
    conductor: {
      ja: "指揮",
      en: "Conductor",
      weight: 710,
      regex: /指揮|conductor/i,
    },
    other: {
      ja: "その他",
      en: "Other",
      weight: 950,
      note: nil,
      regex: /その他|other/i,
    },
    not_applicable: {
      ja: "適用外",
      en: "Not applicable",
      weight: 980,
      note: nil,
      regex: /適用外|not[_ \-]+applicable/i,
    },
  }.with_indifferent_access  # SEED_DATA
  SEED_DATA.each_value{|eh| eh.with_indifferent_access}

  # this is properly set by load_seeds (the contents may be existing ones or new ones)
  MODELS = SEED_DATA.keys.map{|i| [i, nil]}.to_h

  # Main routine to seed.
  #
  # Constant Hash MODELS is set so that the seeded models are accessible.
  #
  # @return [Integer] Number of created/updated entries
  def load_seeds
    _load_seeds_core(%i(weight note))  # defined in seeds_common.rb, using Instrument (==RECORD_CLASS)
  end

end  # module Seeds::Instrument

