# coding: utf-8
require "application_system_test_case"

class Artists::MergesTest < ApplicationSystemTestCase
  setup do
    @artist = artists(:artist_saki_kubota)
    @moderator = users(:user_moderator_general_ja)
  end

  # called after every single test
  teardown do
    # when controller is using cache it may be a good idea to reset it afterwards
    Rails.cache.clear
  end

  test "visiting the index and then new" do
    visit new_user_session_path
    fill_in "Email", with: @moderator.email
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"
    assert_selector "h1", text: "Harami-chan"

    # Artist#index
    visit artists_url
    assert_selector "h1", text: "Artists"
    assert_selector 'form.button_to'
    click_on "Create New Artist"

    ### Artist#new page (EN)
    assert_selector "h1", text: "New Artist"
    css_swithcer_ja = 'div#language_switcher_top span.lang_switcher_ja a'
    css_swithcer_en = 'div#language_switcher_top span.lang_switcher_en a'
    assert_equal "日本語", page.find(css_swithcer_ja).text
    page.find(css_swithcer_ja).click
    # click_link "日本語" # => Capybara::Ambiguous: Ambiguous match, found 2 elements matching visible link "日本語"
    assert page.find('div#navbar_upper_any').text.include?("動画")

    ### Artist#new page (JA)
    #assert_selector "h1", text: "New Artist"
    # label_str = I18n.t('layouts.new_translations.model_language', model: 'Music')
    # find_field(label_str).choose('English')  ## Does not work b/c the label is just a <span>!
    page.find('form div.field.radio_langcode').choose('日本語')
    #choose '日本語'  # a name, id, or label text matching
    fill_in "artist_title", with: "久保田" # <input placeholder="例: The Beatles" type="text" name="artist[title]" id="artist_title">
    ## Alternative
    #label_str = I18n.t('layouts.new_translations.title', model: 'Music')
    #find_field(label_str, match: :first).fill_in with: 'Tekitoh'
    ## Other candidates...
    #page.find('form div.radio_langcode input.name[artist[langcode]]').choose('日本語')
    #page.find('form div.radio_langcode input.name[artist[langcode]]').select('日本語')
    #page.find('form div.radio_langcode input.#artist_langcode_ja').check  # click
              # 'html body div#body_main form div.field.radio_langcode input#artist_langcode_ja'
    # assert     find_field('国名')  # Capybara::ElementNotFound: Unable to find option "日本国" within #<Capybara::Node::Element tag="select" path="/HTML/BODY[1]/DIV[5]/FORM[1]/DIV[8]/SELECT[1]">
    assert_selector    'form div#div_select_country'
    assert_selector    'form div#div_select_prefecture', visible: :hidden
    assert_no_selector 'form div#div_select_prefecture'  # display: none
    assert_no_selector 'form div#div_select_place'       # display: none

    #selector = %Q{form div#div_select_country select option:contains("Japan")}
    #page.execute_script %Q{ $('#{selector}').trigger('mouseenter').click() }

    # Test of dropdown-menu
    #select('日本国',  from: '国名')
    refute page.all('form div#div_select_country option').map(&:text).include?("日本国")  # NOT "日本国"
    assert page.all('form div#div_select_country option').map(&:text).include?("日本")    # but "日本"
    page.find('form div#div_select_country').select('日本')
    csstxt = 'form div#div_select_prefecture'
    assert_selector    csstxt  # Now JS made it appear
    #page.find(csstxt).select('香川県')
    assert     find_field(  '都道府県')                  # Now JS made it appear
    select('香川県',  from: '都道府県')

    choose '不明'  # Sex  # a name, id, or label text matching
    wiki_new = "Wiki_Aya_Kubota"
    fill_in "Wikipedia (英語) URI", with: wiki_new # <label for="artist_wiki_en">/label>
    ##find_field('Year').fill_in with: '2001'
    testnote1 = "my test note for kubota new"
    find_field('artist_note').fill_in with: testnote1
    # choose "artist[note]", with: testnote1   # <textarea name="artist[note]" id="artist_note"></textarea>

    #fill_autocomplete('Associated Artist name', with: 'RCサクセ', select: 'RCサクセション')  # defined in test_helper.rb
    #assert_equal 'RCサクセション', find_field('Artist name').value
#page.all(:xpath, "//select[@id='" + select_id + "']/option").each do |e|
#  e.click
#end
#select_form_eh = page.find('form div.field select#music_engage_hows')
#select_form_eh.select('Arranger')
#select_form_eh.select('Conductor')
    click_on "登録する"

    ### Show page
    assert_text "Artist was successfully created"
    assert_selector "h1", text: "久保田"
    css_edit_button = 'div.link-edit-destroy > a:nth-child(1)'
    css_merge_edit = 'div.actions-destroy-align-r form:nth-child(1) > input'
    css_merge = 'div.link-edit-destroy ' + css_merge_edit
    txt_merge = "Merge with another Artist"

    assert_selector css_edit_button  # , text: 'Edit'  ('編集')
    assert_equal txt_merge, page.find(css_merge)["value"]
    css_align_r = 'div.actions-destroy-align-r'
    refute page.find(css_align_r).text.include?("cannot be destroyed")
    page.find(css_edit_button).click
    
    ### Edit page
    refute_selector css_edit_button  # , text: 'Edit'  ('編集') # NON-existing
    assert_equal txt_merge, page.find(css_merge_edit)["value"]
    refute page.find(css_align_r).text.include?("cannot be destroyed")

    assert_equal 2, page.all('p.navigate-link-below-form a').size  # Show and "Badk to Index"
    click_on txt_merge

    ### Merge new
#page.find(css_swithcer_en).click  ###### Language switching to English; for some reason, it seems t has been already in English..... Check it out!
    click_on "Proceed"  # With no input, but just Submit!  This should display just an error Flash message.
    assert page.all('p.alert').any?{|i| i.text.include? "No Artist"}, "failed: all css: "+page.all('p.alert').inspect

    fill_in "Other artist title", with: "そんな人いるわけないよ"
    click_on "Proceed"  # Submit with a wrong input!  This should display just an error Flash message.
    assert page.all('p.alert').any?{|i| i.text.include? "No Artist"}, "failed: all css: "+page.all('p.alert').inspect

    assert_selector 'form div.field label[for="artist_other_artist_id"]'
    assert_selector 'form div.field input#artist_with_id[name="artist[other_artist_title]"]'
      # <input id="artist_with_id" type="text" name="artist[other_artist_title]" class="ui-autocomplete-input" autocomplete="off">
    txt2sel = sprintf("%s [%s] [ID=%s]", @artist.title, 'ja', @artist.id) #  "久保田早紀" in translations.yml
    fill_autocomplete('Other artist title', with: '久保田', select: txt2sel)  # defined in test_helper.rb
    # NOTE: there should be only one candidate (though not tested here).
    click_on "Proceed"

    ### Merge edit
    assert_selector "h1", text: "Merge Artists"
    css_merge_th1  = 'form thead tr th:nth-child(3) a'
    th_text = page.find(css_merge_th1).text
    assert th_text.include?(@artist.id.to_s), "failed: id=#{@artist.id.to_s} th_text=#{th_text.inspect}" # Link to pID of "久保田早紀" at the 3rd column in <thead>

    css_merge_row1 = 'form tbody tr:nth-child(1)'
    th_text = page.find(css_merge_row1+' th').text
    assert_equal 'Merge to', th_text
    page.find(css_merge_row1+' td:nth-child(2) input').choose  # choose old "久保田早紀" for pID

    css_trow = 'form tbody tr#merge_edit_orig_language'
    assert_selector css_trow+' td:nth-child(2) input'
    assert_selector css_trow+' td:nth-child(3) input'
    page.find(      css_trow+' td:nth-child(3) input').choose

    css_trow = 'form tbody tr#merge_edit_translations'
    refute_selector css_trow+' td:nth-child(2) input'  # non-existent
    assert_selector css_trow+' td:nth-child(3) input:disabled:checked'

    css_trow = 'form tbody tr#merge_edit_engages'
    refute_selector css_trow+' td:nth-child(2) input'  # non-existent
    assert_selector css_trow+' td:nth-child(3) input:disabled:checked'

    css_trow = 'form tbody tr#merge_edit_place'
    assert               page.find(css_trow+' td:nth-child(2)').text.include?("Kagawa (Japan)")
    assert_selector css_trow+' td:nth-child(2) input:disabled:checked'
    assert_selector css_trow+' td:nth-child(3) input:disabled'
    assert_selector css_trow+' td:nth-child(3) input:not(:checked)'

    css_trow = 'form tbody tr#merge_edit_sex'
    assert_equal 'not known', page.find(css_trow+' td:nth-child(2)').text
    assert_selector css_trow+' td:nth-child(2) input:disabled:not(:checked)'
    assert_selector css_trow+' td:nth-child(3) input:disabled:checked'

    # Wiki En => the new one only
    css_trow = 'form tbody tr#merge_edit_wiki_en'
    assert_equal wiki_new,    page.find(css_trow+' td:nth-child(2) label').text
    assert_selector css_trow+' td:nth-child(2) input:disabled:checked'
    refute_selector css_trow+' td:nth-child(3) input'  # non-existent

    # Wiki Ja => both are nil.
    css_trow = 'form tbody tr#merge_edit_wiki_ja'
    refute_selector css_trow+' td:nth-child(2) input'  # non-existent
    refute_selector css_trow+' td:nth-child(3) input'  # non-existent

    # note: always no user check as they are simply merged.
    css_trow = 'form tbody tr#merge_edit_note'
    assert_equal testnote1, page.find(css_trow+' td:nth-child(2)').text
    refute_selector css_trow+' td:nth-child(2) input'  # non-existent
    refute_selector css_trow+' td:nth-child(3) input'  # non-existent

    click_on "Submit"

    ### Show page
    assert_text "Artists were successfully merged"
    assert_selector "h1", text: @artist.title
  end

end
