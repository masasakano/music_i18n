# -*- coding: utf-8 -*-

# Common module to implement memo_editor attribute
#
# include this module when the memo_editor attribute is added to a Model
#
# == Standard procedure
#
# 1. DB Migration
#
#      % bin/rails generate migration AddMemoEditorToEvents memo_editor:text
#
#    Maybe edit the migration file. Perhaps add a DB "comment"?  Not much else to do!
#    Indexing is probably not needed.
#
#      % bin/rails db:migrate:status
#      % bin/rails db:migrate
# 2. Update the Controller.
#    See the example below.
# 3. Update View/Show, using the layout _show_note_memo_timestamps.html.erb
#    * Basically, you replace the existing part between Note and Timestamps.
# 4. Update Form-related View (maybe _form.html.erb), using the layout _form_note_memo_editor.html.erb
#    * Basically, you replace the existing part for Note.
# 5. (Optionally) Update Grid for index-view; basically you should add the model class like
#    columns_upd_created_at(Event) and that shoul suffice because filtering is automatically
#    taken care of by Grid itself.
#
# @example Controller
#   include ModuleMemoEditor   # for memo_editor attribute
#   MAIN_FORM_KEYS ||= []
#   MAIN_FORM_KEYS.concat(%w(duration_hour weight note) + ["start_time(1i)", "start_time(2i)", "start_time(3i)"])
#
# == NOTE
#
module ModuleMemoEditor
  include ModuleRedcarpetAux

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
