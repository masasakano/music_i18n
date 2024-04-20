# coding: utf-8
require "test_helper"

class ActiveSupport::TestCase

  # @note The definition name should not begin with "test_" because otherwise the definition
  #       would be actually run in every testing, maybe scores of times in total!
  #
  # @example
  #   run_test_create_null(ChannelOwner)
  #
  # @param klass [ApplicationRecord, String] of the model to test like ChannelOwner
  def run_test_create_null(klass, col_name: :note)
    bind = caller_locations(1,1)[0]  # Ruby 2.0+
    caller_info = sprintf "%s:%d", bind.absolute_path.sub(%r@.*(/test/)@, '\1'), bind.lineno
    # NOTE: bind.label returns "block in <class:TranslationIntegrationTest>"

    camel_str = (klass.respond_to?(:name) ? klass.name : klass.to_s.camelize)
    snake_str = camel_str.underscore

    if klass.respond_to?(:name) && !klass.column_names.include?(col_name.to_s)
      raise "FATAL: Specified class #{klass.name} does not have the column '#{col_name}' strangely. Contact the code developper (#{__FILE__}:#{__method__} called from #{caller_info})."
    end

    assert_no_difference(camel_str+".count") do
      post send(snake_str.pluralize+"_url"), params: { snake_str => { col_name => "" }}
      # assert flash[:alert].present?, "Did not fail with Flash-alert for a null create."  # flash does not work well for some reason in this helper thought it would work if directly included in a Controller test.
    end
    assert_response :unprocessable_entity
    assert_includes css_select('.alert-danger h2').text, "prohibited"
    css1 = ".alert-danger #error_explanation_list"
    assert_select css1, {count: 1}, "Text: #{css_select(css1).to_s}"
    assert_operator 1, :<=, css_select(css1+" li").size, "At least one error should be reported."
    # print "DEBUG(#{__FILE__}):response: "; puts @response.body
  end

end

