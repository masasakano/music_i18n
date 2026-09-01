# -*- coding: utf-8 -*-

# Common module for the main routine of index in Controllers for auto-complete
#
# @example for publicly-available auto-complete
#   include AutoCompleteIndex
#   def index
#     permitted = requested_from_permitted_path?(allow_index_page: true, orgfilename: __FILE__)  # defined in /app/controllers/concerns/auto_complete_index.rb
#     index_auto_complete(permitted, self.class::MODEL_SYM, do_display_id: false)
#   end
#
module AutoCompleteIndex
  #def self.included(base)
  #  base.extend(ClassMethods)
  #end
  extend ActiveSupport::Concern  # In Rails, the 3 lines above can be replaced with this.

  # List of Regexp-Quoted path *tail* parts that are accepted for Editors to send auto-complete AJAX requests.
  #
  # @note The last one excludes paths like /children/123 or /novae/123 etc.
  QUOTED_ALLOWED_EDITOR_PATH_FRAGMENTS = [
    Regexp.quote("/new"),
    Regexp.quote("/engages"),
    Regexp.quote("/edit")+"(/\d+)?",
    "(?:^|/)"+Regexp.quote("harami_vids/fetch_youtube_data"),
    "(?:^|/)[^/]+s/\d+"
  ]

  #module ClassMethods
  #end # module ClassMethods

  # See the commentat for the Module at the top for detail
  #
  # @param permitted [Boolean] 
  # @param klass [ApplicationRecord, Symbol] If symbol, it is singular
  # @param klass_id: [Integer, NilClass] pID of klass, if any. If specified, the record is excluded from the returned candidates.
  # @param do_display_id: [Boolean] If true, " (en) [ID=123]" is appended (displayed) in each of the element in the returned Array
  # @param kwd: [String] Keyword to auto-complete
  # @param path: [String] Used for the errorneous return message.
  # @return [void]
  def index_auto_complete(permitted, klass, klass_id: nil, do_display_id: false, kwd: params[:keyword], path: params[:path])
    if !permitted
      return respond_to do |format|
        format.html { }
        format.json { render json: {error: "Forbidden request #{path.inspect}" }, status: :unprocessable_content }
      end
    end

    klass = (klass.respond_to?(:where) ? klas : self.class::MODEL_SYM.to_s.classify.constantize)
    model = (klass_id ? klass.find(klass_id) : klass.new)
    # candidates = model.select_titles_partial_str_except_self(:titles, kwd, display_id: do_display_id)
    candidates = model.candidate_titles_from_partial_str_except_self(kwd, display_id: do_display_id)

    respond_to do |format|
      format.html { }
      format.json { render json: candidates[0..self.class::MAX_SUGGESTIONS], status: :ok }
    end
  end

  # @rerutn [Boolean] return falthy if auto-complete is requested from a different page or site from the intended.
  def requested_from_permitted_path?(allow_index_page: false, orgfilename: "Caller")
    is_authenticated = current_user && current_user.roles.exists?  # true if logged in and have a Role

    path_modified = (URI.parse(params[:path]).path rescue params[:path]&.split('?')&.first).sub(%r@^((/?)[a-z]{2}/)?@, '\2')  # to remove the query parameters and also the locale part (NOTE: the latter may not be necessary)
    path_modified = path_modified.sub(%r@(/edit)(/\d+)?\z@, '\1') if is_authenticated

    fragments = []
    if ("static_page_publics" != Rails.application.routes.recognize_path(path_modified)[:controller])
      if allow_index_page
        Rails.application.eager_load!
        fragments.push (BaseWithTranslation.descendants.map{|ek| ek.name.underscore.pluralize}+%w(engages)).join("|")  # /engages is allowed although it is not BaseWithTranslation.
        return true if %r@(?:^|/)(#{fragments.first})/?\z@ =~ params[:path]  # Any plural path like /children or /novae etc is accepted.
      end

      if is_authenticated
        # True if called from new/edit (etc) AND show that are valid in this app.
        # "show" is necessary because once edit has failed, it returns to a "show" page!

        fragments.push QUOTED_ALLOWED_EDITOR_PATH_FRAGMENTS.join("|")
        ### return true if %r@/(new|edit(/\d+)?|[^/]+s/\d+)\z@ =~ params[:path]  # This actually excludes paths like /children/123 or /novae/123 etc.
        return true if /(#{fragments.last})\z/ =~ path_modified
      end
    end

    controller = (Rails.application.routes.recognize_path(path_modified)[:controller].inspect rescue "Unknown")
    logger.warn "Rejects AJAX (or HTTP) request to #{orgfilename} from #{params[:path]} / controller=#{controller} / fragment=#{fragments.inspect}"
    false
  end

end

