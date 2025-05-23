# coding: utf-8

include ModuleCommon  # for seed_fname2print

puts "DEBUG: start "+seed_fname2print(__FILE__) if $DEBUG
# This seed script can run in any environment or condition (see /seeds/users.rb for an environment-specific one).

require_relative "common.rb"  # defines: module Seeds

# Model: ModelSummary
#
module Seeds::ModelSummaries
  extend Seeds::Common

  # Corresponding Active Record class
  RECORD_CLASS = self.name.split("::")[-1].singularize.constantize  # ModelSummary

  # Everything is a function
  module_function

  # Data to seed
  SEED_DATA = {
    Artist: {
      ja: "アーティスト",
      en: "Artist",
    },
    Channel: {
      ja: "チャンネル",
      en: "Channel (to publish)",
    },
    ChannelOwner: {
      ja: "チャンネルのオーナー(例: Abex(企業)、Queen(=アーティスト本人))",
      en: "Channel Owner (e.g., Abex (Corporate), Queen (Artist))",
    },
    ChannelPlatform: {
      ja: "チャンネルのサイト(例: Youtube、Tiktok)",
      en: "Channel Platform (e.g., Youtube, Tiktok)",
    },
    ChannelType: {
      ja: "チャンネルの種類(例: 主チャンネル、副チャンネル、メディア)",
      en: "Channel Type (e.g., primary/secondary channels, media)",
    },
    Country: {
      ja: "国",
      en: "Country",
    },
    CountryMaster: {
      ja: "国のマスターデータベース",
      en: "Master DB for Country",
    },
    Domain: {
      ja: "ドメイン",
      en: "Domain",
    },
    DomainTitle: {
      ja: "ドメインの名前(ドメインにエイリアスがあっても名前は唯一)。「www.」有無は通常エイリアス。一方、(ja|en).wikipedia.orgは内容が異なるから、別DomainTitle。",
      en: "Title of domain (a unified name for a domain with multiple aliases). Prefixes of 'www.' or not are usually aliasses, whereas (ja|en).wikipedia.org are separate because their contents differ.",
    },
    Engage: {
      ja: "ArtistとMusicとEngageHowと年と貢献度の関係(中間DB)",
      en: "Engagement between Artist, Music, EngageHow, year and degree of contribution (Intermediate DB)",
      note: "Association"
    },
    PlayRole: {
      ja: "Engage(ArtistとMusic)とEventItemの関係の種類",
      en: "Type of engagement between Engage (Artist and Music) and EventItem",
    },
    EngageHow: {
      ja: "ArtistとMusicとの関係の種類",
      en: "Type of Engagement between Artist and Music",
    },
    Instrument: {
      ja: "Artistが演奏した楽器(主にArtistMusicPlayの副情報)",
      en: "Instrument an Artist plays (mainly sub-information of ArtistMusicPlay)",
    },
    EventGroup: {
      ja: "シリーズもののEventの一括り。相互に排他的。つまり、一つのEventが部分的にでも複数のEventGroupにまたがることはない。大塚愛「ラブボン」のような場合、1つのEventGroupとしてよい。",
      en: "A series (category) of multiple Events, which are mutually exclusive, namely an Event would not overlap multiple EventGroups evern partially. Annualy-held events like Ai Otsuka's 'LOVE IS BORN' can be registered as a single EventGroup as a series.",
      note: ""
    },
    Event: {
      ja: "(音楽)イベント。ライブでお客さんを入れ替える場合は原則として別々に分ける(例: 昼公演と夜公演は別々)。",
      en: "A (music) event. Multiple concerts that accept separate sets of audience (like afternoon and evening concerts) should be registered as individual Events.",
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
    Harami1129Review: {
      ja: "元々のHarami1129からArtist/Music名が変化したもの",
      en: "Updated Artist or Music from original Harami1129",
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
    SiteCategory: {
      ja: "ウェブサイト種別",
      en: "Website category",
    },
    Sex: {
      ja: "性別",
      en: "Sex",
    },
    Translation: {
      ja: "翻訳(曲名、地名など)",
      en: "Translation (of Musics, Places etc)",
    },
    Url: {
      ja: "URL (HaramiVidのURLを除く)",
      en: "URL (except for those for HaramiVids)",
    },
    User: {
      ja: "登録ユーザー",
      en: "Registered User",
    },
  }.with_indifferent_access  # SEED_DATA
  SEED_DATA.each_pair do |ek, ev|
    ev[:modelname] = ek  # unique key
  end
  SEED_DATA.each_value{|eh| eh.with_indifferent_access}

  # this is properly set by load_seeds (the contents may be existing ones or new ones)
  MODELS = SEED_DATA.keys.map{|i| [i, nil]}.to_h

  # Missing:
  # ModelSummary PageFormat Role RoleCategory StaticPage

  # Main routine to seed.
  #
  # Constant Hash MODELS is set so that the seeded models are accessible.
  #
  # @return [Integer] Number of created/updated entries
  def load_seeds
    _load_seeds_core(%i(modelname note), find_by: :modelname)  # defined in seeds_common.rb, using Instrument (==RECORD_CLASS)
  end  # def load_seeds

end    # module Seeds::ModelSummaries

