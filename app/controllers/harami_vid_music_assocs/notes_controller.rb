# coding: utf-8
class HaramiVidMusicAssocs::NotesController < ApplicationController
  include ApplicationHelper # for hms2sec()

  before_action :set_hvma

  # ID for the field
  FORM_NOTE = HaramiVidMusicAssoc::FORM_NOTE

  # GET /harami_vid_music_assocs/notes/1 or /harami_vid_music_assocs/notes/1.json
  def show
    auth_for!(__method__)
  end

  # GET /harami_vid_music_assocs/notes/1/edit
  def edit
    auth_for!(__method__)
    @hvma.form_note ||= @hvma.note
  end

  # PATCH/PUT /harami_vid_music_assocs/notes/1 or /harami_vid_music_assocs/notes/1.json
  def update
    auth_for!(__method__)

    @hvma.note = @hvma.form_note = set_params[FORM_NOTE]
    respond_to do |format|
      if @hvma.save
        msg = "Note is successfully updated."
        format.html { redirect_to harami_vid_music_assocs_note_path(@hvma), notice: msg }
        format.json { render :show, status: :ok, location: @hvma }
      else
        @hvma.errors.add :base, flash[:alert] if flash[:alert].present? # alert is, if present, included in the instance
        hsflash = {}
        %i(warning notice).each do |ek|
          hsflash[ek] = flash[ek] if flash[ek].present?
        end
        opts = get_html_safe_flash_hash(alert: @hvma.errors.full_messages, **hsflash)
        hsstatus = {status: :unprocessable_content}
        # Since this is "recirect_to", everything must be passed as flash (not in the form of @record.errors)
        #format.html { render template: "harami_vids/show", **(opts) } # notice (and/or warning) is, if any, passed as an option.
        format.html { render :edit, **(opts) } # notice (and/or warning) is, if any, passed as an option.
        format.json { render json: @hvma.errors, **hsstatus }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_hvma
      @hvma = HaramiVidMusicAssoc.find(params[:id])
    end

    # Common authorize
    def auth_for!(method)
      authorize! method, @hvma.harami_vid  # Authorize according to the same-name method for HaramiVid
    end

    # 
    def set_params
      params.permit(FORM_NOTE)
    end

end
