# coding: utf-8
class ArtistMusicPlaysController < ApplicationController
  load_and_authorize_resource

  # DELETE /artist_music_plays/1
  # DELETE /artist_music_plays/1.json
  def destroy
    @artist_music_play.destroy
    respond_to do |format|
      format.html { redirect_back fallback_location: root_path, notice: I18n.t('artist_music_plays.destroy_success') }
      format.json { head :no_content }
    end
  end

  private
end
