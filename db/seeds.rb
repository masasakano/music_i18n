# coding: utf-8
# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

## NOTE:
# This script is run as the main script with
#   * "./db/seeds.rb" (*if* the executable permission was ever given) or
#   * "ruby db/seeds.rb" or
#   * "bin/rails db:seed(:replant)" etc with the environmental variable DO_TEST_SEEDS unset or of 0.
#
# The test script /test/seeds/seeds_test.rb require this file ONLY IF the environmental variable DO_TEST_SEEDS is set positive.
#
# NOTE: Once the superuser has been created (the first registered user is automatically promoted
#  to the superuser!), run the following to prevent them from being overwritten [THIS NEEDS CHECKING!]:
#
#     Translation.update_all(create_user_id: myself.id, update_user_id: myself.id)

class Object
  # To mark this process is running seeding
  FLAG_SEEDING = true
end

include ModuleCommon  # for split_hash_with_keys, seed_fname2print
include ApplicationHelper  # for is_env_set_positive?

def implant_seeds

################################
# Load Model: Sex

nrec = 0  # Number of updated records.
ret = false
sexes = [0, 1, 2, 9].map{ |cid|
  prev = Sex.find_by(id: cid)
  if prev
    prev
  else
    nrec += 1
    ret ||= true
    Sex.new do |p| 
      p.id      = cid
      p.iso5218 = cid
      p.save!
    end
  end
}
# [0] # id=0, name: '不明',
# [1] # id=1, name: '男',
# [2] # id=2, name: '女',
# [3] # id=9, name: '適用不能',

### Model: Sex - Translation ###

# refja = 'ja.wikipedia.org/wiki/ISO_5218'
# refen = 'en.wikipedia.org/wiki/ISO/IEC_5218'

def rescue_rnu
  begin
    yield
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    false
  end
end

hstmpl = {weight: 0, langcode: 'en'}
ret = (rescue_rnu{ sexes[0].with_orig_translation(**hstmpl.merge({title: 'not known',      alt_title: 'Unknown', langcode: 'en'}))} || ret)
ret = (rescue_rnu{ sexes[1].with_orig_translation(**hstmpl.merge({title: 'male',           alt_title: 'M',       langcode: 'en'}))} || ret)
ret = (rescue_rnu{ sexes[2].with_orig_translation(**hstmpl.merge({title: 'female',         alt_title: 'F',       langcode: 'en'}))} || ret)
ret = (rescue_rnu{ sexes[3].with_orig_translation(**hstmpl.merge({title: 'not applicable', alt_title: 'N/A',     langcode: 'en'}))} || ret)

hstmpl[:langcode] = 'ja'
hstmpl[:is_orig]  = false
ret = (rescue_rnu{ sexes[0].create_translation!(**hstmpl.merge({title: '不明',     ruby: 'フメイ',         romaji: 'fumei'}))} || ret)
ret = (rescue_rnu{ sexes[1].create_translation!(**hstmpl.merge({title: '男',       ruby: 'オトコ',         romaji: 'otoko'}))} || ret)
ret = (rescue_rnu{ sexes[2].create_translation!(**hstmpl.merge({title: '女',       ruby: 'オンナ',         romaji: 'onna'}))} || ret)
ret = (rescue_rnu{ sexes[3].create_translation!(**hstmpl.merge({title: '適用不能', ruby: 'テキヨウフノウ', romaji: 'tekiyoufunou'}))} || ret)

# Creates a new one or update the existing one if exists, else return false
def rescue_cre(obj, **kwd)
  record = obj.create(**kwd)
  if record.valid?
    ret = rescue_rnu{ record.save! }
    return ret if ret  # Successfully created a new record.
  else
    # maybe a conflicting record already exists.
  end

  rela = obj.where(**kwd)
  return false if ! rela.empty?  # The identical one exists.

  # The existing one will be updated.
  # Gets the condition to get the existing one and the parameters to update.
  arkey = kwd.keys
  raise "Strange size=#{arkey.size}, kwd=#{kwd.inspect}" if arkey.size - 1 < 1
  (1..(arkey.size-1)).reverse_each do |i|
    arkey.combination(i).each do |ea_ar|
      hs2try = kwd.select{|k, v| ea_ar.include? k}
      rela2 = obj.where(**hs2try)
      next if rela2.size != 1
      return rela2.first.update!(**kwd)  # Never mind some duplicated updates.
    end
  end

  raise "ERROR: Strange. Unique error but cannot find the right one. kwd=#{kwd.inspect}"
end

################################
# Load Model: RoleCategory

# To set a series of objects (if not set) and returns them as an Array
#
# @param model [ActiveRecord] Model class
# @param indices [Array, Boolean] Array of primary-ID. If Boolean and TRUE, taken from contents,
#    starting from 1 like [1,2,3,4]. If FALSE, indices are not explicitly specified.
# @param update [Boolean] if true, and if the record exists, update it.
# @param **contents [Hash<Array>] Label1 => ([content1, ...] for indices)
# @return [Array<Integer, Hash>] A pair. Number of updated/created records
#    if at least one of them is newly set (or updated), else 0.
#    For the Hash part (2nd element) Key is an Integer taken from indices.
#    Say, if indices are [1, 2, 5], ret = { 1 => ret1, 2 => ret2, 5 => ret3 }
def get_set_arobj(model, indices=false, update=true, **contents)
  nrec = 0
  specify_index = indices
  indices = ((1..contents.first[1].size).to_a rescue []) if !indices || (indices == true)
  hsret = indices.map.each_with_index{ |cid, ii| 
    prev = model.find_by(id: cid)
    if prev && !update
      [cid, prev]
    else
      if prev
        ep = prev
      else
        ep = model.new
      end

      ep.id = cid if specify_index
      contents.each_pair do |k, v|
        ep.send(k.to_s+'=', v[ii])
      end
      begin
        if ep.changed?
          ep.save!
          nrec += 1
        end
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => er
        s = contents.map{|k, v| k.to_s+": "+v[ii].inspect}.join ", "
        warn "ERROR: "+er.message
        warn "ERROR: Invalid record (UniqueViolation etc) for #{ii+1}-th one <#{model.name}: id: #{ep.id}, #{s}> in #{__method__}()."
        warn "ERROR: p all="+Role.all.inspect
        raise
      end
      [cid, ep.reload]
    end
  }.to_h
  [nrec, hsret]
end  # def get_set_arobj

if Object.const_defined? :RoleCategory
  mnames = %i(MNAME_ROOT MNAME_HARAMI MNAME_TRANSLATION MNAME_GENERAL_JA).map{|i| RoleCategory.const_get i}
  nrectmp, hsrc = get_set_arobj(RoleCategory, (1..mnames.size).to_a, mname: mnames, superior_id: [nil]+[1]*(mnames.size-1)) # superior_id: [nil, 1, 1, 1]
  nrec += nrectmp
  # hsrc[1] => RoleCategory('ROOT')
  # hsrc[2] => RoleCategory('harami')
  # hsrc[3] => RoleCategory('translation')
  # hsrc[4] => RoleCategory('general_ja')
end

################################
# Load Model: Role
#
# NOTE: No user is created in this seed. First-created user is automatically a sysadmin.

if hsrc && (Object.const_defined? :Role)  # hsrc: HaSh-RoleCategory
  names =  [Role::RNAME_SYSADMIN]+[Role::RNAME_MODERATOR, Role::RNAME_EDITOR, Role::RNAME_HELPER]*3  # 3 as in the number of RoleCategory-s except ROOT (== [RoleCategory::MNAME_HARAMI, MNAME_TRANSLATION, MNAME_GENERAL_JA])
  unames = [Role::UNAME_SYSADMIN]+names[1..-1].map.with_index{|na, i| hsrc[i.div(3)+2].mname+'_'+na} # 3 as in the number of Roles in each RoleCategory (== [Role::RNAME_MODERATOR, RNAME_EDITOR, RNAME_HELPER])
  unames[5] = Role::UNAME_TRANSLATOR  # uname='translation_editor' changed into 'translator'
  hs2pass = {
    name:  names,
    uname: unames,
    role_category: [hsrc[1]]+(2..4).map{|j| [j]*3}.flatten.map{|i| hsrc[i]},
    weight: [Role::DEF_WEIGHT[Role::RNAME_SYSADMIN]] +
            [Role::DEF_WEIGHT[Role::RNAME_MODERATOR], Role::DEF_WEIGHT[Role::RNAME_EDITOR], Role::DEF_WEIGHT[Role::RNAME_HELPER]]*3,
    #weight: [0]+ [100, 1000, 100000]*3,  # values used to be
  }
end

nrectmp, _ = get_set_arobj(Role, (1..names.size).to_a, **hs2pass) 
nrec += nrectmp


################################
# Load the countries (CountryMaster and Country)

ini_prefs = Prefecture.count
ini_placs = Place.count

# Create Country['World'] (id=0)
flag_world = false
if Country.find_by(iso3166_n3_code: 0)  # Skip if already exists.
  # pass
elsif Country['世界', 'ja'] || Country['World', 'en']
  warn "WARNING: Country['世界', 'ja'] or Country['World', 'en'] exists whereas Country.find_by(iso3166_n3_code: 0) is nil. It should not be."
else
  flag_world = true
  if Country.find_by(id: 0)
    warn "WARNING: id=0 for Country is already taken but it is not 'World'."
    world = Country.create!(iso3166_n3_code: 0)
  else
    world = Country.create!(iso3166_n3_code: 0, id: 0)
  end
  hsworld = {
    ja: {title: '世界',  ruby: 'セカイ', romaji: 'sekai', weight: 0},
    en: {title: 'World', is_orig: true, weight: 0},
    fr: {title: 'Monde', weight: 0},
  }
  world.reload.with_translations(**hsworld)
  nrec += 12  # Country, Unknown-Prefecture/Place + 3 languages
end

### Loading ISO-3166 country names

require Rails.root.to_s+'/lib/tasks/lib/read_country_list.rb'

valids = nil
if ENV['LOAD_COUNTRIES'].blank?
  printf("NOTE: All countries in CountryMaster are imported to Country (unless specifying LOAD_COUNTRIES='JP,KR,GB'] etc).\n")
else
  valids = ENV['LOAD_COUNTRIES'].strip.split(/\s*,\s*/).map{|i| i.blank? ? nil : i}.compact
  printf("NOTE: LOAD_COUNTRIES=%s\n", ENV['LOAD_COUNTRIES'].inspect)
end

n_cnts = 0
allcnts = read_country_list  # defined in /lib/tasks/lib/read_country_list.rb
allcnts.each do |ea_cnt|
  trans = ea_cnt.select{ |k, _| /^lang:/ =~ k }.values.reduce({}, :merge)
  ## An example:
  # {:ja=>{title: 英領インド洋地域, alt_title: nil, is_orig: false, weight: 0},
  #  :en=>{title: nil, alt_title: British Indian Ocean Territory (the)", is_orig: true, weight: 0},
  #  :fr=>{title: "Indien (le Territoire britannique de l'océan)", is_orig: false, weight: 0}}

  if ea_cnt[:iso3166_a2_code] == 'MW' && trans[:fr][:title] == 'び'  # An error in the original JSON
    trans[:fr][:title] = 'Malawi (le)'
  end

  hstmp = ea_cnt.select{ |k, _| /^lang:/ !~ k }

  _, hstmp_ms = split_hash_with_keys(hstmp, %i(iso3166_remark territory))
  %i(ja en fr).each do |lc_sym|
    hstmp_ms.merge!({'name_'+lc_sym.to_s+'_full'  => trans[lc_sym][:title]})
    hstmp_ms.merge!({'name_'+lc_sym.to_s+'_short' => trans[lc_sym][:alt_title]}) if lc_sym != :fr
  end
  cm = CountryMaster.find_or_initialize_by(hstmp_ms)  # to create!, JSON columns are tricky and may(?) raise ActiveRecord::StatementInvalid when non-nil.

  if cm.new_record?
    %i(iso3166_remark territory).each do |ek|
      cm.send(ek.to_s+'=', JSON.parse(hstmp[ek].as_json)) if hstmp[ek] # read_country_list.rb treated it as a String.
    end
    cm.save!
    n_cnts += 1
  end
  # TEST: all four must be significant:
  #   CountryMaster.find_by(iso3166_a3_code: 'ASM').slice(:name_ja_full, :name_en_short, :name_fr_full, :territory, :iso3166_remark)

  sym = :iso3166_a2_code  # a2 is used b/c neither iso3166_n3_code nor iso3166_a3_code is defined for "the Republic of Kosovo".
  if valids  # i.e., !ENV['LOAD_COUNTRIES'].blank?
    # Limit the countries to load
    next if !valids.include? hstmp[sym].to_s
  end

  next if Country.find_by(sym => hstmp[sym])  # Already defined.

  Country.load_one_from_master(country_master: cm, hs_main: hstmp, hs_trans: trans, check_clobber: false)
  # This would raise an error (b/c check_clobber=false) if the Country already existed, which should never happen because the condition is checked above.

  n_cnts += 1  # Number of new Countries.
end


if n_cnts > 0
  now_prefs = Prefecture.count
  now_placs = Place.count
  printf("NOTE: (%d%s, %d, %d) entries are inserted in Tables (countries, prefectures, places).\n",
         n_cnts,
         (flag_world ? '(+1, "World")' : ' (without "World")'),
         now_prefs - ini_prefs,
         now_placs - ini_placs
        )
  ini_prefs = now_prefs
  ini_placs = now_placs
  nrec += n_cnts*3*3  # Country, Unknown-Prefecture/Place + 2 languages
end

################################
# Load the prefectures
# Loading ISO-3166-2:JP prefecture names

require Rails.root.to_s+'/lib/tasks/lib/read_prefecture_list.rb'

japan = Country['JPN']  # or Country['France', 'en', true] or Country['日本国']

n_prefs = 0
allprefs = read_prefecture_list
allprefs.each do |ea_cnt|
  trans = ea_cnt.select{ |k, _| /^lang:/ =~ k }.values.reduce({}, :merge)
  ## An example (allprefs[9]):  # => after seed-plant, it is Prefecture.all[260]
  # {:ja=>{:title=>"群馬県", :is_orig=>true, :weight=>0, :ruby=>"グンマケン"},
  #  :en=>{:title=>nil, :alt_title=>"Gunma", :is_orig=>false, :weight=>0}},
  if trans[:en] && trans[:en][:alt_title] && trans[:ja] && !trans[:ja][:romaji]
    trans[:ja][:romaji] = trans[:en][:alt_title]
  end

  hstmp = ea_cnt.select{ |k, _| /^lang:/ !~ k }
  hstmp[:country] = japan
  # hstmp == {:iso3166_loc_code=>10,
  #           :start_date=>"1947-05-03",
  #           :end_date=>nil,
  #           :orig_note=>"英字表記について、外務省によるパスポートの英字表記はGummaであるが、ISO 3166-2には記載がない。https://www.pref.gunma.jp/04/c3610022.html"}

  sym = :iso3166_loc_code
  if !Prefecture.find_by(sym => hstmp[sym])
    #Prefecture.create_with_translations!(**(hstmp.merge({translations: trans})))  # Ruby 2.7 (shouldn't have worked)
    Prefecture.create_with_translations!(hstmp, translations: trans)
    n_prefs += 1
  end
end

# Create a Prefecture and its 2 or 3 Translation-s if not present.
#
# Bug: If the Prefecture does not exist in the specified Country but does
#  in another Country, this does not work correctly.
#
# @param country [Country]
# @param trans [Hash] e.g. {'ja' => {title: '東', ruby: 'アズマ', is_orig: true, weight: 10}, 'en' =>{...}}
# @return [Integer] Created number of objects
def seed_create_prefecture(cntry, trans, iso3166_loc_code: nil, note: nil)
  if !cntry
    warn "WARNING: country for Prefecture (#{trans['ja'][:title]}) does not exist; hence the Prefecture is not seeded. Strange."
    return 0
  end

  prefectures = %w(ja en fr).map{|i| Prefecture[trans[i][:title], i, true]}
  return 0 if prefectures.all?{|i| i}

  if prefectures.all?{|i| !i}
    Prefecture.update_or_create_with_translations!({country: cntry, iso3166_loc_code: iso3166_loc_code}, note: note, translations: trans)
    return 3
  end

  if prefectures[0]  # Japanese Translation exists
    return 0 if prefectures[0].title(  langcode: "en")  # Skip b/c an English translation exists.
    prefectures[0].create_translation!(langcode: "en", **(trans["en"]))
    return 1
  else  # prefectures[1] (derived from the given English Translation) should be Prefecture
    return 0 if prefectures[1].title(  langcode: "ja")  # Skip b/c a Japanese translation exists.
    prefectures[1].create_translation!(langcode: "ja", **(trans["ja"]))
    return 1
  end
end

cntry = Country['FRA']
trans = {'ja' => {title: 'パリ(県)', ruby: 'パリ(ケン)', romaji: 'Pari (ken)', alt_title: 'パリ', alt_ruby: 'パリ', alt_romaji: 'Pari', is_orig: false, weight: 10},
         'en' => {title: 'Paris', weight: 10, is_orig: false},
         'fr' => {title: 'Paris', weight: 0,  is_orig: true},}
n_prefs += seed_create_prefecture(cntry, trans, iso3166_loc_code: 75, note: "iso3166_loc_code is the INSEE code")

cntry = Country['GBR']

trans = {'ja' => {title: 'グレーター・ロンドン', ruby: 'グレーター・ロンドン', romaji: 'greetaa rondon', is_orig: false, weight: 10},
         'en' => {title: 'Greater London', weight: 0, is_orig: true},
         'fr' => {title: 'Grand Londres, Le', weight: 10, is_orig: false},}
n_prefs += seed_create_prefecture(cntry, trans, iso3166_loc_code: 12000007, note: "iso3166_loc_code is the GSS code without the prefix E(ngland)")

if n_prefs > 0
  #now_prefs = Prefecture.count
  now_placs = Place.count
  printf("NOTE: (%d, %d) entries are further inserted in Tables (prefectures, places).\n", n_prefs, now_placs - ini_placs)
  nrec += n_prefs*2*3  # UnknownPlace + 2 languages
end

################################
# Load some places

# Create a Place and its 2 Translation-s if not present.
#
# Bug: If the Place does not exist in the specified Prefecture but does
#  in another Prefecture, this does not work correctly.
#
# @param pref [Prefecture]
# @param trans [Hash] e.g. {'ja' => {title: '東', ruby: 'アズマ', is_orig: true, weight: 10}, 'en' =>{...}}
# @return [Integer] Created number of objects
def seed_create_place(pref, trans)
  if !pref
    warn "WARNING: prefecture for Place (#{trans['ja'][:title]}) does not exist; hence the Place is not seeded. Strange."
    return 0
  end

  places = %w(ja en).map{|i| Place[trans[i][:title], i, true]}
  return 0 if places.all?{|i| i}

  if places.all?{|i| !i}
    Place.update_or_create_with_translations!({prefecture: pref}, translations: trans)
    return 3
  end

  if places[0]  # Japanese Translation exists
    return 0 if places[0].title(  langcode: "en")  # Skip b/c an English translation exists.
    places[0].create_translation!(langcode: "en", **(trans["en"]))
    return 1
  else  # places[1] (derived from the given English Translation) should be Place
    return 0 if places[1].title(  langcode: "ja")  # Skip b/c a Japanese translation exists.
    places[1].create_translation!(langcode: "ja", **(trans["ja"]))
    return 1
  end
end

n_placs = 0

pref = Prefecture['東京都']
trans = {'ja' => {title: '東京都本庁舎', alt_title: '都庁', alt_ruby: 'トチョウ', alt_romaji: 'Tocho', is_orig: true, weight: 10},
         'en' => {title: 'Tokyo Metropolitan Government Building', alt_title: 'Tokyo Met. Gov. Build.', weight: 10}}
n_placs += seed_create_place(pref, trans)

pref = Prefecture['香川県']
trans = {'ja' => {title: '高松駅', ruby: 'タカマツエキ', romaji: 'Takamatsu Eki', is_orig: true, weight: 10},
         'en' => {title: 'Takamatsu Station'}}
n_placs += seed_create_place(pref, trans)

pref = Prefecture['神奈川県']
trans = {'ja' => {title: '横浜BMIストリートピアノ(関内マリナード広場)', ruby: 'ヨコハマビーエムアイストリートピアノ(カンナイマリナードヒロバ)', romaji: "Yokohama BMI sutoriitopiano (Kan'nai Marinaado Hiroba)", is_orig: true, weight: 10},
         'en' => {title: "Yokohama BMI Streetpiano (Kan'nai Marinard Square)", note: '@YokohamaStPiano English name reference: https://hamarepo.com/story.php?story_id=1777', weight: 10}}
n_placs += seed_create_place(pref, trans)

trans = {'ja' => {title: '横浜BMIストリートピアノ(馬車道駅)', ruby: 'ヨコハマビーエムアイストリートピアノ(バシャミチエキ)', romaji: "Yokohama BMI sutoriitopiano (Bashamichi Eki)", is_orig: true, weight: 10},
         'en' => {title: "Yokohama BMI Streetpiano (Bashamichi Station)", note: "Installed months after Kan'nai's sister streetpiano. @YokohamaStPiano", weight: 10}}
n_placs += seed_create_place(pref, trans)

pref = Prefecture['どこかの都道府県','ja',false,Country['Japan','en',true]] # equivalent to Prefecture['どこかの都道府県','ja',Country['日本国']] # or Country[/^日本/]
trans = {'ja' => {title: 'ハラミ自宅', ruby: 'ハラミジタク', romaji: "Harami jitaku", is_orig: true, weight: 10},
         'en' => {title: "HARAMIchan's home", weight: 10, }}
n_placs += seed_create_place(pref, trans)

trans = {'ja' => {title: 'どこかのスタジオ', ruby: 'ドコカノスタジオ', romaji: "Dokokano sutazio", weight: 10},
         'en' => {title: "random music studio", weight: 10, }}
n_placs += seed_create_place(pref, trans)

nrec += n_placs

################################
# Load some genres

artrans = [
  { weight: 99999, :note => nil, translations:
   {'ja' => {title: Genre::UnknownGenre['ja'], ruby: 'ジャンルフメイ', romaji: 'janrufumei', weight: 0},
    'en' => {title: Genre::UnknownGenre['en'], weight: 0, }}},
  { weight: 10, :note => '例: 広瀬香美『ロマンスの神様』, Queen『Bohemian Rhapsody』', translations:
   {'ja' => {title: 'ポップス', ruby: 'ポップス', romaji: 'poppusu', weight: 10},
    'en' => {title: 'Pop', weight: 10,}}},
  { weight: 20, :note => '例: 『彼こそが海賊』(Pirates of the Caribbean), 『ビッグブリッヂの死闘』(Final Fantasy)', translations:
   {'ja' => {title: '劇場・映画・アニメ・ゲーム曲', ruby: 'ゲキジョウ・エイガ・アニメ・ゲームキョク', romaji: 'gekijou/eiga/animekyoku', weight: 10},
    'en' => {title: 'Theatrical/Movie/Game', weight: 10,}}},
  { weight: 30, :note => '例: 滝廉太郎『荒城の月』, 『北風小僧の寒太郎』(みんなのうた)', translations:
   {'ja' => {title: '近世歌謡曲・唱歌・童謡', ruby: 'キンセイカヨウキョク・ショウカ・ドウヨウ', romaji: 'kinseikayoukyoku/shouka/douyou', weight: 10},
    'en' => {title: 'Modern classic/kids', weight: 10,}}},
  { weight: 40, :note => '例: 『Amazing Grace』『蛍の光』『よさこい節』', translations:
   {'ja' => {title: '伝統・民謡・賛美歌', ruby: 'デントウ・ミンヨウ・サンビカ', romaji: 'dentou/minyou/sanbika', weight: 10},
    'en' => {title: 'Traditional/Folk/Hymn', weight: 10,}}},
  { weight: 50, :note => '例: Louis Armstrong『What A Wonderful World』, 上原ひろみ『Somewhere』', translations:
   {'ja' => {title: 'ジャズ', ruby: 'ジャズ', romaji: 'jazu', weight: 10},
    'en' => {title: 'Jazz', weight: 10,}}},
  { weight: 100, :note => '例: Mozart『トルコ行進曲』, Beethoven『交響曲第九(歓喜の歌)』', translations:
   {'ja' => {title: 'クラシック', ruby: 'クラシック', romaji: 'kurasikku', weight: 10},
    'en' => {title: 'Classic', weight: 10,}}},
  { weight: 200, :note => '例: ツトム・ヤマシタ『太陽の儀礼』', translations:
   {'ja' => {title: '現代器楽曲', ruby: 'ゲンダイキガクキョク', romaji: 'gendaikigakukyoku', weight: 10},
    'en' => {title: 'Modern instrumental', weight: 10,}}},
  { weight: 500, :note => '例: ラジオ体操', translations:
   {'ja' => {title: 'その他', ruby: 'ソノタ', weight: 10},
    'en' => {title: 'Other', weight: 10, }}},
]

n_genres = 0
artrans.each do |ea_hs|
  hs_note, hs_trans = split_hash_with_keys(ea_hs, [:note, :weight])
  begin
    record = Genre.update_or_create_with_translations!(hs_note, **hs_trans)
  rescue RuntimeError #=> er
    print "ERROR in seeds in creating Genre. Contact the code developer: [ea_hs, note, hs_trans]=";p [ea_hs, hs_note, hs_trans]
    raise
  end
  n_genres += 1 if record.saved_changes?
end
nrec += n_genres*3  # Genre + 2 languages (In fact, this is not accurate... no changes in Translation are not considered.)

################################
# Load some engage_hows

artrans = [
  { weight: 99999, note: nil, translations:
   {'ja' => {title: EngageHow::UnknownEngageHow['ja'], ruby: 'カンヨケイタイフメイ', weight: 0},
    'en' => {title: EngageHow::UnknownEngageHow['en'], weight: 0, }}},
  { weight: 10, note: nil, translations:
   {'ja' => {title: '歌手(オリジナル)', ruby: 'カシュ(オリジナル)', weight: 10},
    'en' => {title: 'Singer (Original)', weight: 10, }}},
  { weight: 20, note: nil, translations:
   {'ja' => {title: '歌手(カバー)', ruby: 'カシュ(カバー)', weight: 10},
    'en' => {title: 'Singer (Cover)', weight: 10, }}},
  { weight: 30, note: nil, translations:
   {'ja' => {title: '作詞', ruby: 'サクシ', weight: 10},
    'en' => {title: 'Lyricist', weight: 10, }}},
  { weight: 40, note: nil, translations:
   {'ja' => {title: '訳詞', ruby: 'ヤクシ', weight: 10},
    'en' => {title: 'Translator', weight: 10, }}},
  { weight: 50, note: nil, translations:
   {'ja' => {title: '作曲', ruby: 'サッキョク', weight: 10},
    'en' => {title: 'Composer', weight: 10, }}},
  { weight: 60, note: nil, translations:
   {'ja' => {title: '編曲', ruby: 'ヘンキョク', weight: 10},
    'en' => {title: 'Arranger', weight: 10, }}},
  { weight: 70, note: nil, translations:
   {'ja' => {title: '指揮', ruby: 'シキ', weight: 10},
    'en' => {title: 'Conductor', weight: 10, }}},
  { weight: 80, note: nil, translations:
   {'ja' => {title: '演奏', ruby: 'エンソウ', weight: 10},
    'en' => {title: 'Player', weight: 10, }}},
  { weight: 90, note: nil, translations:
   {'ja' => {title: '伴奏', ruby: 'バンソウ', weight: 10},
    'en' => {title: 'Accompanist', weight: 10, }}},
  { weight: 100, note: nil, translations:
   {'ja' => {title: 'プロデュース', ruby: 'プロデュース', weight: 10},
    'en' => {title: 'Producer', weight: 10, }}},
  { weight: 110, note: nil, translations:
   {'ja' => {title: 'アシスタント', ruby: 'アシスタント', weight: 10},
    'en' => {title: 'Assistant', weight: 10, }}},
  { weight: 500, note: nil, translations:
   {'ja' => {title: 'その他', ruby: 'ソノタ', weight: 10},
    'en' => {title: 'Other', weight: 10, }}},
]

n_engage_hows = 0
artrans.each do |ea_hs|
  hs_note, hs_trans = split_hash_with_keys(ea_hs, [:note, :weight])
  record = EngageHow.update_or_create_with_translations!(hs_note, **hs_trans)
  n_engage_hows += 1 if record.saved_changes?
end
nrec += n_engage_hows*3  # EngageHow + 2 languages (In fact, this is not accurate... no changes in Translation are not considered.)

################################
# Load some artists

female = Sex['female']
japan = Country['JPN']
artrans = [
  { note: nil,
    sex: Sex.unknown, place: Place.unknown, translations:
   {'ja' => {title: Artist::UnknownArtist['ja'], ruby: 'フメイノオンガクカ', romaji: 'fumei no ongakuka', weight: 0},
    'en' => {title: Artist::UnknownArtist['en'], weight: 0, },
    'fr' => {title: Artist::UnknownArtist['fr'], weight: 0, }}},
  { note: nil, birth_day: 21, birth_month: 1,
    wiki_ja: 'w.wiki/3JVi', sex: female, place: Place.unknown(country: japan), translations:
   {'ja' => {title: 'ハラミちゃん', ruby: 'ハラミチャン', romaji: 'Haramichan', alt_title: 'ハラミ', alt_ruby: 'ハラミ', alt_romaji: 'Harami', weight: 0, is_orig: true},
    'en' => {title: 'HARAMIchan', alt_title: 'Harami-chan', weight: 10, is_orig: false, }}},
  { note: nil, birth_day: 12, birth_month: 4, birth_year: 1966,
    wiki_ja: 'w.wiki/3cyo', wiki_en: 'Kohmi_Hirose', sex: female, place: Place.unknown(country: japan), translations:
   {'ja' => {title: '広瀬香美', ruby: 'ヒロセコウミ', romaji: 'HIROSE Kohmi', weight: 0, is_orig: true},
    'en' => {title: 'Kohmi Hirose', weight: 0, is_orig: false, }}},
  { note: nil, birth_day: 6, birth_month: 3, birth_year: 1995,
    wiki_ja: 'w.wiki/3Jvj', wiki_en: 'Aimyon', sex: female, place: Place.unknown(prefecture: Prefecture[/兵庫県/, japan]), translations:
   {'ja' => {title: 'あいみょん', ruby: 'アイミョン', romaji: 'Aimyon', weight: 0, is_orig: true},
    'en' => {title: 'Aimyon', weight: 0, is_orig: false, }}},
  { note: nil, birth_day: 19, birth_month: 1, birth_year: 1954,
    wiki_ja: '%E6%9D%BE%E4%BB%BB%E8%B0%B7%E7%94%B1%E5%AE%9F', wiki_en: 'Yumi_Matsutoya', sex: female, place: Place.unknown(prefecture: Prefecture[/東京都/, japan]), translations:
   {'ja' => {title: '荒井由実', ruby: 'アライユミ', romaji: 'ARAI Yumi', alt_title: 'ユーミン', alt_ruby: 'ユーミン', alt_romaji: 'Yuumin', weight: 0, is_orig: true},
    'en' => {title: 'Yumi Arai', weight: 0, is_orig: false, }}},
  { note: nil, birth_day: 29, birth_month: 11, birth_year: 1976,
    wiki_ja: '%E6%9D%BE%E4%BB%BB%E8%B0%B7%E7%94%B1%E5%AE%9F', wiki_en: 'Yumi_Matsutoya', sex: female, place: Place.unknown(prefecture: Prefecture[/東京都/, japan]), translations:
   {'ja' => {title: '松任谷由実', ruby: 'マツトウヤユミ', romaji: 'MATSUTOUYA Yumi', alt_title: 'ユーミン', alt_ruby: 'ユーミン', alt_romaji: 'Yuumin', weight: 0, is_orig: true},
    'en' => {title: 'Yumi Matsutoya', alt_title: 'Yuming', weight: 0, is_orig: false, }}},
]

n_artists = 0
artrans.each do |ea_hs|
  hs_main, hs_trans = split_hash_with_keys(ea_hs, %i(note birth_day birth_month birth_year wiki_ja wiki_en sex place))
  begin
    record = Artist.update_or_create_with_translations!(hs_main, nil, mainkeys=%i(birth_day birth_month birth_year), **hs_trans)
  rescue MultiTranslationError::AmbiguousError => er
    # Skip, because at least one entry already exists.
    warn "WARNING: Multiple entries for a seeded Artist are found. Your existing record may have duplications: "+er.message
    next
  rescue ActiveRecord::RecordInvalid => er
    if er.message.include? 'not unique in the combination'
      warn "WARNING: The following is not processed as an error is raised (which should not happen!), for Hash=#{ea_hs.inspect}: "+er.message
      next
    end
  end

  if !record
    # maybe if a seeded-record has changed since?
    warn "WARNING(#{File.basename __FILE__}): seeding an Artist failed: Parameters=#{hs_main.inspect}, Translations=#{hs_trans}"
    next
  end
  n_artists += 1 if record.saved_changes?
end
nrec += n_artists*2  # Artist + 2 languages (In fact, this is not accurate... no changes in Translation are not considered.)


################################
# Load some musics

gen_inst = Genre[/instrumental/i, 'en']
gen_pop = Genre[/ポップス/, 'ja']
gen_other = Genre[/^other/i, 'en']
artrans = [
  { note: nil, genre: Genre.unknown,
    place: Place.unknown, translations:
   {'ja' => {title: Music::UnknownMusic['ja'], ruby: 'ナニカノキョク', romaji: 'nanika no kyoku', weight: 0},
    'en' => {title: Music::UnknownMusic['en'], weight: 0, },
    'fr' => {title: Music::UnknownMusic['fr'], weight: 0, }}},
  { note: nil, year: 2019, genre: gen_other,
    place: Place.unknown(country: japan), translations:
   {'ja' => {title: 'ハラミ体操', ruby: 'ハラミタイソウ', romaji: 'Harami taiso', weight: 0, is_orig: true},
    'en' => {title: 'Harami Exercise Theme Music', weight: 1000, }}},
  { note: nil, year: 2020, genre: gen_inst,
    place: Place.unknown(country: japan), translations:
   {'ja' => {title: 'ファンファーレ', ruby: 'ファンファーレ', romaji: 'Fanfaare', weight: 0, is_orig: true},
    'en' => {title: 'Fanfare', weight: 100, }}},
  { note: nil, year: 2021, genre: gen_inst,
    place: Place.unknown(country: japan), translations:
   {'ja' => {title: '雨', ruby: 'アメ', romaji: 'Ame', weight: 0, is_orig: true},
    'en' => {title: 'Rain', weight: 100, }}},
  { note: nil, year: 2021, genre: gen_inst,
    place: Place.unknown(country: japan), translations:
   {'ja' => {title: '947', ruby: '947', romaji: '947', weight: 0, is_orig: true},
    'en' => {title: '947', weight: 100, }}},
  { note: nil, year: 2022, genre: gen_inst,
    place: Place.unknown(country: japan), translations:
   {'ja' => {title: 'ひとり', ruby: 'ヒトリ', romaji: 'Hitori', weight: 0, is_orig: true},
    'en' => {title: 'Alone', weight: 100, }}},
  { note: nil, year: 2023, genre: gen_inst,
    place: Place.unknown(country: japan), translations:
   {'ja' => {title: '祈りのワルツ', ruby: 'イノリノワルツ', romaji: 'Inori no warutsutori', weight: 0, is_orig: true},
    'en' => {title: 'Waltz of a prayer', weight: 100, }}},
  { note: nil, year: 1993, genre: gen_pop,
    place: Place.unknown(country: japan), translations:
   {'ja' => {title: 'ロマンスの神様', ruby: 'ロマンスノカミサマ', romaji: 'Romansu no kamisama', weight: 0, is_orig: true},
    'en' => {title: 'God of Romance', weight: 100, }}},
  { note: nil, year: 2020, genre: gen_pop,
    place: Place.unknown(country: japan), translations:
   {'ja' => {title: '裸の心', ruby: 'ハダカノココロ', romaji: 'Hadaka no kokoro', weight: 0, is_orig: true},
    'en' => {title: 'Naked Heart', weight: 100, }}},
]

n_musics = 0
artrans.each do |ea_hs|
  hs_main, hs_trans = split_hash_with_keys(ea_hs, %i(note year genre place))
  begin
    record = Music.update_or_create_with_translations!(hs_main, nil, mainkeys=%i(year), **hs_trans)
    n_musics += 1 if record.saved_changes?
  rescue MultiTranslationError::AmbiguousError => er
    # Skip, because at least one entry already exists.
    warn "WARNING: Multiple entries for a seeded Music are found. Your existing record may have duplications: "+er.message
  end
end
nrec += n_musics*2  # Music + 2 languages (In fact, this is not accurate... no changes in Translation are not considered.)

################################
# Load some engages

art = {}
enh = {}
mu  = {}
art[:harami] = Artist["ハラミちゃん", 'ja']
art[:kohmi]  = Artist[/広瀬\s*香美/, 'ja']
art[:aimyon] = Artist["あいみょん", 'ja']
enh[:sing]    = EngageHow[/singer.*origin/, 'en']
enh[:lyric]   = EngageHow[/lyric/i, 'en']
enh[:compose] = EngageHow[/compose/i, 'en']
enh[:play]    = EngageHow[/player/i, 'en']
# mu[:harami]  = Music["ハラミ体操", 'ja']
# mu[:fanfare] = Music["ファンファーレ", 'ja']
# mu[:rain]    = Music["雨", 'ja']
# mu[:nine47]  = Music["947", 'ja']
# mu[:hitori]  = Music["ひとり", 'ja']
{harami: "ハラミ体操", fanfare: "ファンファーレ", rain: "雨", nine47: "947", hitori: "ひとり", waltz_prayer: "祈りのワルツ"}.each_pair do |ek, ev|
  mu[ek] = (art[:harami].musics.joins(:translations).where("translations.title": ev).first || Music[ev, 'ja'])
end  # A way to prevent a song with the identical title by another artist from being picked up in repeated seeding.
mu[:romance] = Music["ロマンスの神様", 'ja']
mu[:naked]   = Music["裸の心", 'ja']
arengages = %i(harami fanfare rain nine47 hitori waltz_prayer).map{|i|
  %i(compose play).map{|ek|
    { note: nil, artist: art[:harami], engage_how: enh[ek],
      year: mu[i].year, music: mu[i]}
  }
}
arengages += [
  %i(sing lyric compose).map{|ek|
    { note: nil, artist: art[:kohmi],  engage_how: enh[ek],
      year: mu[:romance].year, music: mu[:romance]} },
  %i(sing lyric compose).map{|ek|
    { note: nil, artist: art[:aimyon], engage_how: enh[ek],
      year: mu[:naked].year,   music: mu[:naked]} },
]
arengages.flatten!

n_engages = 0
arengages.each do |ea_hs|
  next if !ea_hs[:engage_how]
  eng = Engage.find_or_initialize_by(**ea_hs.slice(*(%i(artist music engage_how year))))

  %w(note contribution).each do |i|
    eng.public_send(i+'=', ea_hs[i.to_sym]) if ea_hs[i.to_sym]
  end
  next if !eng.changed?

  eng.save!
  n_engages += 1
end

nrec += n_engages  # Engages

################################
# Load page_formats

ar_page_formats = [
  {mname: PageFormat::FULL_HTML,     description: 'Full unfiltered HTML'},
  {mname: PageFormat::FILTERED_HTML, description: 'Filtered restricted HTML'},
  {mname: PageFormat::MARKDOWN,      description: 'Markdown'},
]

n_page_formats = 0
ar_page_formats.each do |ea_hs|
  pf = PageFormat.find_or_initialize_by(mname: ea_hs[:mname])
  if pf.new_record?
    pf.update!(description: ea_hs[:description])
    n_page_formats += 1
  end
end

printf "%d PageFormats loaded.\n", n_page_formats if n_page_formats > 0
nrec += n_page_formats  # PageFormats

################################
# Load static_pages

if !(ENV['STATIC_PAGE_ROOT'] && ENV['STATIC_PAGE_FILES'])
  warn "fails to read (StaticPage-s) "+[ENV['STATIC_PAGE_ROOT'], ENV['STATIC_PAGE_FILES']].inspect
else
  n_static_pages = 0
  ENV['STATIC_PAGE_FILES'].split(/,/).each do |ftail|
    uri = ENV['STATIC_PAGE_ROOT'].strip.sub(%r@/$@, '')+'/'+ftail.strip
    begin
      page = StaticPage.load_file! uri, langcode: 'en'
    rescue ActiveRecord::RecordInvalid
      warn "This should not happen. One thing that could happen is that the titles for multiples files are identical; this happened when all the specified files were '301 Moved Permanently' - unexpectedly."
      raise
    end
    n_static_pages += 1 if page
  end
  printf "%d StaticPages loaded.\n", n_static_pages if n_static_pages > 0
  nrec += n_static_pages  # StaticPage
end

################################
# Auto loading external seed files

# For sorting
#
# returns either -1 or 1 if kwd is either a or b, respectively, else returning nil
#
# @param reverse [Boolean, NilClass] if true, the lower priority (= 1) is returned when a==kwd.
def _return_priority(a, b , kwd ,reverse: false)
  sign = (reverse ? -1 : 1)
  (ind = [a, b].index(kwd)) ? sign*(ind*2-1) : nil
end

# Some files depend on other files, which must be run before them.
# Generates the order.
rootdirs = [Rails.root, 'db', 'seeds']
allfiles = Dir[File.join(*(rootdirs+['*.rb']))].map{|s| s.sub(%r@.*\/db/seeds/(.+).rb@, '\1')}.sort{ |a, b|
  result = %w(seeds_user user seeds_event_group event_group instrument play_role channels).each do |kwd|  # WARNING: Be careful of plural and singular!
    reverse = ("channels" == kwd)
    ret = _return_priority(a,b,kwd, reverse: reverse)
    break ret if ret
  end
  result.respond_to?(:divmod) ? result : (a<=>b)  # result is either an Integer or (the original keyword) Array
}.map{|i| File.join(*(rootdirs+[i+'.rb']))}
#puts "DEBUG: seeding order:" ######### for DEBUG
#puts allfiles.map{|i| "    "+File.basename(i)}.join("\n") ######### for DEBUG

allfiles.each do |seed|
  next if "common.rb" == File.basename(seed)  # Skipping reading the common included Module
  seedfile2print = seed_fname2print(seed)
  puts "loading "+seedfile2print if $DEBUG  # defined in ModuleCommon

  begin
    require seed
    camel = File.basename(seed, ".rb").camelize
    begin
      klass =
        if /\ASeeds/ =~ camel
          camel.singularize.constantize      # e.g., SeedsUser
        else
          Seeds.const_get(camel) # e.g., Seeds::PlayRole
        end
    rescue NameError
      # maybe seeds_user.rb in the production environment, where SeedsUser is deliberately undefined.
      puts "NOTE: skip running "+seedfile2print #if $DEBUG
      next
    end
    if !klass.respond_to? :load_seeds 
      raise sprintf("ERROR(%s): In (%s), %s.%s is not defined.", File.basename(__FILE__), seedfile2print, camel, "load_seeds")
    end
    increment = klass.load_seeds  # execute the method in an external file
    nrec += increment 
    if (increment > 0 || $DEBUG) && (camel != "SeedsUser")  # This has been already printed in seeds_user.rb
      printf "(%s): %s %s (incl. Translations) are created/updated.\n", seedfile2print, increment, camel.sub(/^Seeds/, "").pluralize
    end
  rescue => err
    warn "Error raised while loading and running #{seedfile2print}"  # Without this, the traceback information (where it failed) would not be printed in testing.
    raise
  end
end  # (ar_priority + Dir[File.join(*(rootdirs+['*.rb']))]).uniq.each do |seed|

################################
# HaramiVid update_all-ed with the default Channel

def_channel = Channel.default(:HaramiVid)
if def_channel
  cnt_be4 = HaramiVid.where(channel_id: nil).count
  HaramiVid.where(channel_id: nil).update_all(channel_id: def_channel.id)
  cnt_aft = HaramiVid.where(channel_id: nil).count
  if 0 < (diff_cnt = cnt_aft - cnt_be4)
    puts "NOTE: #{diff_cnt} HaramiVid with a nil channel are updated to be associated with a default Channel."
  end
else
  warn "Default Channel is not found, hence no update_all with HaramiVid executed."
end

################################
# Final comment

if nrec <= 0
  warn "WARNING: All the seeds have already been implemented. No change."
else
  printf "Successfully seeded: %d entries in total.\n", nrec
end

end # def implant_seeds


################################
# Executing seeding
################################

fb0 = File.basename($0)
fbf = File.basename(__FILE__)
if (fb0 == fbf) || (fb0 == "ruby" && ARGV[1].present? && File.basename(ARGV[1]) ==fbf) || (fb0 == "rails" && ARGV.size == 0 && !is_env_set_positive?("DO_TEST_SEEDS"))  # defined in application_helper.rb 
  implant_seeds
end

