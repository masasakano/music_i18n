class HomeController < ApplicationController
  skip_before_action :authenticate_user!, :only => [:index]

  def index
    @message = ''
    @home_hvs = HaramiVid.order(release_date: :desc)[0..19]  # The latest 20 Videos
  end
end
