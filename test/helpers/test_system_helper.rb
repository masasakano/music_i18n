# coding: utf-8
require "test_helper"

# @example
#    require "helpers/test_system_helper"
#
class ActiveSupport::TestCase

  CSSQUERIES ||= {}.with_indifferent_access
  CSSQUERIES[:error_div] ||= {}.with_indifferent_access
  CSSQUERIES[:error_div][:whole] = 'div#error_explanation'
  CSSQUERIES[:error_div][:title] = CSSQUERIES[:error_div][:whole]+" h2"
  CSSQUERIES[:hidden] ||= {}.with_indifferent_access
  CSSQUERIES[:hidden][:prefecture] = 'form div#'+ApplicationController::HTML_KEYS[:ids][:div_sel_prefecture]+' div.form-group'
  CSSQUERIES[:hidden][:place]      = 'form div#'+ApplicationController::HTML_KEYS[:ids][:div_sel_place]+     ' div.form-group'
    # e.g., assert_selector ActiveSupport::TestCase::CSSQUERIES[:hidden][:place], visible: :hidden
    #       assert_no_selector ActiveSupport::TestCase::CSSQUERIES[:hidden][:place] # display: none
    #       assert_empty page.find_all(:xpath, "//form//div[@id='#{ApplicationController::HTML_KEYS[:ids][:div_sel_place]}']//div[contains(@class, 'form-group')][contains(@style,'display: none;')]")
    # c.f., in the old-school FORM:  assert_selector 'form div#div_select_place', visible: :hidden

  CSSQUERIES[:trans_new] ||= {}.with_indifferent_access
  # Note: for the old-style Rails form: page.find('form div.field.radio_langcode')
  %w(langcode is_orig).each do |es|
    CSSQUERIES[:trans_new][es+"_radio"] = "form fieldset.%s_"+ApplicationController::PARAMS_NAMES[:trans][es].to_s # NOTE: requires model-name!!
    # e.g., 'form fieldset.%s_langcode'
    #       'form fieldset.%s_best_translation_is_orig'
  end

  # @example Controller test
  #   assert_empty css_select(css_query(:trans_new, :is_orig_radio, model: Model))  # defined in helpers/test_system_helper
  # 
  # @example System test
  #   assert_no_selector css_query(:trans_new, :is_orig_radio, model: Prefecture)
  def css_query(key1, key2=nil, model: nil)
    query = CSSQUERIES[key1]
    query = query[key2] if key2.present?
    query = sprintf(query, get_modelname(model)) if model  # defined in application_helper.rb
    raise "no query for [key1, key2]=#{[key1, key2].inspect}" if !query
    query
  end 

  # @example
  #   assert_match(/ prohibited /, page_find_sys(:error_div, :title).text)  # defined in helpers/test_system_helper
  #   page_find_sys(:trans_new, :langcode_radio, model: MyModel).choose('English')  # defined in helpers/test_system_helper
  #    Old forms: page.find('form div.field.radio_langcode').choose('English')
  #   page_find_sys(:trans_new, :is_orig_radio, model: @channel_type).choose('No')  # defined in helpers/test_system_helper
  # 
  def page_find_sys(*args, **kwds)
    page.find(css_query(*args, **kwds))
  end 

  # Gets a field value, like a radio-button etc.
  #
  # @example Get a value for radio-buttons for "is_orig" in Page "new" for MyModel (e.g., ChannelType)
  #   assert_equal "on",   page_get_val(:trans_new, :is_orig, model: "my_model"), "is_orig should be Undefined, but..."  # defined in helpers/test_system_helper
  #   assert_equal "true", page_get_val(:trans_new, :is_orig, model:  my_model),  "is_orig should be true, but..."
  #
  # @example
  #   assert_equal "en",   page_get_val(:trans_new, :langcode, model: MyModel), "Language should be set English, but..."
  #
  def page_get_val(key1, key2=nil, model: nil)
    if "trans_new" == key1.to_s
      case key2.to_s
      when "langcode", "is_orig"
        page.find_field(name: get_modelname(model)+"[#{ApplicationController::PARAMS_NAMES[:trans][key2]}]", checked: true)["value"]  # defined in application_helper.rb
        # e.g., page.find_field(name: "channel_type[best_translation_is_orig]", checked: true)["value"]
      else
        raise "Unsupported, yet..."
      end
    else
        raise "Unsupported, yet..."
    end
  end 

end
