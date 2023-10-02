# coding: utf-8

include ModuleCommon  # for seed_fname2print

puts "DEBUG: start "+seed_fname2print(__FILE__) if $DEBUG
# This seed script can run in any environment or condition (see /seeds/users.rb for an environment-specific one).

# Model: ModelSummary
#
module SeedsModelSummaries
  # Everything is a function
  module_function

  # Data to seed
  SEED_DATA = {
    Artist: {
      ja: "アーティスト",
      en: "Artist",
    },
    Country: {
      ja: "国",
      en: "Country",
    },
    CountryMaster: {
      ja: "国のマスターデータベース",
      en: "Master DB for Country",
    },
    Engage: {
      ja: "ArtistとMusicとEngageHowと年と貢献度の関係(中間DB)",
      en: "Engagement between Artist, Music, EngageHow, year and degree of contribution (Intermediate DB)",
      note: "Association"
    },
    EngageHow: {
      ja: "ArtistとMusicとの関係の種類",
      en: "Type of Engagement between Artist and Music",
    },
    EventGroup: {
      ja: "シリーズもののEventの一括り。相互に排他的。つまり、一つのEventが部分的にでも複数のEventGroupにまたがることはない。複数の大型フェスは、開催年ごとに一つのEventGroupとする(例: フジロックの2022年と2023年とは別々)。大塚愛「ラブボン」のような場合は、1つのEventGroupとしてよい。",
      en: "A series (category) of multiple Events, which are mutually exclusive, namely an Event would not overlap multiple EventGroups evern partially. For annually-held big festivals, the festival each year should be registered as a single EventGroup (e.g., Fuji Rocks 2022 and 2023 are registered as separate EventGroups). Annualy-held small-scale events like Ai Otsuka's 'LOVE IS BORN' can be registered as a single EventGroup as a series.",
      note: ""
    },
    Event: {
      ja: "(音楽)イベント。大型フェスならば1日あるいは1つのステージがEventとなるだろう。ライブでお客さんを入れ替える場合は別々に分ける(例: 昼公演と夜公演は別々)。",
      en: "A (music) event. For big festivals, a single stage or single day may be an Event. Multiple concerts that accept separate sets of audience (like afternoon and evening concerts) should be registered as individual Events.",
      note: ""
    },
    EventItem: {
      ja: "一つのEventの中の何かの一括り。特に、1本の公開動画として使われるもの(もしくはその一部)を単位とする。1つのEventItemは複数の動画で使われる可能性があり(別編集など)、また1本の動画は複数のEventItemを含むかも知れない(年間ツアーのダイジェスト版など)。",
      en: "A sub-Event of an Event, meant to be a part that is used in the entire clip or clips in a single video. An EventItem may be used in multiple videos (like separate edits) and a single video may contain multiple EventItems (like a digest movie of a year-long tour).",
      note: ""
    },
    Genre: {
      ja: "音楽の種別",
      en: "Genre of Music",
    },
    Harami1129: {
      ja: "Harami動画サーバーからダウンロードした動画情報",
      en: "Information retrieved from Harami-video server",
    },
    HaramiVid: {
      ja: "ハラミちゃん動画",
      en: "Video of HARAMIchan",
    },
    Music: {
      ja: "音楽",
      en: "Music",
    },
    Place: {
      ja: "場所(一般には県よりも小さい単位)",
      en: "Place (Smaller than a Prefecture in general)",
    },
    Prefecture: {
      ja: "県または州",
      en: "Prefecture or state",
    },
    Sex: {
      ja: "性別",
      en: "Sex",
    },
    Translation: {
      ja: "翻訳(曲名、地名など)",
      en: "Translation (of Musics, Places etc)",
    },
    User: {
      ja: "登録ユーザー",
      en: "Registered User",
    },
  } 
  # Missing:
  # ModelSummary PageFormat Role RoleCategory StaticPage

  # Main routine to seed.
  def load_model_summaries
    n_changed = 0

    SEED_DATA.each_pair do |modelname, ehs|
      model = ModelSummary.find_or_initialize_by(modelname: modelname)
      is_increased = model.new_record?
      if ehs[:note].present? && model.note.blank?
        model.note = ehs[:note].strip 
        is_increased = true
      end
      if !model.save
        warn "ERROR(#{__FILE__}:#{__method__}): Fails in save ModelName=#{modelname} (ID=#{model.id.inspect})"
        next
      end
      BaseWithTranslation::AVAILABLE_LOCALES.each do |langcode|
        if ehs[langcode].present? && model.title(langcode: langcode.to_s).blank?
          is_increased = true
          model.create_translation!(langcode: langcode.to_s, title: ehs[langcode]) # not specifying is_orig
        end
      end
      n_changed += 1 if is_increased
    end
    n_changed
  end
  
end    # module SeedsModelSummaries

n_entries = SeedsModelSummaries.load_model_summaries

if n_entries > 0 || $DEBUG
  printf("  %s: %s ModelSummaries are created/updated.\n", seed_fname2print(__FILE__), n_entries)
end

