class StaticPagePublicsController < ApplicationController

  skip_before_action :authenticate_user!, :only => [:show]
  load_and_authorize_resource :static_page, :only => [:index]  # authorization based on StaticPage

  def index
    @static_pages = StaticPage.order(:mname, :langcode)
  end

  def show
    @static_page = StaticPage.find_by_mname(params[:path], locale=I18n.locale)
    raise ActionController::RoutingError, "Page not found." if !@static_page
  end
end

