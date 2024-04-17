# -*- coding: utf-8 -*-

# Common module to introduce "whodunnit"
#
module ModuleWhodunnit
  #def self.included(base)
  #  base.extend(ClassMethods)
  #end
  extend ActiveSupport::Concern  # In Rails, the 3 lines above can be replaced with this.

  module ClassMethods
    # Skip {#set_create_user} and {#set_update_user} (before_create and before_save) callbacks if true.
    # This is set especially for processing from Harami1129, as the translations populated
    # from the table are NOT set by the signed-in user.
    attr_accessor :skip_set_user_callback
  end

  # Callback before_create
  #
  # Set create_user_id
  # Skipped if {Translation.skip_set_user_callback} is true.
  # non-nil weight is always set at create.
  def set_create_user
    #puts "DEBUG122(set_create_user): title=#{title} Translation.whodunnit=#{Translation.whodunnit.inspect} callback=#{self.class.skip_set_user_callback.inspect}" if ENV['TEST_STRICT']  ## NOTE: for model tests, current_user sometimes exists(!!), which should not be(!) and is Rails-7's bug.
    klass = self.class
    if klass.respond_to?(:skip_set_user_callback) && klass.skip_set_user_callback
      self.weight ||= (klass.const_defined?("DEF_WEIGHT") ? klass::DEF_WEIGHT : Float::INFINITY) if self.respond_to?(:weight) 
      return
    end
    self.create_user ||= ModuleWhodunnit.whodunnit
    self.weight ||= def_weight  # nil-weight -> Float::INFINITY if !Translation.whodunnit (i.e., current_user.nil?)
  end

  # Callback before_save
  #
  # Set update_user_id
  # Skipped if {Translation.skip_set_user_callback} is true.
  def set_update_user
    klass = self.class
    return if klass.respond_to?(:skip_set_user_callback) && klass.skip_set_user_callback
    self.update_user = ModuleWhodunnit.whodunnit if !update_user_id_changed?
  end
end


class << ModuleWhodunnit
  # Setter/getter of {ModuleWhodunnit.whodunnit}
  attr_accessor :whodunnit
end
