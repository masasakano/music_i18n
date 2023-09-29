# coding: utf-8

#include ModuleCommon  # for split_hash_with_keys

puts "DEBUG: start /seeds/model_summaries.rb" if $DEBUG
return if !Rails.env.development?

# Models: User and UserRoleAssoc
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

  # Main routine to seed.
  def model_summaries_main
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

n_entries = SeedsModelSummaries.model_summaries_main

if n_entries > 0 || $DEBUG
  printf("/seeds/#{File.basename __FILE__}: %s ModelSummaries are created/updated.\n", n_entries)
end

