# -*- coding: utf-8 -*-

# Common module to implement memo_editor attribute
#
# @example
#   include ModuleMemoEditor   # for memo_editor attribute
#   MAIN_FORM_KEYS ||= []
#   MAIN_FORM_KEYS.concat(%w(duration_hour weight note) + ["start_time(1i)", "start_time(2i)", "start_time(3i)"])
#
# == NOTE
#
module ModuleMemoEditor
  def self.included(base)
    if base.const_defined?(:MAIN_FORM_KEYS)
      base.const_get(:MAIN_FORM_KEYS).push "memo_editor"
    else
      base.const_set(:MAIN_FORM_KEYS, %w[memo_editor])
    end
    # base.extend(ClassMethods)
  end
  #extend ActiveSupport::Concern  # to activate class methods

  #include ApplicationHelper

  #module ClassMethods
  #end


  #################
  private 
  #################


end
