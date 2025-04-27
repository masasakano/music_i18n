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
end
