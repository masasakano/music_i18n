# coding: utf-8
require 'test_helper'

class InjectFromHarami1129Test < ActiveSupport::TestCase
  Klass = Harami1129s::InjectFromHarami1129 

  include ModuleCommon
  test "module common for distributed_insertion" do
    assert guess_japan_from_char('abc').unknown?
    assert guess_japan_from_char('あいうえお').unknown?
  end

  test "interpret_mapping_harami1129" do
    assert_equal :release_date, Klass::MAPPING_HARAMI1129[:harami_vid][:ins_release_date]
    #absm = Klass.new
    h1 = harami1129s(:harami1129one)
    h2 = harami1129s(:harami1129two)

    crows={}
    hshv2 = Klass.get_hsmain_to_update(h2, HaramiVid, crows, model_snake=nil) #ignore_double_us: false)
    release_date = Klass::MAPPING_HARAMI1129[:harami_vid][:ins_release_date] # == :release_date
    assert hshv2.key?(release_date)
    assert hshv2.key?(:uri)
    assert_match(%r@(youtu\.be|youtube\.com)/@, hshv2[:uri])

    hsat2 = Klass.get_hsmain_to_update(h2, Artist, crows, model_snake='artist') #ignore_double_us: false)
    assert_equal Sex[:unknown], hsat2[:sex]
    assert_equal %i(sex place), hsat2.keys, "hsat2=#{hsat2.inspect}"
    assert       hsat2[:place].unknown?

    tit2 = "harami1129two sing"
    assert_equal tit2, h2.singer  # Just to check
    destination = {:translations=>:title}
    ret = Klass.send(:interpret_mapping_harami1129_core, h2, :ins_singer, destination)
    exp = {:translations => {title: tit2}}
    assert_equal ret, **exp

    hstr2 = Klass.hash_for_trans(h2, Artist)
    assert hstr2.key?(:en)
    assert hstr2[:en].key?(:title)
    assert_equal({:en=>{:title=>"harami1129two sing", :is_orig=>true}}, hstr2)

    hsmu2 = Klass.hash_for_trans(h2, Music)
    assert hsmu2.key?(:en)
    assert hsmu2[:en].key?(:title)
    assert_equal({:en=>{:title=>"harami1129two music", :is_orig=>true}}, hsmu2)

    crows={}
    hsdh2 = Klass.get_destination_row(h2, HaramiVid, crows)
    assert_equal hshv2[:uri], hsdh2.uri
    assert_equal hshv2[release_date], hsdh2.send(release_date)  # :release_date
#print "DEBUG:test:hsdh2=";p hsdh2
    crows[:harami_vid] = hsdh2
    hsda2 = Klass.get_destination_row(h2, Artist, crows)
#print "DEBUG:test:hsda2=";p hsda2
    crows[:artist] = hsdh2
    

    #cells = absm.cells2inject(h2)
    #assert       h2[:song]
    #assert_equal h2[:song], cells[:ins_song], "cells=#{cells.inspect}"
  end
end

