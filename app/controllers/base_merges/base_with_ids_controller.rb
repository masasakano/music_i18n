# coding: utf-8

# JSON-only controller to return candidate Artists/Musics (or maybe else)
class BaseMerges::BaseWithIdsController < ApplicationController
  authorize_resource :class => false
  #skip_before_action :authenticate_user!, :only => [:index]  # action defined in application_controller.rb
  skip_authorize_resource
  #skip_authorization_check

  # Maximum number of candidates.
  MAX_SUGGESTIONS = 15

  # The caller's path must be either */%/merges or something/(new|edit).
  # See {#get_id} below.
  def index
    idcur = get_id
    if !idcur
      return respond_to do |format|
        format.html { }
        format.json { render json: {error: "Forbidden request to #{params[:path].inspect}" }, status: :unprocessable_entity }
      end
    end

    model_klass = self.class::MODEL_SYM.to_s.classify.constantize
    model = (idcur.respond_to?(:divmod) ? model_klass.find(idcur) : model_klass.new)
    candidates = model.select_titles_partial_str_except_self(:titles, params[:keyword], display_id: true)

    respond_to do |format|
      format.html { }
      format.json { render json: candidates[0..MAX_SUGGESTIONS], status: :ok }
    end
  end

  private
    # @rerutn [Integer, NilClass] rejects requests from a different page or site.
    def get_id
      # hs = Rails.application.routes.recognize_path params[:path], method: :get  # this works in Console, but does not work in test...
      # => {:controller=>"musics/merges", :action=>"new", :id=>"8", :locate=>"en"}
#logger.debug "DEBUG(#{__FILE__}): recognize_path(#{params[:path]})="+hs.inspect
      # baseroot = File.dirname(__FILE__).sub(%r@\A.+\bapp/controllers/@, "") # => "/en/musics/21923907/merges/new"
      # dirs = hs[:controller].split("/")  # "musics/merges"
      # if /\A#{Regexp.quote(dirs[0])}/ =~ baseroot && baseroot.include?(dirs[1])
      #   (%w(new edit).include? hs[:action])
      #   hs[:id].to_i
      mat = %r@\b#{self.class::MODEL_SYM}s/(\d+)/merges\b@.match(params[:path])
      return mat[1].to_i if mat

      # If called from other new/edit that are valid in this app.
      path_modified =params[:path].sub(%r@^(/?[a-z]{2}/)?@, "").sub(%r@(/edit)(/\d+)?\z@, '\1')  # I am not sure if this is necessary in reality (but just to play safe).
      if ("static_page_publics" != Rails.application.routes.recognize_path(path_modified)[:controller]) &&
         %r@/(new|edit(/\d+)?)\z@ =~ params[:path]
        return true   # anything but nil or Integer
      else
        logger.warn "Rejects AJAX (or HTTP) request to #{__FILE__} from #{params[:path]}"
        nil
      end
    end

end
