module Prefectures
  class PlacesController < ApplicationController
    def index
      # In addition, params of :select_name, :selected, :required are directly handled in the ERB teplate: /app/views/prefectures/places/index.html.erb

      selected_prefecture = params[:prefecture_id].presence && Prefecture.find(params[:prefecture_id])
      @places      = selected_prefecture&.places || Place.all
      @selected_id = selected_prefecture && selected_prefecture.unknown_place.id

      render layout: false
    end
  end
end
