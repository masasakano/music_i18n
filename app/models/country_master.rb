# coding: utf-8
# == Schema Information
#
# Table name: country_masters
#
#  id                                                  :bigint           not null, primary key
#  end_date                                            :date
#  independent(Flag in ISO-3166)                       :boolean
#  iso3166_a2_code(ISO 3166-1 alpha-2, JIS X 0304)     :string
#  iso3166_a3_code(ISO 3166-1 alpha-3, JIS X 0304)     :string
#  iso3166_n3_code(ISO 3166-1 numeric-3, JIS X 0304)   :integer
#  iso3166_remark(Remarks in ISO-3166-1, 2, 3 in Hash) :json
#  name_en_full                                        :string
#  name_en_short                                       :string
#  name_fr_full                                        :string
#  name_fr_short                                       :string
#  name_ja_full                                        :string
#  name_ja_short                                       :string
#  note                                                :text
#  orig_note(Remarks by HirMtsd)                       :text
#  start_date                                          :date
#  territory(Territory names in ISO-3166-1 in Array)   :json
#  created_at                                          :datetime         not null
#  updated_at                                          :datetime         not null
#
# Indexes
#
#  index_country_masters_on_iso3166_a2_code  (iso3166_a2_code) UNIQUE
#  index_country_masters_on_iso3166_a3_code  (iso3166_a3_code) UNIQUE
#  index_country_masters_on_iso3166_n3_code  (iso3166_n3_code) UNIQUE
#
class CountryMaster < ApplicationRecord
  has_many :countries, dependent: :restrict_with_exception

  # Wrapper of {Country.load_one_from_master}
  #
  # @param check_clobber: [Boolean] if true (Def: false), and if the corresponding Country already exists, returns nil. If false, no check is performed and this method always attempts to create a Country.
  # @return [Country, NilClass] returns nil if self has a child Country (errors is set). Or, {Country#errors}.any? AND {#errors}.any? may be true if check_clobber is true and the corresponding Country, which is for some reason not the child of self, already exists.
  def create_child_country(check_clobber: false)
    if countries.present? 
      tit = name_en_full
      tit = name_en_short if tit.blank?
      errors.add :base, "No Country is created because a child Country already exists for CountryMaster (pID=#{id}): #{tit}"
      return
    end

    country = Country.load_one_from_master(country_master: self, check_clobber: check_clobber)

    if country.errors.any? 
      country.errors.full_messages.each do |msg|
        errors.add :base, msg
      end
    end

    country
  end

  # @return [Hash] to feed to create {Translation} associated to the corresponding {Country}
  #   e.g., {ja: {title: "英領インド洋地域", alt_title: nil, is_orig: false, weight: 0}, en: {...}, ...}
  def construct_hs_trans
    hstrans = {}.with_indifferent_access
    %w(ja en fr).each do |lc|
      hstrans[lc] = {
        langcode: lc,
        is_orig: true,
        weight: 0,
      }.with_indifferent_access
      hstrans[lc][:title]     = send('name_'+lc+'_full')
      hstrans[lc][:alt_title] = send('name_'+lc+'_short')

      case lc.to_s
      when "ja"
        _add_ruby!(hstrans[lc])
      when "en"
        _adjust_english!(hstrans[lc])
      when "fr"
        _adjust_french!(hstrans[lc])
      end
    end

    hstrans
  end

  private

  # adds ruby and alt_ruby to the given Hash.
  #
  # @param hsin [Hash] for Japanese Translation
  # @return [void]
  def _add_ruby!(hsin)
    %w(title alt_title).each do |att|
      rubycand = hsin[att].dup
      next if rubycand.blank?

      rubycand.gsub!(/南極/, "ナンキョク")
      rubycand.gsub!(/極南/, "キョクナン")
      rubycand.gsub!(/\(香港\)/, "ホンコン")
      rubycand.gsub!(/\(澳門\)/, "マカオ")
      rubycand.gsub!(/台湾\(タイワン\)/, "タイワン")
      rubycand.gsub!(/中華/, "チュウカ")
      rubycand.gsub!(/大韓民国/, "ダイカンミンコク")
      rubycand.gsub!(/日本/, "ニホン")
      rubycand.gsub!(/小離島/, "ショウリトウ")
      rubycand.gsub!(/多民族国/, "タミンゾクコク")
      rubycand.gsub!(/特別行政区/, "トクベツギョウセイク")
      rubycand.gsub!(/自治区/, "ジチク")
      rubycand.gsub!(/地域/, "チイキ")
      rubycand.gsub!(/西岸/, "セイガン")
      rubycand.gsub!(/朝鮮/, "チョウセン")
      rubycand.gsub!(/世界/, "セカイ")
      rubycand.gsub!(/社会/, "シャカイ")
      rubycand.gsub!(/民主/, "ミンシュ")
      rubycand.gsub!(/主義/, "シュギ")
      rubycand.gsub!(/人民/, "ジンミン")
      rubycand.gsub!(/共和/, "キョウワ")
      rubycand.gsub!(/連邦/, "レンポウ")
      rubycand.gsub!(/連合/, "レンゴウ")
      rubycand.gsub!(/合衆/, "ガッシュウ")
      rubycand.gsub!(/合州/, "ガッシュウ")
      rubycand.gsub!(/独立/, "ドクリツ")
      rubycand.gsub!(/首長/, "シュチョウ")
      rubycand.gsub!(/中央/, "チュウオウ")
      rubycand.gsub!(/東方/, "トウホウ")
      rubycand.gsub!(/赤道/, "セキドウ")
      rubycand.gsub!(/および/, "オヨビ")
      rubycand.gsub!(/王/, "オウ")
      rubycand.gsub!(/公/, "コウ")
      rubycand.gsub!(/領/, "リョウ")
      rubycand.gsub!(/東/, "ヒガシ")
      rubycand.gsub!(/西/, "ニシ")
      rubycand.gsub!(/南/, "ミナミ")
      rubycand.gsub!(/北/, "キタ")
      rubycand.gsub!(/諸/, "ショ")
      rubycand.gsub!(/島/, "トウ")
      rubycand.gsub!(/洋/, "ヨウ")
      rubycand.gsub!(/国/, "コク")
      rubycand.gsub!(/区/, "ク")
      rubycand.gsub!(/米/, "ベイ")
      rubycand.gsub!(/英/, "エイ")

      if /^[\p{katakana}\sー・=()]+$/ =~ rubycand
        hsin[att.sub(/title/, "ruby")] = rubycand
      end
    end
  end

  # @param hsin [Hash] for English Translation
  # @return [void]
  def _adjust_english!(hsin)
    %w(title alt_title).each do |att|
      next if hsin[att].blank?
      hsin[att].sub!(/^[tT]he\s+(.+)/, '\1, the')
      hsin[att].sub!(/\s+\(([tT]he)\)$/, ', \1')
    end
  end

  # @param hsin [Hash] for French Translation
  # @return [void]
  def _adjust_french!(hsin)
    %w(title alt_title).each do |att|
      next if hsin[att].blank? || hsin[att].strip.blank?
      if "title" == att && (mat0=/(.+)\s+\(\s*([^\)]+)\)(\*?)$/.match(hsin[att].strip))
        # if a pair of parentheses exist, the full "expanded" expression is defined as French "title", which may or may not include the article like "les", and that without that in the parentheses is defined as "alt_title"
        roottxt, prefix_content, asterisk = mat0[1], mat0[2].strip, mat0[3]
        article = ""
        if (mat1=/^([lL](?:'|(?:e|a|es)\b))\s*([^\)]*)$/.match(prefix_content))
          article, prefix_content = mat1[1], mat1[2].strip
        end
        article = ", "+article if !article.empty?
        prefix_content << " " if !prefix_content.empty?
        hsin["alt_title"] = roottxt + asterisk                    # e.g., Christmas
        hsin[att] = prefix_content + hsin["alt_title"] + article  # e.g., Île Christmas, l'  (from "Christmas (l'Île)")
      end
      hsin[att].sub!(/\s+\(\s*([lL](?:'|e|a|es))\s*\)(\*)$/, '\2, \1')
    end
  end
end

