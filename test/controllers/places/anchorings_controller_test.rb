# coding: utf-8
require "test_helper"
require "controllers/base_anchorings_controller_test.rb"

class Places::AnchoringsControllerTest < BaseAnchoringsControllerTest  # < ActionDispatch::IntegrationTest
  include ActiveSupport::TestCase::ControllerAnchorableHelper

  setup do
    @anchorable = @place = places(:tocho)
    @anchorabl2 = places(:takamatsu_station)

    ## sanity checks
    [@anchorable, @anchorabl2].each do |anc|
      if (k1=anc.class.name) != (k2=self.class.name).split(":").first.singularize
        raise "Inconsistent @anchorable (< #{k1}) with the test class name (#{k2}) — check setup for @anchorable"
      end
    end
  end

  # ---------------------------------------------

  test "should create/update/destroy anchoring by editor" do
    do_basic_tests(fail_users: [@user_no_role], success_users: [@moderator_all, @editor_ja])   #   # defined in /test/controllers/base_anchorings_controller_test.rb
  end
end

