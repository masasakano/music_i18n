# -*- coding: utf-8 -*-

# Common module to implement the class method :html_head_title
#
# The method is referred to from {ApplicationHelper#_title_from_path}
#
# @example
#   include ModuleHtmlHeadTitle  # implements the class method :html_head_title
#
# == NOTE
#
module ModuleHtmlHeadTitle
  extend ActiveSupport::Concern

  module ClassMethods
    # Returns the String expression for the record specified in the form of
    # the given +hsroute+ (Result of Rails.application.routes.recognize_path)
    #
    # For +hsroute+, see {ApplicationHelper#get_html_head_title}
    # 
    # At the time of writing, "ID=789" is the only one implemented.
    #
    # @return [String] for the record according to the given +hsroute+ (Result of Rails.application.routes.recognize_path)
    def html_head_title(*args, &bloc)
      html_head_title_id_only(*args, &bloc)
    end

      # A pID String expression only.
      #
      # @param hsroute [Hash] Result of Rails.application.routes.recognize_path
      #   See {ApplicationHelper#get_html_head_title}
      def html_head_title_id_only(hsroute)
        sprintf "ID=%s", hsroute[:id].inspect
      end
      private :html_head_title_id_only
  end

end

