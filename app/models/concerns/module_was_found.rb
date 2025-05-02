# -*- coding: utf-8 -*-

# Module to implement methods, primarily {#was_found?} and {#was_created?}
#
# == Description
#
# Class method +define_was_found_for(keyword)+ is also defined, with which
# +keyword_was_found?+ etc are defined.
#
# @example
#   include ModuleWasFound
#
module ModuleWasFound
  #def self.included(base)
  #  base.extend(ClassMethods)
  #end
  extend ActiveSupport::Concern  # In Rails, the 3 lines above can be replaced with this.

  # extend ModuleApplicationBase
  # extend ModuleCommon

  module ClassMethods
    #
    # Defines 8 instance methods including "*_found(=|?)" and "*_created(=|?)"
    #
    # Basically defines writers and readers (with a postfix of a question mark) and related utitlity methods.
    # Eight methods:
    #
    # * "*_found(=|?)"  (writer & reader)
    # * "*_created(=|?)"
    # * "set_*_(found|created)_true"  (Synonym of self.*_**=true)
    # * "set_*_found_if_true(either_arg){ or_block }"  (setting both *_found and *_created)
    # * "reset_*_found_created"  (resets both instances)
    #
    # Suppose "*" is "group".  Then,
    #
    # 1. if "@group_found" is falsy AND
    # 2. if "@group_created" is truthy,
    # 3. "group_found?" returns false and "group_created?" returns true,
    #    or if it is the reverse, they return the reverse,
    #    or if neither is the case (i.e., both are falthy are both are truthy),
    #    this raises HaramiMusicI18n::ModuleWasFounds::InconsistencyInWasFoundError
    #
    # In other words, you MUST set either of them truthy to get either true/false
    # from either of +group_found?/created?+, avoiding an Exception.
    # This is because otherwise, chances are neither of them may have never been set.
    #
    # @example  How to include
    #    class Article < ApplicationRecord
    #      include ModuleWasFound  # define attr_writers @was_found, @was_created and their questioned-readers.
    #      define_was_found_for("group")  # defined in ModuleWasFound; define #group_found, #group_found? etc
    #
    # @example  How to use the methods (for the default +was_found?+)
    #    def abc(x)
    #      self.was_found   = nil
    #      self.was_created = false
    #      begin
    #        was_found? rescue was_created?
    #      rescue HaramiMusicI18n::ModuleWasFounds::InconsistencyInWasFoundError => er
    #        warn "You must set either of them truethy."
    #      end
    #      self.was_created = true
    #      was_found?    # => false
    #      was_created?  # => true
    #
    # @example  A tip to use set_group_found_true
    #    existing_or_nil = MyClass.find_by(some: 5)&.tap(&:set_was_found_true)
    #
    def define_was_found_for(was)
      %w(found created).each do |metho|
        attr_writer [was, metho].join("_").to_sym    # In find_or_create, if an instance is found, this is set.

        # defines methods of set_*_(found|created)_true
        define_method sprintf("set_%s_%s_true", was, metho).to_sym do
          instance_variable_set(sprintf("@%s_%s", was, metho).to_sym, true)
        end
      end 

      # defines method set_*_found_if_true()
      #
      # If the given block's return (high priority) or status as the argument is true,
      # "*_found" was set true, and if not "*_created" was set true.
      #
      # NOTE: set_*_created_if_true() is NOT defined.
      define_method(("set_"+was+"_found_if_true").to_sym) do |status=:never_case9, &bloc|
        found_true = (bloc ? bloc.call : status)
        raise ArgumentError, "must specify status or block" if :never_case9 == found_true
        instance_variable_set(sprintf("@%s_found",   was).to_sym,  found_true)
        instance_variable_set(sprintf("@%s_created", was).to_sym, !found_true)
      end

      # defines method reset_*_found_created to reset both
      define_method(("reset_"+was+"_found_created").to_sym) do
        instance_variable_set(sprintf("@%s_found",   was).to_sym, nil)
        instance_variable_set(sprintf("@%s_created", was).to_sym, nil)
      end

      # defines method *_found?
      define_method (was+"_found?").to_sym do
        it_found   = instance_variable_get(("@"+was+"_found").to_sym)
        it_created = instance_variable_get(("@"+was+"_created").to_sym)
        if     it_found && !it_created
          true
        elsif !it_found &&  it_created
          false
        else
          raise HaramiMusicI18n::ModuleWasFounds::InconsistencyInWasFoundError, "(internal) #{was}_found/#{was}_created are either inconsistent or not set (found/created=(#{it_found.inspect}/#{it_created.inspect})). Contact the code developer. self="+inspect
        end
      end

      # defines method *_created?
      define_method (was+"_created?").to_sym do
        !send(was+"_found?")
      end
    end
  end  # module ClassMethods


  extend ClassMethods

  ## instance methods "was_found?". "was_created?" and their respective writers are included (=defined) in default.
  define_was_found_for("was")

  #################
  private 
  #################

end
