require "application_system_test_case"

class PrefecturesTest < ApplicationSystemTestCase
  setup do
    @record = @prefecture = prefectures(:kagawa) # prefectures(:one)
    @model_underscore = @record.class.name.underscore
    @user_no_role = users(:user_no_role)
    #@translator = users(:user_translator)
    @moderator_ja = users(:user_moderator_general_ja)
  end

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
  end

  test "visiting the index and then new" do
    h1_title = "Prefectures"
    # visit prefectures_url
    assert_index_fail_succeed(prefectures_url, h1_title, user_fail: @user_no_role, user_succeed: @moderator_ja)  # defined in test_system_helper.rb
    # Now in Index page, logged in

    click_on "Create New Prefecture"
    assert_selector "h1", text: "New Prefecture"
    ensure_page_load_in_full_load  # defined in test_system_helper.rb

    new_title = "No place in World"
    fill_in_new_translations([{ title: new_title }])

    fill_in_main_note_with('Note prefecture 2-A')  # defined in test_system_helper.rb
    click_on "Create Prefecture"

    assert_selector "h1", text: new_title
    assert_text "Prefecture was "+(str="successfully created")
    flash_text_system_assert(str, type: [:notice, :success], category: :div)  # defined in test_helper.rb
    close_flash_windows([:notice, :success])  # defined in test_system_helper.rb

    ## testing switching locale
    record = Prefecture.last_created
    assert_equal :with_confirm, assert_switch_orig_locale(record, browser_locale=:en, to_locale: nil)  # defined in test_system_helper.rb
    assert assert_switch_orig_locale(record, browser_locale=:en, to_locale: :en)  # defined in test_system_helper.rb
    xpath_ja = switch_orig_locale(:ja)  # should fail to switch b/c no :ja Translation (but no exception or assertion failure)
    refute_selector :xpath, xpath_ja

    # Destroy button should be visible.
    assert_selector "#main_link_edit_merge_destroy .#{Consts::Csses::Layouts::DESTROY_LINK}"  # either <button> or <a>

    click_on "Back", match: :first
    assert_selector "h1", text: h1_title

    xpath_link = "//*[@id='body_main']//" +
                 ModuleCommon.xpath_contain_css(["table_index"], complete_for: "table") +
                 "/tbody/tr[" +
                 ModuleCommon.xpath_contain_text(new_title, case_insensitive: false) +
                 "]/td//" +
                 ModuleCommon.xpath_contain_css(Consts::Csses::Layouts::DESTROY_LINK, complete_for: "*")

    assert_selector :xpath, xpath_link
    assert_difference("Prefecture.count", -1){
      accept_confirm do
        page.find(:xpath, xpath_link).click
      end
      assert_text "Prefecture was "+(str="successfully destroyed")
      flash_text_system_assert(str, type: [:notice, :success], category: :div)  # defined in test_helper.rb
      close_flash_windows([:notice, :success])  # defined in test_system_helper.rb
    }
    refute_selector :xpath, xpath_link
  end

  #test "updating a Prefecture" do
  #  visit prefectures_url
  #  click_on "Edit", match: :first

  #  fill_in "Country", with: @prefecture.country_id
  #  fill_in "Note", with: @prefecture.note
  #  click_on "Update Prefecture"

  #  assert_text "Prefecture was successfully updated"
  #  click_on "Back"
  #end

  #test "destroying a Prefecture" do
  #  visit prefectures_url
  #  page.accept_confirm do
  #    click_on "Destroy", match: :first
  #  end

  #  assert_text "Prefecture was successfully destroyed"
  #end
end
