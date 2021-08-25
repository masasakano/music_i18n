#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# Read Country_list.json

require 'active_support/all'
require 'json'

## Add --help option as an independent command
if $0 == __FILE__
  require 'optparse'
  opt = OptionParser.new <<-EOF
USAGE: #{File.basename($0)} [-h] YourDir/Country_list.json (or STDIN) > STDERR
     : ruby -r#{File.basename($0)} -e 'my_hash = read_country_list(verbose: false, file: "Country_list.json")'
DESCRIPTION: diplays warnings if called from a command-line, and returns a Hash if called as a library.
DATA: <https://github.com/HirMtsd/Code.git>
  EOF
  begin
    opt.parse!(ARGV)
  rescue OptionParser::ParseError => err
    warn "Argument/Option ERROR - #{err}\nTo see help, run #{File.basename($0)} --help"
    exit 1
  end
  FILE_COUNTRY_LIST = ARGF
else
  FILE_COUNTRY_LIST = File.dirname(File.dirname(File.dirname(__FILE__)))+'/assets/seeds/Country_list.json'
end


# Mapping of key(originl) => Table-column name
COUNTRY_MAPPING = {
  "code"   => :iso3166_a2_code,
  "codeA3" => :iso3166_a3_code,
  "codeN3" => :iso3166_n3_code,
  "name"     => {ja: {"full" => :title, "short" => :alt_title}},
  "en_name"  => {en: {"full" => :title, "short" => :alt_title, "en_short" => :alt_title}},  # "en_short" only for iso3166_n3_code: 654 (Saint Helena etc)
  "fr_name"  => {fr: :title},
  "independent" => :independent,
  "territory"   => :territory,
  "remark" => :iso3166_remark,
  "note"   => :orig_note,
  "start_date" => :start_date,
  "end_date"   => :end_date,
}

# Returns an Array of Hash-es each of which can e fed to {Country#new} except
# for the keys of "lang:en" etc, each of which has a content of a Hash and
# should be used with {Country#with_languages} .
#
# Note some parameters (Array or Hash) are passed as a JSON-string
#
# @example input file
#   {"code": "IO", "codeA3": "IOT", "codeN3": "086", "name": {"full": "英領インド洋地域", "short": null},
#                 "en_name": {"short": "British Indian Ocean Territory (the)", "full": null}, "fr_name": "Indien (le Territoire britannique de l'océan)",
#                 "independent": false, "territory":["Chagos Archipelago", "Diego Garcia"],
#                 "remark": {"part1": "Comprises: Chagos Archipelago (Principal island: Diego Garcia). No subdivision reported", "part2": "No subdivisions relevant for this standard."},
#                 "note": null,
#                 "start_date": null, "end_date": null},
#
# @example return
#   [...,
#     {:iso3166_a2_code=>"IO",
#      :iso3166_a3_code=>"IOT",
#      :iso3166_n3_code=>86,
#      "lang:ja"=>{:ja=>{"title"=>"英領インド洋地域", "alt_title"=>nil, :is_orig=>false, :weight=>0}},
#      "lang:en"=>{:en=>{"title"=>nil, "alt_title"=>"British Indian Ocean Territory (the)", :is_orig=>true, :weight=>0}},
#      "lang:fr"=>{:fr=>{"title"=>"Indien (le Territoire britannique de l'océan)", :is_orig=>false, :weight=>0}},
#      :independent=>false,
#      :territory=>"[\"Chagos Archipelago\",\"Diego Garcia\"]",
#      :iso3166_remark=>"{\"part1\":\"Comprises: Chagos Archipelago (Principal island: Diego Garcia). No subdivision reported\",\"part2\":\"No subdivisions relevant for this standard.\"}",
#      :orig_note=>nil,
#      :start_date=>nil,
#      :end_date=>nil},
#    ...]
#
# @param verbose: [Boolean] if false (Def), suppress the warnings of the data themselves.
# @return [Array<Hash<String, Object>>]
def read_country_list(verbose: false, file: FILE_COUNTRY_LIST)
  instr = (file.respond_to?(:read) ? file.read : File.read(file))
  JSON.parse(instr)["countries"].map{ |ei|
    hstmp = ei.map{ |ek, ev|  # e.g., ["en_name", {"short": ...}]
      if COUNTRY_MAPPING[ek].respond_to? :merge  # i.e., ek =~ /^(name|en_name|fr_name)/
        subk, subv = COUNTRY_MAPPING[ek].first   # eg., [:ja, {"full" => "title", "short" => "alt_title"}]
        grandchild = 
          if subv.respond_to?(:merge)
            # ja, en
            warn "WARNING: #{ek}=>#{ev.keys.sort}: #{ev}" if ev.keys.sort != %w(full short) && verbose
            ev.map{ |k2, v2| [subv[k2], v2]}.to_h
          else
            # fr
            {subv => ev}
          end

        grandchild[:is_orig] = 
          if    subk == :ja && grandchild[:title] == '日本国'
            true
          elsif subk == :en && grandchild[:alt_title] != 'Japan' && grandchild[:alt_title] != 'France'
            true
          elsif subk == :fr && grandchild[:title] == 'France (la)'
            true
          else
            false
          end
        grandchild[:weight] = 0
        ['lang:'+subk.to_s, {subk => grandchild}]
      elsif ek == 'codeN3'
        [COUNTRY_MAPPING[ek], (ev ? ev.to_i : ev)]
      else
        [COUNTRY_MAPPING[ek], (ev.respond_to?(:map) ? ev.to_json : ev)]
      end
    }.to_h

    %i(ja en fr).each do |lc|
      key = "lang:"+lc.to_s
      hstmp[key][lc][:title].blank?
      if hstmp[key][lc][:title].blank? && hstmp[key][lc][:alt_title].blank?
        warn sprintf("Blank record: Lang=%s, iso3166_a2_code=%s, iso3166_n3_code=%s: %s", lc, hstmp[:iso3166_a2_code].inspect, hstmp[:iso3166_n3_code].inspect, hstmp[key][lc].inspect) if verbose
        if lc == :ja
          replace = 
            case hstmp[:iso3166_n3_code]
            when 535
              'ボネール、シント・ユースタティウスおよびサバ'
            when 531
              'キュラソー'
            when 534
              'シント・マールテン'
            else
              nil
            end

          if replace
            hstmp[key][lc][:title] = replace
            warn "fixed with #{replace.inspect}."  if verbose
          end
        end
      end
    end
    hstmp
  }
end

if $0 == __FILE__
  read_country_list(verbose: true)
end

