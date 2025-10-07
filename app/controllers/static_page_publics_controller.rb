class StaticPagePublicsController < ApplicationController

  skip_before_action :authenticate_user!, :only => [:show]
  load_and_authorize_resource :static_page, :only => [:index]  # authorization based on StaticPage

  # @note
  #  This is called from recognize_path_with_static_page in test/test_helper.rb
  #
  # @param path [String]
  # @return [StaticPage]
  # @raise [ActionController::RoutingError]
  def self.static_page_from_path(path, locale=I18n.locale)
    StaticPage.find_by_mname(path, locale) || raise(ActionController::RoutingError, "Page not found.")
  end

  def index
    @static_pages = StaticPage.order(:mname, :langcode)
  end

  def show
    @static_page = self.class.static_page_from_path(params[:path], locale=I18n.locale)
  end
end

