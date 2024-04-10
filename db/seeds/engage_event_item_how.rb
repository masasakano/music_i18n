# coding: utf-8

require(File.dirname(__FILE__)+"/common.rb")  # defines: module Seeds

# Model: EngageEventItemHow
#
module Seeds::EngageEventItemHow
  extend Seeds::Common
  #include ModuleCommon  # for ...

  # Everything is a function
  module_function

  # Data to seed
  # NOTE: Make sure these to be consistent with /test/fixtures/engage_event_item_hows.yml and translations.yml
  SEED_DATA = {
    unknown: {
      ja: EngageEventItemHow::UNKNOWN_TITLES['ja'],
      en: EngageEventItemHow::UNKNOWN_TITLES['en'],
      fr: EngageEventItemHow::UNKNOWN_TITLES['fr'],
      orig_langcode: 'en',
      mname: "unknown",
      weight: 999,  # NOTE: The weight for this must be the DB-default 999.
      note: '何らかの関連があったもののそれが不明な場合',
      regex: /Unknown\s*Engage\s*EventItemHow/i,  # to check potential duplicates => NOT used b/c mname suffices (c.f., seeds_event_group.rb)
    },
    singer: {
      ja: "歌手",
      en: "Singer",
      mname: "singer",
      weight: 10,
      note: nil,
      regex: /^(歌手|singer)/i,
    },
    chorus: {
      ja: "コーラス",
      en: "Chorus",
      mname: "chorus",
      weight: 20,
      note: 'メインボーカルでない歌手',
      regex: /コーラス|chorus/i,
    },
    inst_player_main: {
      ja: "主要な楽器演奏者",
      en: "Main Instrument Player",
      mname: "inst_player_main",
      weight: 30,
      note: '主要な楽器演奏者',
      regex: /主\*楽器演奏者|main.*player/i,
    },
    inst_player: {
      ja: "楽器演奏者",
      en: "Instrument Player",
      mname: "inst_player",
      weight: 40,
      note: '一般の楽器演奏者',
      regex: /^(楽器演奏者|(instrument\s*)player)/i,
    },
    conductor: {
      ja: "指揮者",
      en: "Conductor",
      mname: "conductor",
      weight: 50,
      note: nil,
      regex: /指揮者|Conductor/i,
    },
    host: {
      ja: "ホスト",
      en: "Host",
      mname:  "host",
      weight: 110,
      note: "看板番組などのホスト",
      regex: /ホスト|Host/i,
    },
    mc: {
      ja: "司会者",
      en: "MC",
      mname: "mc",
      weight: 120,
      note: "ホストではない(イベントなどの)司会者",
      regex: /^(司会者|MC)$/i,
    },
    guest_main: {
      ja: "メインゲスト",
      en: "Main Guest",
      mname: "guest_main",
      weight: 130,
      note: nil,
      regex: /メインゲスト|main.*guest/i,
    },
    guest: {
      ja: "ゲスト",
      en: "Guest",
      mname: "guest",
      weight: 140,
      note: nil,
      regex: /\A(ゲスト|guest)/i,
    },
    producer: {
      ja: "プロデューサー",
      en: "Producer",
      mname: "producer",
      weight: 210,
      note: nil,
      regex: /プロデューサー|producer/i,
    },
    staff: {
      ja: "スタッフ",
      en: "Staff",
      mname: "staff",
      weight: 220,
      note: nil,
      regex: /スタッフ|staff/i,
    },
    helper: {
      ja: "協力者",
      en: "Helper",
      mname: "helper",
      weight: 230,
      note: nil,
      regex: /協力.*者|helper/i,
    },
    spectator: {
      ja: "観客",
      en: "Spectator",
      mname: "spectator",
      weight: 310,
      note: nil,
      regex: /観客|spectator/i,
    },
    visitor: {
      ja: "訪問客",
      en: "Visitor",
      mname: "visitor",
      weight: 320,
      note: nil,
      regex: /訪問客|visitor/i,
    },
    other: {
      ja: "その他",
      en: "Other",
      mname: "other",
      weight: 410,
      note: nil,
      regex: /その他|other/i,
    },
  } 

  # this is properly set by load_seeds (the contents may be existing ones or new ones)
  MODELS = SEED_DATA.keys.map{|i| [i, nil]}.to_h

  # Main routine to seed.
  #
  # Constant Hash MODELS is set so that the seeded models are accessible.
  #
  # @return [Integer] Number of created/updated entries
  def load_seeds
    n_changed = 0

    SEED_DATA.each_pair do |key, ehs|
      model = EngageEventItemHow.find_or_initialize_by(mname: ehs[:mname])
      n_changed += model_save(model, ehs, attrs: %i(weight note))  # defined in seeds_common.rb
      MODELS[key] = model.reload

      n_changed += translation_save(model, ehs)  # defined in seeds_common.rb
    end

    n_changed
  end  # def load_seeds

end  # module Seeds::EngageEventItemHow

