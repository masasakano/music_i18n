module Countries
  class PrefecturesController < ApplicationController
    def index
      # In addition, params of :select_name, :selected, :required are directly handled in the ERB teplate: /app/views/countries/prefectures/index.html.erb

      selected_country = params[:country_id].presence && Country.find(params[:country_id])
      @prefectures = selected_country&.prefectures || Prefecture.all
      @selected_id = selected_country && selected_country.unknown_prefecture.id

      render layout: false
    end
  end
end
