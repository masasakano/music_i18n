# coding: utf-8
require 'test_helper'

# Common test routines for Controller tests
#
# @example Usage
#   require_relative 'translation_common'
#   class PlacesControllerTest < ActionDispatch::IntegrationTest
#     include ActionDispatch::IntegrationTest::TranslationCommon # from translation_common.rb
#     test "should create" do
#       hs2pass = { "langcode"=>"en", "title"=>"The Tｅst", "note"=>nil }
#       controller_trans_common(:place, hs2pass)  # defined in translation_common.rb
#     end
#   end
#
module ActionDispatch::IntegrationTest::TranslationCommon
  # @param klass_sym [Symbol] :place, :prefecture, etc
  # @param hsparam [Hash] the default params to pass to Controller
  # @return [void]
  def controller_trans_common(klass_sym, hsparam)
    com2count   = klass_sym.to_s.capitalize + '.count' 
    klass_dcase = klass_sym.to_s.downcase  # e.g., "place" (String)
    url = klass_dcase.pluralize + '_url'
    # Creation fails because no Translation (or name) is specified.
    assert_no_difference(com2count) do
      assert_no_difference('Translation.count') do
        post send(url), params: { klass_dcase => hsparam.merge({"title"=>""})}
        assert_response :unprocessable_content #, "message is : "+flash.inspect
      end
    end
  
    # Creation fails because Translation (or name) is a duplicate.
    place = nil
    assert_no_difference(com2count) do
      assert_no_difference('Translation.count') do
        post send(url), params: { klass_dcase => hsparam}
        assert_response :unprocessable_content #, "message is : "+flash.inspect
      end
    end

    # Creation fails because Translation (or name) is a duplicate (after assimilated).
    title2 = hsparam["title"].sub(/e/, 'ｅ').tr('t', 'ｔ')  # Zenkaku "e" and "t"
    assert_equal "Thｅ Tｅsｔ", title2
    assert_no_difference(com2count) do
      assert_no_difference('Translation.count') do
        post send(url), params: { klass_dcase => hsparam.merge({"title"=>title2})}
        assert_response :unprocessable_content #, "message is : "+flash.inspect
      end
    end
  end
end

