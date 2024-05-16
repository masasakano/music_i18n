# coding: utf-8
class HaramiVidMusicAssocsController < ApplicationController
  load_and_authorize_resource

  # DELETE /harami_vid_music_assocs/1
  # DELETE /harami_vid_music_assocs/1.json
  def destroy
    @harami_vid_music_assoc.destroy
    respond_to do |format|
      format.html { redirect_back fallback_location: root_path, notice: I18n.t('harami_vid_music_assocs.destroy_success') }
      format.json { head :no_content }
    end
  end

  private
end
