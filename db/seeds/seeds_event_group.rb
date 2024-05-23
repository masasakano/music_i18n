# coding: utf-8

include ModuleCommon  # for seed_fname2print

puts "DEBUG: start "+seed_fname2print(__FILE__) if $DEBUG
# This seed script can run in any environment or condition (see /seeds/users.rb for an environment-specific one).

# Model: EventGroup
#
# NOTE: Place must be loaded beforehands!
module SeedsEventGroup
  include ModuleCommon  # for DEF_EVENT_START_YEAR etc

  # Everything is a function
  module_function

  Places = {
    world: nil,
    japan: nil,
  }

  japan = Country[/日本/]  # '日本国' exactly in default, but it may change in the future.
  place_world = Place.unknown(country: Country.unknown)
  place_japan = Place.unknown(country: japan)

  get_place = Proc.new{|key|
    case key.to_sym
    when :world
      Place.unknown #(country: Country.unknown)
    when :japan
      Place.unknown(country: japan)
    when :miyazaki
      Place.unknown(prefecture: Prefecture[/宮崎/])
    else
      raise "invalid key: #{key}"
    end
  }

  # This is for running this module the second time, where Place-s are gone (and hence the original place_id are invalid!)
  # This happens when testing seeds with /test/seeds/seeds_test.rb where multiple attempts are deliberately made.
  GET_PLACE_PROC = get_place

  # product models (or guessed, if existing)
  MODELS = {
    unknown: nil,
    single_streets: nil,
    street_events: nil,
    harami_guests: nil,
    harami_concerts: nil,
    harami_jp2022s: nil,
    harami_jp2023s: nil,
    drop2022s: nil,
  }

  max_error_day = TimeAux::MAX_ERROR.in_days.ceil + 1  # = 3652060 [days]

  # Data to seed
  SEED_DATA = [
    {
      ja: 'その他のイベント類',
      en: 'UncategorizedEventGroup',
      fr: "Groupe d'événements non classé",
      orig_langcode: 'en',
      start_date: TimeAux::DEF_FIRST_DATE_TIME,
      start_date_err: max_error_day,
      end_date:   TimeAux::DEF_LAST_DATE_TIME,
      end_date_err:   max_error_day,
      place: place_world,
      place_key: :world,
      note: '他のどれにも分類されない一般的イベント類(結婚式招待など)',
      regex: /(Uncategorized|Unknown)\s*Event\s*Group/i,
      key: :unknown,
    },
    {
      ja: "単発ストリート演奏",
      en: "Single-shot street playing",
      start_date: TimeAux::DEF_FIRST_DATE_TIME,
      start_date_err: max_error_day,
      end_date:   TimeAux::DEF_LAST_DATE_TIME,
      end_date_err:   max_error_day,
      place: place_world,
      place_key: :world,
      note: 'ふらっと立ち寄るストリートピアノ演奏など',
      regex: /(単発.*|独立)ストリート(ピアノ|演奏)|street +(music|play)/i,
      key: :single_streets,
    },
    {
      ja: "ストリートイベント",
      en: "Street events",
      start_date: TimeAux::DEF_FIRST_DATE_TIME,
      start_date_err: max_error_day,
      end_date:   TimeAux::DEF_LAST_DATE_TIME,
      end_date_err:   max_error_day,
      place: place_world,
      place_key: :world,
      note: '高松市田町フラワーフェスティバル2020など',
      regex: /street +event/i,
      key: :street_events,
    },
    {
      ja: "ハラミちゃんゲスト出演単発ライブ",
      en: "Single-shot concerts with HARAMIchan being an invited guest",
      start_date: Date.new(2021, 1, 29),
      start_date_err: 0,
      end_date:   TimeAux::DEF_LAST_DATE_TIME,
      end_date_err: 0,
      place: place_world,
      place_key: :world,
      note: '香美フェス2023など',
      regex: /ハラミちゃんゲスト|HARAMIchan.+guest|guest.+HARAMIchan/i,
      key: :harami_guests,
    },
    {
      ja: "ハラミちゃん主催単発ライブ",
      en: "HARAMIchan single-shot solo concerts",
      start_date: Date.new(2019, 12, 7),
      start_date_err: 0,
      end_date:   TimeAux::DEF_LAST_DATE_TIME,
      end_date_err: 0,
      place: place_world,
      place_key: :world,
      note: '武道館公演など',
      regex: /ハラミちゃん主催|single-shot +solo/i,
      key: :harami_concerts,
    },
    {
      ja: "生配信",
      en: "Live-streamings",
      start_date: Date.new(2019, 7, 1),
      start_date_err: max_error_day,
      end_date:   TimeAux::DEF_LAST_DATE_TIME,
      end_date_err:   max_error_day,
      place: place_japan,
      place_key: :japan,
      note: '自宅他からの生配信限定イベント',
      regex: /^(生配信|Live[\- ]stream(ings?)?\b)/i,
      key: :live_streamings,
    },
    {
      ja: "MVやスタジオ録音・録画",
      en: "MVs & recording in a studio etc",
      start_date: TimeAux::DEF_FIRST_DATE_TIME,
      start_date_err: 90,
      end_date:   TimeAux::DEF_LAST_DATE_TIME,
      end_date_err:   max_error_day,
      place: place_japan,
      place_key: :japan,
      note: nil,
      regex: /(MV.+スタジオ録|\b(MVs|music videos?)\b.+\brecording\b)/i,
      key: :mvs,
    },
    {
      ja: "ラジオ局収録",
      en: "Recording at/for a radio station",
      start_date: Date.new(2019, 12, 25),
      start_date_err: 3,
      end_date:   TimeAux::DEF_LAST_DATE_TIME,
      end_date_err:   max_error_day,
      place: place_japan,
      place_key: :japan,
      note: nil,
      regex: /^(ラジオ局|\bradio\b.+\b(station|studio)s?\b)/i,
      key: :radio,
    },
    {
      ja: "テレビ局収録",
      en: "Recording at/for a television station",
      start_date: Date.new(2020, 2, 10),
      start_date_err: 10,
      end_date:   TimeAux::DEF_LAST_DATE_TIME,
      end_date_err:   max_error_day,
      place: place_japan,
      place_key: :japan,
      note: nil,
      regex: /^(テレビ局|\b(television|tv)\b.+\b(station|studio)s?\b)/i,
      key: :tv,
    },
    {
      ja: "ハラミちゃん全国ツアー2022",
      en: "HARAMIchan All-Japan Tour 2022",
      orig_langcode: 'ja',
      start_date: Date.new(2022, 4, 2), 
      start_date_err: 0,
      end_date:   Date.new(2022, 7, 9),
      end_date_err: 0,
      place: place_japan,
      place_key: :japan,
      note: '宮城県仙台市(電力ホール)〜沖縄県那覇市(琉球新報ホール)',
      regex: /ハラミちゃん.*全国.*2022|HARAMIchan.+2022/i,
      key: :harami_jp2022s,
    },
    {
      ja: "ハラミちゃん47都道府県ピアノツアー2023",
      en: "HARAMIchan 47 Prefecture Piano Tour 2023",
      orig_langcode: 'ja',
      start_date: Date.new(2023, 4, 9),
      start_date_err: 0,
      end_date:   Date.new(2024, 1, 13),
      end_date_err: 0,
      place: place_japan,
      place_key: :japan,
      note: '埼玉県大宮市(ソニックシティ)〜東京都江東区(東京ガーデンシアター)',
      regex: /ハラミちゃん.*47都道府県|HARAMIchan.+47 +Prefecture/i,
      key: :harami_jp2023s,
    },
    {
      ja: "THE DROP FESTIVAL in Japan",
      en: "THE DROP FESTIVAL in Japan",
      orig_langcode: 'en',
      order_no: 1,
      start_date: Date.new(2022, 10, 29),
      start_date_err: 0,
      end_date:   Date.new(2022, 10, 30),
      end_date_err: 0,
      place: Place.unknown(prefecture: Prefecture[/宮崎/]),
      place_key: :miyazaki,
      note: 'THE DROP FESTIVAL日本初開催(青島こどものくに)、ハラミちゃん初の夏フェス参加',
      regex: /DROP +FES(TIVAL)?\b.+\bJAPAN\b/i,
      key: :drop2022s,
    },
  ] 

  # Main routine to seed.
  #
  # Constant Hash MODELS is set so that the seeded models are accessible.
  #
  # @return [Integer] Number of created/updated entries
  def load_seeds
    n_changed = 0

    SEED_DATA.each do |ehs|
      models = EventGroup.select_regex(:title, ehs[:regex])
      model = (models.empty? ? EventGroup.new : models.first)
      n_changed_cand = (model.new_record? ? 1 : 0)  # +1 for EventGroup

      %i(order_no start_date start_date_err end_date end_date_err place note).each do |ek|
        # If the column is set, it unchanges, but if not, it is set.
        next if model.send(ek).present? || ehs[ek].blank?
        n_changed_cand = 1  # (at least partly) modified, hence +1 in the increment
        model.send(ek.to_s+"=", ehs[ek])
        if ek==:place && ehs[ek] && !Place.exists?(ehs[ek].id)
          model.place = GET_PLACE_PROC.call(ehs[:place_key] || :world)
        end
      end

      begin
        model.save!  # EventGroup saved.  This should not raise an Exception, for Countries should have been already defined!
      rescue ActiveRecord::RecordInvalid
        msg = "ERROR(#{__FILE__}:#{__method__}): EventGroup#save! failed while attempting to save ja=(#{ehs[:ja]}).  This should never happen, except after a direct Database manipulation (such as DB migration rollback) has left some orphan Translations WITHOUT a parent; check out the log file for a WARNING message."
        warn msg
        Rails.logger.error msg
        raise
      end

      MODELS[ehs[:key]] = model
      n_changed += n_changed_cand

      ## Create Translation if not yet
      tras = model.best_translations
      is_orig_existing = nil
      %i(ja en fr).each do |lcode|
        next if !ehs.key?(lcode)
        if tras.key?(lcode)  # Translation of the language for EventGroup already defined?. If so, skip.
          # If is_orig==true is alraedy defined, is_orig in any of the associiated translations is not updated.
          is_orig_existing = lcode if tras[lcode].is_orig
          next
        end
        model.with_translation(langcode: lcode.to_s, title: ehs[lcode], is_orig: nil, weight: 90)
        if n_changed_cand == 0
          n_changed_cand = 1
          n_changed += 1   # +1 because of Translation update/creation (for an existing record)
        end
      end
      if !is_orig_existing && ehs[:orig_langcode]
        # is_orig is defined above and none
        t = model.best_translation(langcode: ehs[:orig_langcode])
        t.update!(is_orig: true)
      end
    end

    # Translations for the uncategorized/unknown have weight=0 (i.e., will be never modified).
    EventGroup.unknown.best_translations.each_value do |etra|
      etra.update!(weight: 0)
    end

    n_changed*7  # not accurate, but basically, per EventGroup, 1 Evnet, 2x2 Translations, and 1 EventItem are created.
  end  # def load_seeds

end  # module SeedsEventGroup

