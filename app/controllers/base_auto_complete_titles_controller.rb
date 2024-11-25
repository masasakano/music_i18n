# coding: utf-8

# JSON-only controller to return titles of candidate Artists/Musics (or maybe else)
# This can be called by public (not limited to authenticated users)
#
# Each subclass Controller must define constant MODEL_SYM like :music
class BaseAutoCompleteTitlesController < ApplicationController
  include AutoCompleteIndex  # defined in /app/controllers/concerns/auto_complete_index.rb

  # Maximum number of candidates.
  MAX_SUGGESTIONS = 30

  # @see  /app/javascript/autocomplete_model_with_id.js
  # @param model [Class, BaseWithTranslation, String, Symbol] of Artist or Music to autocomplete
  # @return [String] returns the basename (i.e., params key) of a form ID (for <input>) from a model.
  def self.formid_autocomplete_with_id(model)
    helpers.get_modelname(model)+'_with_id' # defined in application_helper.rb
  end

  # The caller's path must be somethings/ (i.e., index).
  # See {#requested_from_permitted_path?} below.
  def index
    index_auto_complete(requested_from_permitted_path?, self.class::MODEL_SYM, do_display_id: false)
  end

  private
    # @rerutn [Boolean] rejects requests if requested from a different page or site from the intended.
    def requested_from_permitted_path?
      path_modified = params[:path].sub(%r@^(/?[a-z]{2}/)?@, "")  # to remove the locale part; I am not sure if this is necessary in reality (but just to play safe).
      fragment = nil
      if ("static_page_publics" != Rails.application.routes.recognize_path(path_modified)[:controller])
        Rails.application.eager_load!
        fragment = (BaseWithTranslation.descendants.map{|ek| ek.name.underscore.pluralize}+%w(engages)).join("|")  # /engages is allowed although it is not BaseWithTranslation.
        return true if %r@/(#{fragment})/?\z@ =~ params[:path]  # This handles even paths like /children or /novae etc.
      end

      logger.warn "Rejects AJAX (or HTTP) request to #{__FILE__} from #{params[:path]} / controller=#{Rails.application.routes.recognize_path(path_modified)[:controller].inspect} / fragment=#{fragment.inspect}"
      false
    end

end
