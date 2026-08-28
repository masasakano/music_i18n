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
    title_core = Regexp.quote(@place.title_or_alt(lang_fallback_option: :either, article_to_head: true))  # Essential because the automatic title-guess prefers :en (if there is any), while Place <h1> ignores I18n.locale but displays it in the original language, and in this case (with @place), it is :ja
    h1_title_regex = /\b#{title_core}\b/
    do_basic_tests(h1_title_regex: h1_title_regex, fail_users: [@user_no_role], success_users: [@moderator_all, @editor_ja]) # using @anchorable # defined in /test/controllers/base_anchorings_controller_test.rb
  end
end

