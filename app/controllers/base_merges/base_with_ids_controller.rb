# coding: utf-8

# JSON-only controller to return candidate Artists/Musics (or maybe else)
class BaseMerges::BaseWithIdsController < ApplicationController
  include AutoCompleteIndex  # defined in /app/controllers/concerns/auto_complete_index.rb

  authorize_resource :class => false
  #skip_before_action :authenticate_user!, :only => [:index]  # action defined in application_controller.rb
  skip_authorize_resource
  #skip_authorization_check

  # Maximum number of candidates.
  MAX_SUGGESTIONS = 15

  # @see  /app/javascript/autocomplete_model_with_id.js
  # @param model [Class, BaseWithTranslation, String, Symbol] of Artist or Music to autocomplete
  # @return [String] returns the basename (i.e., params key) of a form ID (for <input>) from a model.
  def self.formid_autocomplete_with_id(model)
    helpers.get_modelname(model)+'_with_id' # defined in application_helper.rb
  end

  # The caller's path must be either */%/merges or something/(new|edit) or somethings/ (i.e., index).
  # See {#get_id} below.
  def index
    permitted = get_id
    id_cur = (permitted.respond_to?(:divmod) ? permitted : nil)
    index_auto_complete(permitted, self.class::MODEL_SYM, klass_id: id_cur, do_display_id: true)
  end

  private
    # @rerutn [Integer, NilClass] rejects requests from a different page or site.
    def get_id
      # hs = Rails.application.routes.recognize_path params[:path], method: :get  # this works in Console, but does not work in test...
      # => {:controller=>"musics/merges", :action=>"new", :id=>"8", :locate=>"en"}
      # baseroot = File.dirname(__FILE__).sub(%r@\A.+\bapp/controllers/@, "") # => "/en/musics/21923907/merges/new"
      # dirs = hs[:controller].split("/")  # "musics/merges"
      # if /\A#{Regexp.quote(dirs[0])}/ =~ baseroot && baseroot.include?(dirs[1])
      #   (%w(new edit).include? hs[:action])
      #   hs[:id].to_i
      mat = %r@\b#{self.class::MODEL_SYM}s/(\d+)/merges\b@.match(params[:path])
      return mat[1].to_i if mat

      # If called from other new/edit AND show that are valid in this app.
      # "show" is necessary because once edit has failed, it returns to a "show" page!
      # So, either index, new, show, or edit within the app page is allowed.
      path_modified =params[:path].sub(%r@^(/?[a-z]{2}/)?@, "").sub(%r@(/edit)(/\d+)?\z@, '\1')  # I am not sure if this is necessary in reality (but just to play safe).
      if ("static_page_publics" != Rails.application.routes.recognize_path(path_modified)[:controller]) &&
         %r@/(new|edit(/\d+)?|[^/]+s/\d+)\z@ =~ params[:path]  # This actually excludes paths like /children/123 or /novae/123 etc.
        return true   # anything but nil or Integer
      else
        logger.warn "Rejects AJAX (or HTTP) request to #{__FILE__} from #{params[:path]}"
        nil
      end
    end

end
