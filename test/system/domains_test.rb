require "application_system_test_case"

class DomainsTest < ApplicationSystemTestCase
  setup do
    model = @domain = domains(:one)
    @artist = artists(:artist_saki_kubota)
    @moderator_all   = users(:user_moderator_all)         # General-JA Moderator can manage.
    @editor_harami   = users(:user_editor)                # Harami Editor can manage.
    @moderator_harami= users(:user_moderator)             # Harami Moderator can manage.
    @translator      = users(:user_translator)            # Translator can read but not create/delete.
    @trans_moderator = users(:user_moderator_translation) # Translator cannot create/delete but edit (maybe!).
    @editor_ja       = users(:user_editor_general_ja)     # Same as Harami-editor
    @moderator_gen   = users(:user_moderator_general_ja)
    @h1_title = "Domains"
    but_text = model.class.name.underscore.gsub(/_/, ' ').capitalize # "Domain title" (SimpleForm default)
    @button_text = {
      create: "Create #{but_text}",
      update: "Update #{but_text}",
    }
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "visiting the index" do
    assert_index_fail_succeed(@domain, user_fail: @editor_harami, user_succeed: @trans_moderator)  # defined in test_system_helper.rb
  end

  #test "should create domain" do
  #  visit domains_url
  #  click_on "New domain"

  #  fill_in "Domain", with: @domain.domain
  #  #fill_in "Domain title", with: @domain.domain_title_id   ## select...
  #  fill_in "Note", with: @domain.note
  #  click_on "Create Domain"

  #  assert_text "Domain was successfully created"
  #  click_on "Back"
  #end

  #test "should update Domain" do
  #  visit domain_url(@domain)
  #  click_on "Edit this domain", match: :first

  #  fill_in "Domain", with: @domain.domain
  #  #fill_in "Domain title", with: @domain.domain_title_id   ## select...
  #  fill_in "Note", with: @domain.note
  #  click_on "Update Domain"

  #  assert_text "Domain was successfully updated"
  #  click_on "Back"
  #end

  #test "should destroy Domain" do
  #  visit domain_url(@domain)
  #  click_on "Destroy this domain", match: :first

  #  assert_text "Domain was successfully destroyed"
  #end
end
