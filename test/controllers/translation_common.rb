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
    hsparam = hsparam.with_indifferent_access
    hsparam = hsparam[klass_dcase] if hsparam.has_key? klass_dcase
    # Creation fails because no Translation (or name) is specified.
    assert_no_difference(com2count) do
      assert_no_difference('Translation.count') do
        post send(url), params: { klass_dcase => _hsnew_with_title(hsparam, "") }
        assert_response :unprocessable_content #, "message is : "+flash.inspect
      end
    end
  
    # Creation fails because Translation (or name) is a duplicate.
    assert_no_difference(com2count) do
      assert_no_difference('Translation.count') do
        post send(url), params: { klass_dcase => hsparam}
        assert_response :unprocessable_content #, "message is : "+flash.inspect
      end
    end

    # Creation fails because Translation (or name) is a duplicate (after assimilated).
    title2 = _get_title_from_hsparam(hsparam).sub(/e/, 'ｅ').tr('t', 'ｔ')  # Zenkaku "e" and "t"
    #title2 = hsparam["title"].sub(/e/, 'ｅ').tr('t', 'ｔ')  # Zenkaku "e" and "t"
    assert_equal "Thｅ Tｅsｔ", title2, "sanity-check"
    assert_no_difference(com2count) do
      assert_no_difference('Translation.count') do

        post send(url), params: { klass_dcase => _hsnew_with_title(hsparam, title2)}
        #post send(url), params: { klass_dcase => hsparam.merge({"title"=>title2})}
        assert_response :unprocessable_content #, "message is : "+flash.inspect
      end
    end
  end

  def _hsnew_with_title(hsparam, new_title)
    # hsparam.has_key?(:title) ? hsparam.merge({"title"=>new_title}) : hsparam.merge({ translations_attributes: [hsparam[:translations_attributes][0].merge({title: new_title})] })
    hsparam.has_key?(:title) ? hsparam.merge({"title"=>new_title}) : params_hash_translation_array_with_new_title(hsparam, new_title)  # defined in test_helper.rb
  end
  private :_hsnew_with_title
 
  def _get_title_from_hsparam(hsparam)
    hsparam.has_key?(:title) ? hsparam["title"] : hsparam[:translations_attributes][0][:title]
  end
  private :_get_title_from_hsparam
end

