# -*- coding: utf-8 -*-
# require "unicode/emoji"

# Common module for Event and EventItem models (and controllers)
#
# @example
#   include ModuleEventAux
#
# == NOTE
#
module ModuleEventAux
  #def self.included(base)
  #  base.extend(ClassMethods)
  #end
  extend ActiveSupport::Concern  # In Rails, the 3 lines above can be replaced with this.

  extend ModuleApplicationBase

  module ClassMethods
    # @note This assumes any of DEF_EVENT_TITLE_FORMATS and  DEF_STREAMING_EVENT_TITLE_FORMATS
    #   of Event are identical for the elements 1 and 2 (but NOT 0).
    #
    # @param lcode [String] langcode
    # @param event_group [EventGroup]
    # @param prefer_en: [Boolean] if True (Def: false), English is used for postfix regardless of lcode
    # @return [String]
    def def_event_title_postfix(lcode, event_group, prefer_en: false)
      tit_evgr = event_group.title_or_alt(langcode: (prefer_en ? "en" : lcode), lang_fallback_option: :either, str_fallback: "")
      fmts = Event::DEF_STREAMING_EVENT_TITLE_FORMATS.first.last
      sprintf fmts[1..2].join(""), tit_evgr
    end

    # @param lcode [String] langcode
    # @param event_group [EventGroup]
    # @return [String]
    def def_event_item_machine_title_postfix(lcode, event_group)
      def_event_title_postfix(lcode, event_group, prefer_en: true).gsub(/[[:space:]]+/, "_")
    end

    # Unsaved Default Translation for an Event for the given langcode (locale)
    #
    # @param prefix [String] Unique part for the default title
    # @param lcode [String] langcode
    # @param event_group [EventGroup]
    # @param weight: [Float, NilClass] for Translation to return
    # @param prefer_en: [Boolean] if True (Def: false), English is used for postfix regardless of lcode
    # @return [String]
    def def_event_tra_new(prefix, lcode, event_group, weight: Float::INFINITY, prefer_en: false)
      postfix = def_event_title_postfix(lcode, event_group, prefer_en: prefer_en)
      title = get_unique_string("translations.title", rela: self.joins(:translations), prefix: prefix, postfix: postfix, separator: "-", separator2:"")  # defined in module_application_base.rb
      Translation.new(langcode: lcode, title: title, weight: weight)
    end
  end

  #################
  private 
  #################

end
