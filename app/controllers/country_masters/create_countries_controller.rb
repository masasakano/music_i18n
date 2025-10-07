# coding: utf-8

class CountryMasters::CreateCountriesController < ApplicationController
  before_action :set_country_master, only: [:update]

  # POST /country_masters/:id/create_countries
  def update
    authorize! :update, CountryMasters::CreateCountriesController

    country = @country_master.create_child_country(check_clobber: true)

    respond_to do |format|
      if country && !@country_master.errors.any?
        format.html { redirect_to country, notice: 'Country was successfully created.' }
        format.json { render :show, status: :created, location: @country }
      else
        format.html { redirect_to @country_master, alert: @country_master.errors.full_messages }
        #format.html { render "country_masters/show", status: :unprocessable_content, location: @country_master }
        format.json { render json: @country_master.errors, status: :unprocessable_content }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_country_master
      @country_master = CountryMaster.find(params[:id])
    end

end
