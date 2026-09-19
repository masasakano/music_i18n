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
    # Defines 8 instance methods including "*_found?" and "*_created?"
    #
    # Basically this method defines setters and getters (writers and readers) and
    # related utitlity methods for the given parameter, as well as setting the default 8 methods like `was_found?`.
    # Although 8 methods are defined, you should use only 4 of them, as follows
    #
    # The purpose is that if you use the dedicated setter of
    # +set_was_found_if_true{false}+ (or +set_was_found_if_true(false)+),
    # "was_found?" and "was_created?" return +false+ and +true+, respectively,
    # namely always the opposite Boolean values so that the developers can
    # write readable code.  In other words, this Module provides a set of
    # human-readable instance methods.
    #
    # == Four recommended methods:
    #
    # * "*_found?"    # (getter)
    # * "*_created?"  # (getter)
    # * "set_*_found_if_true(Treated_as_Boolean=nil){ optional_block }" # (setting both *_found and *_created)
    # * "reset_*_found_created"  # (resets both instance variables)
    #
    # == All 8 methods for the sake of completeness, though 4 of them are obsolete:
    #
    # * "*_found(=|?)"  (setter & getter)  # Use Getter, but do NOT use this setter method, for it beats the point of this Module!
    # * "*_created(=|?)"                   # Do NOT use this setter method.
    # * "set_*_(found|created)_true"  (Synonym of self.*_**=true) # Do NOT use these setter methods!! Left due to historic reason.
    # * "set_*_found_if_true(either_arg){ or_block }"  (setting both *_found and *_created)  # Recommended Setter
    # * "reset_*_found_created"  (resets both instances)
    #
    # Although you can set them manually, any inconsistency setting would raise
    # {HaramiMusicI18n::ModuleWasFounds::InconsistencyInWasFoundError}
    #
    # == Detail
    #
    # Suppose
    #
    #   define_was_found_for("group")
    #
    # has been called.  Internally, this set 2 instance variables of 
    # `@group_found` and `@group_created`.
    #
    # 1. if "@group_found" is falsy AND
    # 2. if "@group_created" is truthy,
    # 3. "group_found?" returns false and "group_created?" returns true;
    #    or if it is the reverse, they return the reverse;
    #    or if neither is the case (i.e., both are falthy or both are truthy),
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
    # @example  Just to show an errorneous way
    #    def raise_always_warning
    #      begin
    #        was_found? rescue was_created?
    #      rescue HaramiMusicI18n::ModuleWasFounds::InconsistencyInWasFoundError => er
    #        warn "You must set either of them truthy or falthy."
    #      end
    #    end
    #
    # @example  How to use the methods (for the default +was_found?+)
    #    def an_example_use(any_object)
    #      set_was_found_if_true(false)
    #      was_found?    # => false
    #      was_created?  # => true
    #      reset_*_found_created"  # (resets both instance variables)
    #      set_was_found_if_true{ any_object }
    #      was_found?    # => Boolean: !!any_object 
    #      was_created?  # => Boolean:  !any_object 
    #
    # @example  A tip to use set_was_found_true
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
