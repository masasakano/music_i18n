# coding: utf-8

# JSON-only controller to return titles of candidate Artists/Musics (or maybe else)
# This can be called by public (not limited to authenticated users)
#
# Each subclass Controller must define constant MODEL_SYM like :music
#
# @see BaseMerges::BaseWithIdsController
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
  # See {BaseMerges::BaseWithIdsController} for auto-complete for authorized users
  def index
    permitted = requested_from_permitted_path?(allow_index_page: true, orgfilename: __FILE__)  # defined in /app/controllers/concerns/auto_complete_index.rb
    index_auto_complete(permitted, self.class::MODEL_SYM, do_display_id: false)
  end

end
