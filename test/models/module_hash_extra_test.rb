require 'test_helper'

class ModuleHashExtraTest < ActiveSupport::TestCase
  using ModuleHashExtra
  
  test "strip_strings etc" do
    hs = {:a => " \n ", 'b' => 'abc', :c => nil, :d => '', :e => 5}
    assert_equal({:a => "", 'b' => 'abc', :c => nil, :d => '', :e => 5}, hs.strip_strings)
    assert_equal({:a => nil, 'b' => 'abc', :c => nil, :d => nil, :e => 5}, hs.strip_strings.values_blank_to_nil)
    assert_equal({'b' => 'abc', :e => 5}, hs.strip_strings.values_blank_to_nil.compact)
    assert_equal({ :b => 'abc', :e => 5, 6=>7}, hs.merge({6=>7}).strip_strings.values_blank_to_nil.compact.with_sym_keys)
  end
end
