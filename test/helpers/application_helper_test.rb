# coding: utf-8
require 'test_helper'
#require "capybara/minitest"

class ApplicationHelperTest < ActionView::TestCase
  ## add this
  #include Devise::Test::IntegrationHelpers
  #include Capybara::Minitest::Assertions

  #
  # cf. https://gorails.com/blog/how-to-test-helpers-in-rails-with-devise-current_user-and-actionview-testcase
  def current_user
    @current_user
  end

  # mocking can? in View context
  def can?(*arg)
    Ability.new(@current_user).can?(*arg)
  end

  setup do
    # @current_user = User.first
  end

  teardown do
    Rails.cache.clear
  end

  test "editor_only_safe_html" do
    music = musics(:music1)

    ## Testing for the non-authenticated
    @current_user = nil
    assert_raises(ArgumentError){ editor_only_safe_html("") }

    assert_equal("",  editor_only_safe_html(Role,  method: :index, text: "abc"))
    assert_equal("",  editor_only_safe_html(music,  method: :edit, text: "abc"))
    exp = '<div class="">abc</div>'
    assert_equal exp, editor_only_safe_html(Music, method: :index, text: "abc")

    exp = '<div class="">9</div>'
    assert_equal exp, editor_only_safe_html(Music, method: :index, text: 9) # 9 should be stringfied.
    assert            editor_only_safe_html(Music, method: :index, text: nil){"  "}.blank?
    assert_raises(StandardError) {
                      editor_only_safe_html(Music, method: :index, text: [])  } # NoMethodError caused by sanitize()  # but the error type may change in the future

    mu = musics(:music1)
    exp = '<p class="x &lt;">abc</p>'
    act = editor_only_safe_html(mu,    method: :show, tag: "p", class: "x <"){ "abc" }
    assert_equal exp, act
    assert       act.html_safe?

    exp = '<div class="">&lt;</div>'
    act = editor_only_safe_html(mu,    method: :show, text: "<")
    assert_equal exp, act
    assert       act.html_safe?

    assert_equal editor_only_safe_html(mu, method: :show, text: "<hr>"), editor_only_safe_html(mu, method: :show){"<hr>"}

    exp = '<div class="">AAA</div>'
    act = editor_only_safe_html(mu,    method: :show){ "AAA<script>" }
    assert_equal exp, act
    assert       act.html_safe?

    exp = '<div class="">AAA<script></div>'
    act = editor_only_safe_html(mu,    method: :show){ "AAA<script>".html_safe }
    assert_equal exp, act
    assert       act.html_safe?

    ## Testing for sysadmin
    @current_user = users(:user_editor)
    #@current_user = users(:user_sysadmin)

    exp = '<p class="x &lt; editor_only">abc</p>'
    act = editor_only_safe_html(music,  method: :edit, tag: "p", class: "x <"){ "abc"}
    assert_equal exp, act

    act = editor_only_safe_html(Role,    method: :edit, tag: "p", class: "x <"){ "abc"}
    assert_equal  "", act, "Editor cannot edit Role, but..."

    exp = '<div class="moderator_only">AAA<script></div>'
    act = editor_only_safe_html(music,  method: :edit, only: :moderator){ "AAA<script>".html_safe }
    assert_equal exp, act
    assert       act.html_safe?

    exp = '<div class="x &lt; my_klass">AAA</div>'
    act = editor_only_safe_html(music,  method: :edit, class: "x <", only: "my_klass"){ "AAA<script>" }
    assert_equal exp, act
    assert       act.html_safe?

    assert_raise(ArgumentError){ 
        editor_only_safe_html(music, method: "xy", permissive: false, text: "xyz") }
    assert_raise(ArgumentError){ 
        editor_only_safe_html(:abc, method: :edit, permissive: false, text: "xyz") }
    assert_raise(ArgumentError){ 
        editor_only_safe_html(:abc, method: :edit,                    text: "xyz") }

    exp = '<div class="x &lt; my_klass">AAA</div>'
    act = editor_only_safe_html(:pass,  method: true, class: "x <", only: "my_klass"){ "AAA<script>" }
    assert_equal exp, act

    exp = '<div class="x &lt; my_klass">AAA</div>'
    act = editor_only_safe_html(:pass,  method: false, class: "x <", only: "my_klass"){ "AAA<script>" }
    assert_equal "", act
  end

  test "sorted_title_ids" do
    org_locale = I18n.locale
    begin
      I18n.locale = "en"
      ary = sorted_title_ids(ChannelOwner.all, method: :title_or_alt_for_selection_optimum).map(&:first)
      assert_includes ary, "HARAMIchan"
      assert_includes ary, "Kohmi Hirose"
      assert_operator ary.find_index("HARAMIchan"), :<, ary.find_index("Kohmi Hirose")

      ctype = channel_types(:channel_type_sub)
      assert_equal ["Side channel", "Secondary"], [ctype.title, ctype.alt_title].sort.reverse, "fixture sanity check..."
      rela_ctype = ChannelType.where(id: ctype.id)
      ary = sorted_title_ids(rela_ctype, method: :title_or_alt_for_selection_optimum).map(&:first)
      assert_equal "Side channel", ary[0]
      ary = sorted_title_ids(rela_ctype, method: :title_or_alt, langcode: I18n.locale).map(&:first)
      assert_equal "Side channel", ary[0]
      ary = sorted_title_ids(rela_ctype, method: :title_or_alt, langcode: I18n.locale, prefer_shorter: true).map(&:first)
      assert_equal "Secondary", ary[0]
    ensure
      I18n.locale = org_locale
    end
  end
end

