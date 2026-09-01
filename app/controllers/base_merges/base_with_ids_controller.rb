# coding: utf-8

# JSON-only controller to return candidate Artists/Musics (or maybe else)
#
# This Controller is basically for Editors only (including pID etc)
# See {BaseAutoCompleteTitlesController} for publicly-available auto-complete
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
  # See {BaseAutoCompleteTitlesController} for publicly-available auto-complete
  def index
    permitted = id_cur = get_id  # NOTE: if id_cur is an Integer, the path is definitely a valid path, so permitted is truthy.
    permitted ||= requested_from_permitted_path?(allow_index_page: false, orgfilename: __FILE__)  # defined in /app/controllers/concerns/auto_complete_index.rb

    index_auto_complete(permitted, self.class::MODEL_SYM, klass_id: id_cur, do_display_id: true)
  end

  private

    # Returns the ID for "merge".
    #
    # @rerutn [Integer, Boolean]
    def get_id
      mat = %r@\b#{self.class::MODEL_SYM}s/(\d+)/merges\b@.match(params[:path])
      mat ? mat[1].to_i : nil
    end

end
