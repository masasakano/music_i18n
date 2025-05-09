# coding: utf-8
class HaramiVids::AddMissingMusicToEvitsController < ApplicationController
  include HaramiVidsHelper # for set_event_event_items (common with HaramiVids::FetchYoutubeDataController) and collection_musics_with_evit
  include HaramiVids::AddMissingMusicToEvitsHelper # for 

  before_action :set_event_item

  def show
    @harami_vid.missing_music_ids = @harami_vid.missing_musics_from_amps
  end

  def update
    auth_for!(__method__)

    parent_mus_ids = @harami_vid.musics.ids.uniq

    flash[:warning] ||= []
    flash[:alert]   ||= []
    flash_msgs = {
      notice: [],
    }.with_indifferent_access

    def_artist =     Artist.default(:HaramiVid)
    def_inst   = Instrument.default(:HaramiVid)
    def_prole  =   PlayRole.default(:HaramiVid)

    if @music_ids.empty?
      flash[:warning] << "No Music is specified to associate."
    else
      @music_ids.each do |mus_id|
        if !Music.exists?(mus_id)
          logger.error "ERROR(#{File.basename __FILE__}:#{__method__}): Strangely, non-existent Music ID=#{(mus_id)} is specified."
          Music.find(mus_id)  # => ActiveRecord::RecordNotFound
          raise
        elsif !parent_mus_ids.include? mus_id
          logger.error "ERROR(#{File.basename __FILE__}:#{__method__}): Strangely, Music ID=#{(mus_id)} not in HaramiVidMusicAssoc is specified."
          raise
        end

        ActiveRecord::Base.transaction(requires_new: true) do
          amp = ArtistMusicPlay.find_or_initialize_by(
            event_item: @event_item,
            artist:     def_artist,
            music_id:   mus_id,
            instrument: def_inst,
            play_role:  def_prole,
          )
          if amp.id
            flash[:warning] << "Strangely Music (ID=#{mus_id}) is already assosiated."
            next
          end

          if amp.save
            flash_msgs[:notice] << "Successfully associated Music #{Music.find(mus_id).title_or_alt(lang_fallback_option: :either).inspect} (ID=#{mus_id})."
          else
            @harami_vid.errors.add :base, amp.errors.full_messages
            flash[:alert] << "Failed to associate Music #{Music.find(mus_id).title_or_alt(lang_fallback_option: :either).inspect} (ID=#{mus_id})."
            raise ActiveRecord::Rollback, "Force rollback."  # no need, but playing safe
          end
        end
      end
    end

    respond_to do |format|
      if !@harami_vid.errors.any?
        format.html { redirect_to harami_vids_add_missing_music_to_evit_url(@harami_vid, harami_vid: {add_missing_music_to_evit: {musics_event_item_id: @event_item.id} }), notice: flash_msgs[:notice] }
        format.json { render :show, status: :ok, location: @harami_vid }
      else
        @harami_vid.errors.add :base, "Place is NOT updated." if !pla2upd
        @harami_vid.errors.add :base, flash[:alert] if flash[:alert].present? # alert is, if present, included in the instance
        hsflash = {}
        %i(warning notice).each do |ek|
          hsflash[ek] = flash[ek] if flash[ek].present?
        end
        opts = get_html_safe_flash_hash(alert: @harami_vid.errors.full_messages, **hsflash)
        hsstatus = {status: :unprocessable_entity}.merge(opts)
        format.html { render :show, **hsstatus } # notice (and/or warning) is, if any, passed as an option.  # NOTE: this is usually :edit, but only in this case this is :show (!)
        #format.html { render :edit, **(opts) } # notice (and/or warning) is, if any, passed as an option.
        format.json { render json: @harami_vid.errors, **hsstatus }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_event_item
      @harami_vid = HaramiVid.find(params[:id])
      perm_prms = params.require(:harami_vid).require(:add_missing_music_to_evit).permit(:musics_event_item_id, missing_music_ids: [])
      @event_item = EventItem.find(perm_prms[:musics_event_item_id])
      @music_ids = ((ar=perm_prms[:missing_music_ids]).present? ? ar.map{|i| i.present? ? i.to_i : nil} : []).compact
      set_event_event_items  # setting @event_event_items ; defined in HaramiVidsHelper
    end

    # Common authorize
    def auth_for!(method)
      authorize! method, @harami_vid  # Authorizes according to the same-name method for HaramiVid
    end

end
