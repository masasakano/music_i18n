# -*- coding: utf-8 -*-

# Common helper module for Redcarpet (for handling markdown)
#
# == USAGE
#
# class SomeController  # for Controllers for traditional full-loading
#   include ModuleRedcarpetAux
#
#   MDRENDERER.render(my_markdown_text) 
#
module ModuleRedcarpetAux
  extend ActiveSupport::Concern
  extend ApplicationHelper  # for sanitized_html

  MD_EXTENSIONS = {
    no_intra_emphasis: true,
    tables: true,
    fenced_code_blocks: true,
    autolink: true,
    strikethrough: true,
    space_after_headers: true,
    superscript: true,
  }

  renderer = Redcarpet::Render::HTML.new(prettify: true)
  MDRENDERER = Redcarpet::Markdown.new(renderer, MD_EXTENSIONS)

  # Usage:
  #   ModuleRedcarpetAux.md2safehtml(place.note)
  #
  # @param instr [String, NilClass]
  # @return [String] Sanitized and html_safe String (never nil)
  def self.md2safehtml(instr=nil)
    sanitized_html(MDRENDERER.render(instr || "")).html_safe  # sanitized_html defined in ApplicationHelper 
  end
end

