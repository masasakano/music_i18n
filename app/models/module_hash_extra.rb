# -*- coding: utf-8 -*-

# Utility module to add a few methods in Hash
#
# Use this with "using".
#
# @example
#   class Translation < ApplicationRecord
#     using ModuleHashExtra
#   end
#
# @example
#   hs = {:a => " \n ", 'b' => 'abc', :c => nil, :d => '', :e => 5}
#   hs.strip_strings  # => {:a => "", 'b' => 'abc', :c => nil, :d => '', :e => 5}
#   hs.strip_strings.values_blank_to_nil  # => {:a => nil, 'b' => 'abc', :c => nil, :d => nil, :e => 5}
#   hs.strip_strings.values_blank_to_nil.compact  # => {'b' => 'abc', :e => 5}
#   hs.strip_strings.values_blank_to_nil.compact.keys_string_to_symbol  # => {:b => 'abc', :e => 5}
#
module ModuleHashExtra
  refine Hash do
    # Returns a Hash where String#strip is performed for all values of Hash
    #
    # @return [Hash]
    def strip_strings
      map{|k, v| [k, (v.respond_to?(:strip) ? v.strip : v)]}.to_h
    end
  
    # Returns a Hash where all blank values are converted into nil
    #
    # You can chain this to Hash#compact if you wish.
    #
    # @return [Hash]
    def values_blank_to_nil
      map{|k, v| [k, (v.blank? ? nil : v)]}.to_h
    end
  
    # Returns a Hash where all String keys are converted into Symbol
    #
    # @return [Hash]
    def with_sym_keys
      map{|k, v| [(k.respond_to?(:to_sym) ? k.to_sym : k), v]}.to_h
    end
  end
end

