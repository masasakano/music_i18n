# coding: utf-8

class Musics::Merges::MusicWithIdsController < ApplicationController

  authorize_resource :class => false
  #skip_before_action :authenticate_user!, :only => [:index]  # action defined in application_controller.rb
  skip_authorize_resource
  #skip_authorization_check

  # Maximum number of candidates.
  MAX_SUGGESTIONS = 15

  def index
    idcur = get_id
    if !idcur
      return respond_to do |format|
        format.html { }
        format.json { render json: {error: "Forbidden request to #{params[:path].inspect}" }, status: :unprocessable_entity }
      end
    end

    candidates = Music.find(get_id).select_titles_partial_str_except_self(:titles, params[:keyword], display_id: true)

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
      mat = %r@\bmusics/(\d+)/merges\b@.match(params[:path])
      if mat
        mat[1].to_i
      else
        logger.warn "Rejects AJAX (or HTTP) request to #{__FILE__} from #{params[:path]}"
        nil
      end
    end

end
