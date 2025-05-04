# coding: utf-8
require "test_helper"
require "controllers/base_anchorings_controller_test.rb"

class HaramiVids::AnchoringsControllerTest < BaseAnchoringsControllerTest  # < ActionDispatch::IntegrationTest
  include ActiveSupport::TestCase::ControllerAnchorableHelper
  
  setup do
    @anchorable = @harami_vid = harami_vids(:harami_vid1)
    @anchorabl2 = harami_vids(:harami_vid2)

    ## sanity checks
    [@anchorable, @anchorabl2].each do |anc|
      if (k1=anc.class.name) != (k2=self.class.name).split(":").first.singularize
        raise "Inconsistent @anchorable (< #{k1}) with the test class name (#{k2}) — check setup for @anchorable"
      end
    end
  end

  # ---------------------------------------------

  test "should create/update/destroy anchoring by Harami-editor" do
    do_basic_tests(h1_title_regex: /\bHARAMIchan\b.+\bvideo\b/i, fail_users: [@editor_ja], success_users: [@moderator_all, @editor_harami])   # defined in /test/controllers/base_anchorings_controller_test.rb
  end


  test "should create an anchoring for Youtube-comment by Harami-editor" do
    url1 = ApplicationHelper.normalized_uri_youtube(@anchorable.uri, long: true,  with_scheme: true)+"&lc=UgxffvDXzEaXVHqYcMF4AaABAg"
    exp1 = ApplicationHelper.normalized_uri_youtube(@anchorable.uri, long: false, with_scheme: true)+"?lc=UgxffvDXzEaXVHqYcMF4AaABAg"  # the query part starting with "?"
    assert_equal "https://", url1[0..7], 'sanity check'
    assert_equal "https://", exp1[0..7], 'sanity check'
    tit1 = "セットリスト 2019-10-26生配信 (Youtubeコメント)"
    note1 = "note-1"
    sc_sns = site_categories(:site_category_sns)

    new1 = _assert_create_anchoring_url_core(@anchorable,
              fail_users: [], success_users: [@moderator_all],
              url_str: url1, url_langcode: "ja", note: note1,
              title: tit1,
              site_category_id: sc_sns.id.to_s,
              diff_num: 10011)  #, is_debug: true)

    assert_equal "ja",   new1.url.url_langcode
    assert_equal tit1,   new1.url.title
    refute_equal SiteCategory.unknown, new1.site_category, "SiteCategory should NOT be the unknown one, but..."
    assert_equal sc_sns, new1.url.site_category
    assert_equal exp1,   new1.url.url
  end
end
