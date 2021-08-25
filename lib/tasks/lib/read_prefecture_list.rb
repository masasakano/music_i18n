#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# Read Prefecture_list.json

require 'active_support/all'
require 'json'

## Add --help option as an independent command
if $0 == __FILE__
  require 'optparse'
  opt = OptionParser.new <<-EOF
USAGE: #{File.basename($0)} [-h] YourDir/Prefecture_list.json (or STDIN) > STDERR
     : ruby -r#{File.basename($0)} -e 'my_hash = read_prefecture_list(verbose: false, file: "Prefecture_list.json")'
DESCRIPTION: diplays warnings if called from a command-line, and returns a Hash if called as a library.
DATA: <https://github.com/HirMtsd/Code.git>
  EOF
  begin
    opt.parse!(ARGV)
  rescue OptionParser::ParseError => err
    warn "Argument/Option ERROR - #{err}\nTo see help, run #{File.basename($0)} --help"
    exit 1
  end
  FILE_PREFECTURE_LIST = ARGF
else
  FILE_PREFECTURE_LIST = File.dirname(File.dirname(File.dirname(__FILE__)))+'/assets/seeds/Prefecture_list.json'
end

PREFECTURE_LANGUAGE_SYMBOLS = %i(ja en)

# Mapping of key(originl) => Table-column name
PREFECTURE_MAPPING = {
  "code"   => :iso3166_loc_code,
  "name"       => {ja: :title},
  "kana_name"  => {ja: {"full_lower" => :ruby}},  # "full_upper" for hankaku-kana
  "en_name"    => {en: {"en" => :title, "ja" => :alt_title}},
  "start_date" => :start_date,
  "end_date"   => :end_date,
  "note"   => :orig_note,
}

# Returns an Array of Hash-es each of which can e fed to {Prefecture#new} except
# for the keys of "lang:en" etc, each of which has a content of a Hash and
# should be used with {Prefecture#with_languages} .
#
# Note some parameters (Array or Hash) are passed as a JSON-string
#
# @example input file
#   {"code":"10", "name":"群馬県", "kana_name":{"half_upper":"ｸﾞﾝﾏｹﾝ", "full_lower":"グンマケン"},
#                                  "en_name":{"en":null, "ja":"Gunma"}, "start_date":"1947-05-03", "end_date":null,
#                                  "note":"英字表記について、外務省によるパスポートの英字表記はGummaであるが、ISO 3166-2には記載がない。https://www.pref.gunma.jp/04/c3610022.html"},
#
# @example return
#   [...,
#     {:iso3166_loc_code=>10,
#      "lang:ja"=>{:ja=>{:title=>"群馬県", :is_orig=>true, :weight=>0, :ruby=>"グンマケン"}},
#      "lang:en"=>{:en=>{:title=>nil, :alt_title=>"Gunma", :is_orig=>false, :weight=>0}},
#      :start_date=>"1947-05-03",
#      :end_date=>nil,
#      :orig_note=>"英字表記について、外務省によるパスポートの英字表記はGummaであるが、ISO 3166-2には記載がない。https://www.pref.gunma.jp/04/c3610022.html"},
#    ...]
#
# @param verbose: [Boolean] if false (Def), suppress the warnings of the data themselves.
# @return [Array<Hash<String, Object>>]
def read_prefecture_list(verbose: false, file: FILE_PREFECTURE_LIST)
  instr = (file.respond_to?(:read) ? file.read : File.read(file))
  JSON.parse(instr)["prefectures"].map{ |ei|
    artmp = ei.map{ |ek, ev|  # e.g., ["en_name", {"short": ...}]
      if PREFECTURE_MAPPING[ek].respond_to? :merge  # i.e., ek =~ /^(name|kana_name|en_name)/
        subk, subv = PREFECTURE_MAPPING[ek].first   # eg., [:en, {"en" => :title, "ja" => :alt_title}]
        grandchild = 
          if subv.respond_to?(:merge)
            # ja, en
            warn "WARNING: #{ek}=>#{ev.keys.sort}: #{ev}" if ![%w(full_lower half_upper), %w(en ja)].include?(ev.keys.sort) && verbose
            
            ev.map{ |k2, v2| subv[k2] ? [subv[k2], v2] : nil}.compact.to_h
          else
            # ja: :title
            {subv => ev}
          end

        grandchild[:is_orig] = ((subk == :ja) ? true : false)
        grandchild[:weight] = 0
        ['lang:'+subk.to_s, {subk => grandchild}]
      elsif ek == 'code'
        [PREFECTURE_MAPPING[ek], (ev ? ev.to_i : ev)]
      else
        [PREFECTURE_MAPPING[ek], (ev.respond_to?(:map) ? ev.to_json : ev)]
      end
    }  # .to_h would overwrite "lang:ja"=>{:ja=>{"title"=>"宮城県"}} and deletes it.

    hstmp = {}
    artmp.each do |ek, ev|
      if !hstmp.key? ek
        hstmp[ek] = ev
        next
      end

      # Merge the new Hash elements to an existing hash
      raise "Strange! Key=(#{ek}) appears multiple times in seed-Array=#{artmp.inspect}" if !hstmp[ek].respond_to? :keys
      raise "Strange! Existing Key=(#{ek}) has a strange shape (#{hstmp[ek]}) in seed-Array=#{artmp.inspect}" if hstmp[ek].keys.size != 1
      lc, _ = hstmp[ek].first
      raise "Strange! New Key=(#{ek}) has a strange shape (#{ev.inspect}) in seed-Array=#{artmp.inspect}" if ev.keys != [lc]
      hstmp[ek][lc].merge! ev[lc]
    end
    

    PREFECTURE_LANGUAGE_SYMBOLS.each do |lc|
      key = "lang:"+lc.to_s
      begin
        hstmp[key][lc][:title].blank?
      rescue NoMethodError
        print "DEBUG:key=#{key}; p=";p hstmp[key]
        raise
      end
      if hstmp[key][lc][:title].blank? && hstmp[key][lc][:alt_title].blank?
        warn sprintf("Blank record: Lang=%s, iso3166_loc_code=%s: %s", lc, hstmp[:iso3166_loc_code].inspect, hstmp[key][lc].inspect) if verbose
      end
    end
    hstmp
  }
end

if $0 == __FILE__
  read_prefecture_list(verbose: true)
end

