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
    assert_selector "h1", text: "HARAMIchan"

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

  test "populate Harami1129s and merge artists" do
    h1129s = [harami1129s(:harami1129_sting1), harami1129s(:harami1129_sting2)]
    art_ids = []  # "Populated" Artist IDs
    mus_ids = []  # "Populated" Music IDs
    artists = []  # Artists after "Populated"

    visit new_user_session_path
    fill_in "Email", with: users(:user_moderator).email  # All-mighty moderator
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"
    assert_selector "h1", text: "HARAMIchan"

    # Harami1129#index
    #visit harami1129s_url  # Same as below.
    find(:xpath, "//div[@id='navbar_upper_user']//li[@class='nav-item']//a[text()='Harami1129s']").click

    assert_selector "h1", text: "Harami1129s"

    (0..1).each do |i_h1129|
      h1129 = h1129s[i_h1129]

      if 0 == i_h1129
        # internal insertion
        visit harami1129_url(h1129)
        assert_selector "h1", text: "HARAMI1129 Entry"
        assert_equal h1129.id, page.find("dl#h1129_main_dl dd#h1129_id_dd").text.to_i
        assert_selector 'form div.actions input[type="submit"][value="Insert within Table"]'
        refute_selector 'form div.actions input[type="submit"][value="Populate"]'
        click_on "Insert within Table"

        assert_selector "h1", text: "HARAMI1129 Entry"
        msg_notice = page.find(:xpath, "//div[@id='body_main']/p[contains(@class, 'notice')][1]").text.strip  # Notice message issued.
        assert_match(/ID=#{h1129.id}\b.+\bupdated for ins_COLUMNS/, msg_notice)  # ID=12345 in Harami1129 is updated for ins_COLUMNS.
        assert_equal h1129.id, page.find("dl#h1129_main_dl dd#h1129_id_dd").text.to_i
        assert_selector 'form input[type="submit"][value="Populate"]'
      end

      # Click "Show"
      visit harami1129s_url
      find(:xpath, "//table[contains(@class, 'harami1129s_grid')]//tr/td[contains(@class, 'title')]/a[text()[contains(., '#{h1129.title}')]]/../../td[contains(@class, 'actions')]/a[text()='Show']").click  # NOTE: Title may be preceded with an emoji-symbol

      assert_selector "h1", text: "HARAMI1129 Entry"
      %w(title singer song).each do |ek|
        ddid = "h1129_"+ek+"_dd"
        exp = h1129.send(ek).strip
        assert_equal exp, _get_h1129_table_cell(ddid, "Downloaded")
        assert_equal exp, _get_h1129_table_cell(ddid, "Internally inserted")
        assert_equal "",  _get_h1129_table_cell(ddid, "Current Destination"), "No destination should be defined for #{ek}, but..."
      end
      
      click_on "Populate"  # Creating Artist (<=Singer) and Music (<= Song)
      assert_selector "h1", text: "HARAMI1129 Entry"
      %w(title singer song).each do |ek|
        ddid = "h1129_"+ek+"_dd"
        exp = h1129.send(ek).strip
        assert_equal exp, _get_h1129_table_cell(ddid, "Current Destination"), "Destination should have been defined for #{ek}, but..."
        case ek
        when "singer", "song"
          id_entry = File.basename(page.find(:xpath, "//dl[@id='h1129_main_dl']/dd[@id='#{ddid}']//table//th[a='Current Destination']/a")["href"].strip).to_i
          assert_operator 0, :<, id_entry, "#{ek} should have a positive ID assigned, but..."
          if "singer" == ek
            art_ids[i_h1129] = id_entry
          else
            mus_ids[i_h1129] = id_entry
          end
        else
          # skip
        end
      end # %w(title singer song).each do |ek|
    end   # (0..1).each do |i_h1129|

    assert_not_equal art_ids[0], art_ids[1], "Two Artists (to be merged) should exist, but..."
    assert_not_equal mus_ids[0], mus_ids[1]

    artists = art_ids.map{|i| Artist.find i}

    ## merging - option is not provided because the user is an only-Harami1129 moderator
    visit artist_path(art_ids[0])
    assert_selector :xpath, "//input[@type='submit' and @value='Add translation']"
    refute_selector :xpath, "//input[@type='submit' and @value='Merge with another Artist']"

    ## Logout and back in as a full moderator.
    page.find(:xpath, "//div[@id='navbar_top']//a[text()='Log out']").click
    assert_equal "Signed out successfully.", page.find(:xpath, "//div[@id='body_main']/p[contains(@class, 'notice')][1]").text.strip  # Notice message issued.

    page.find("div#home_bottom a.login-button").click  # In the bottom menu.
    #visit new_user_session_path  # equivalent.
    fill_in "Email", with: users(:user_moderator_all).email  # All-mighty moderator
    fill_in "Password", with: '123456'  # from users.yml
    click_on "Log in"

    assert_selector "h1", text: "HARAMIchan"

    ## select a record for merging
    visit artist_path(art_ids[0])
    assert_selector :xpath, "//div[contains(@class, 'link-edit-destroy')]//div[contains(@class, 'actions-destroy')]//input[@disabled='disabled' and @type='submit' and @value='Destroy']"  # "Destroy button for Artist should be disabled, but..."
    click_on "Merge with another Artist" 

    assert_selector "h1", text: "Merge Artists (#{h1129s[0].singer.strip})"
    fill_in "Artist-ID (to merge this with)", with: "-5"
    click_on "Proceed"

    ## jumping to merging page failed
    assert_selector "h1", text: "Merge Artists (#{h1129s[0].singer.strip})"
    assert page.find(:xpath, "//div[@id='body_main']/p[contains(@class, 'alert-danger')][1]").text.strip.include?("No Artist matches")  # Warning message "No Artist matches the given one. Try a different title or ID." issued.
    fill_in "Artist-ID (to merge this with)", with: art_ids[0]  # identical ID => should fail.
    click_on "Proceed"

    ## jumping to merging page failed
    assert_selector "h1", text: "Merge Artists (#{h1129s[0].singer.strip})"
    assert page.find(:xpath, "//div[@id='body_main']/p[contains(@class, 'alert-danger')][1]").text.strip.include?("Identical Artists specified")  # Warning message "Identical Artists specified. Try a different title or ID." issued.

    ## try with a correct record
    assert_selector "h1", text: "Merge Artists (#{h1129s[0].singer.strip})"
    fill_in "Artist-ID (to merge this with)", with: art_ids[1]
    click_on "Proceed"

    assert_selector "h1", text: "Merge Artists"
    assert_match(/Back to\b.* ID.+#{art_ids[0]}\b/, page.find("p.navigate-link-below-form > a:nth-child(1)").text.strip)
    [0, 1].each do |i|
      assert_match(/\b#{artists[i].orig_translation.title}\b/, page.find(:xpath, "//form//table//thead//th[#{i+2}]").text.strip, '"Sting" or "スティング" should exist in the Table header, but...')
    end
    assert_match(/Merged\b/, page.find(:xpath, "//form//table//thead//th[4]").text.strip)

    # column Merged
    assert_match(/\b#{art_ids[0]}\b/, page.find(:xpath, "//form//tbody//tr[@id='merge_edit_merge_to']//td[3]").text.strip)  # ID=873 etc. (the first-Artist ID) in the column "Merged"
    tra = artists[0].orig_translation
    assert_match(/\b#{tra.langcode}\b.+#{tra.title}\b/m, page.find(:xpath, "//form//tbody//tr[@id='merge_edit_orig_language']//td[3]").text.strip, '"Sting" should exist in the column for the merged result, but...')  # "Sting" 
    tra = artists[1].translations.first
    assert_match(/\b#{tra.langcode}\b.+#{tra.title}\b/m, page.find(:xpath, "//form//tbody//tr[@id='merge_edit_translations']//td[3]").text.strip, '"スティング" should exist in the column for the merged result, but...')  # is_orig=true for "スティング", but it should appear in the third row (Translations), because "Sting" is for orig-language in default (because this path/page is for it).
    assert_match(/\bYork\b.+\bYorkkk\b/m, page.find(:xpath, "//form//tbody//tr[@id='merge_edit_engages']//td[3]").text.strip, 'Both Musics should exist in the column for the merged Engage-Musics, but...')
    assert_match(/\bUnknown\b.+\bJapan\b/m, page.find(:xpath, "//form//tbody//tr[@id='merge_edit_place']//td[3]").text.strip, 'Unknown(Japan) should appear in the column for the merged Place because it is narrower than Unknown-World, but...')

    ## submit to reload
    page.find(:xpath, "//form//*[@id='merge_edit_merge_to']//input[@id='artist_to_index_1']").choose
    page.find(:xpath, '//form//*[@id="merge_edit_orig_language"]//input[@id="artist_lang_orig_1"]').choose
    click_on "Reload"

    assert_selector "h1", text: "Merge Artists"
    assert_match(/Back to\b.* ID.+#{art_ids[0]}\b/, page.find("p.navigate-link-below-form > a:nth-child(1)").text.strip)
    assert_match(/\b#{art_ids[1]}\b/, page.find(:xpath, "//form//tbody//tr[@id='merge_edit_merge_to']//td[3]").text.strip, "should have changed to (#{art_ids[1]}), but...")  # ID=874 etc. (the "second"-Artist ID) in the column "Merged"
    tra = artists[1].orig_translation
    assert_match(/\b#{tra.langcode}\b.+#{tra.title}\b/m, page.find(:xpath, "//form//tbody//tr[@id='merge_edit_orig_language']//td[3]").text.strip, 'This time, "スティング" should exist in the column for the merged result, but...') # swapped!
    tra = artists[0].translations.first
    assert_match(/\b#{tra.langcode}\b.+#{tra.title}\b/m, page.find(:xpath, "//form//tbody//tr[@id='merge_edit_translations']//td[3]").text.strip, 'This time, "Sting" should exist in the column for the merged result, but...')  # swapped!

    ## submit
    click_on "Submit"

    ## Logout just in case.
    page.find(:xpath, "//div[@id='navbar_top']//a[text()='Log out']").click
  end

  private
    # Returns a table cell String, after searching with XPath
    # @return [String]
    def _get_h1129_table_cell(ddid, th_row)
      page.find(:xpath, "//dl[@id='h1129_main_dl']/dd[@id='#{ddid}']//table//tr[th='#{th_row}']/td[1]").text.strip
                      # "//dl[@id='h1129_main_dl']/dd[@id='#{ddid}']//table//tr/td[text()=#{th_row}]/following-sibling::td[1]"  # Same meaning as the above.
    end
    private :_get_h1129_table_cell
end

