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
    assert_equal exp, editor_only_safe_html(Music, method: :index, text: 9)
    exp = '<div class=""></div>'
    assert_equal exp, editor_only_safe_html(Music, method: :index, text: nil){9} # 9 should be stringfied.
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

end

