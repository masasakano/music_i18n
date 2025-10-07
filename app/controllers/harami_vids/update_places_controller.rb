# coding: utf-8
class HaramiVids::UpdatePlacesController < ApplicationController
  include HaramiVids::UpdatePlacesHelper

  before_action :set_hvid

  # GET /harami_vids/update_places/1 or /harami_vids/update_places/1.json
  def show
    auth_for!(__method__)
  end

  # PATCH/PUT /harami_vids/update_places/1 or /harami_vids/update_places/1.json
  def update
    auth_for!(__method__)

    pla2upd = get_evit_place_if_need_updating(@harami_vid) # defined in /app/helpers/harami_vids/update_places_helper.rb

    respond_to do |format|
      if pla2upd && @harami_vid.update(place: pla2upd)
        msg = "Place is successfully updated."
        format.html { redirect_to harami_vids_update_place_url(@harami_vid), notice: msg }
        format.json { render :show, status: :ok, location: @harami_vid }
      else
        @harami_vid.errors.add :base, "Place is NOT updated." if !pla2upd
        @harami_vid.errors.add :base, flash[:alert] if flash[:alert].present? # alert is, if present, included in the instance
        hsflash = {}
        %i(warning notice).each do |ek|
          hsflash[ek] = flash[ek] if flash[ek].present?
        end
        opts = get_html_safe_flash_hash(alert: @harami_vid.errors.full_messages, **hsflash)
        hsstatus = {status: :unprocessable_content}.merge(opts)
        format.html { render :show, **hsstatus } # notice (and/or warning) is, if any, passed as an option.  # NOTE: this is usually :edit, but only in this case this is :show (!)
        #format.html { render :edit, **(opts) } # notice (and/or warning) is, if any, passed as an option.
        format.json { render json: @harami_vid.errors, **hsstatus }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_hvid
      @harami_vid = HaramiVid.find(params[:id])
    end

    # Common authorize
    def auth_for!(method)
      authorize! method, @harami_vid  # Authorizes according to the same-name method for HaramiVid
    end

end
