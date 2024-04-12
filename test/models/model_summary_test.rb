# coding: utf-8
# == Schema Information
#
# Table name: model_summaries
#
#  id         :bigint           not null, primary key
#  modelname  :string           not null
#  note       :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_model_summaries_on_modelname  (modelname) UNIQUE
#
require "test_helper"

class ModelSummaryTest < ActiveSupport::TestCase
  test "fixtures" do
    traja = translations(:model_summary_HaramiVid_ja)
    assert_equal "ja", traja.langcode
    assert_equal "HaramiVid", traja.translatable.modelname

    ms = model_summaries(:model_summary_HaramiVid)
    assert_equal "HaramiVid", ms.modelname
    assert_equal "ハラミちゃん動画", ms.title_or_alt(langcode: "ja"), "translations: "+ms.translations.inspect
  end
end
