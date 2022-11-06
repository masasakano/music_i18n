class Musics::MergesController < BaseMergesController
  # This constant should be defined in each sub-class of BaseMergesController
  # to indicate the mandatory parameter name for +params+
  MODEL_SYM = :music

  before_action :set_music,  only: [:new]
  before_action :set_musics, only: [:edit, :update]

  # @raise [ActionController::UrlGenerationError] if no Music ID is found in the path.
  def new
  end

  # @raise [ActionController::UrlGenerationError] if no Music ID is found in the path.
  # @raise [ActionController::ParameterMissing] if the other Music ID is not specified (as GET).
  def edit
    if @musics.size != 2
      msg = 'No Music matches the given one. Try a different title.'
      respond_to do |format|
        format.html { redirect_to musics_new_merge_users_path(@musics[0]), alert: msg }
        format.json { render json: {error: msg}, status: :unprocessable_entity }
      end
    end
  end

  def update
    raise 'This should never happen - necessary parameter is missing.' if @musics.size != 2
    @to_index = merge_params[FORM_MERGE[:to_index]].to_i  # defined in base_merges_controller.rb
    begin
      ActiveRecord::Base.transaction do
        merge_lang_orig(@musics)   # defined in base_merges_controller.rb
        merge_lang_trans(@musics)  # defined in base_merges_controller.rb
        merge_engage_harami1129
        %i(prefecture_place genre year).each do |metho| 
          merge_overwrite metho
        end
        merge_note
        merge_harami_vid_music_assoc

        @musics[@to_index].save!
        @musics[other_index(@to_index)].reload  # Without this HaramiVidMusicAssoc is cascade-destroyed!
        @musics[other_index(@to_index)].destroy!
        #raise ActiveRecord::Rollback, "Force rollback." if ...
      end
    rescue
      raise ## Transaction failed!  Rolled back.
    end

    mu_to = @musics[@to_index]
    mu_other = @musics[other_index(@to_index)]
    if !mu_to.errors.any? && mu_other.destroyed?
      return respond_to do |format|
        msg = sprintf 'Musics was successfully merged.'
        format.html { redirect_to music_path(mu_to), success: msg }
        format.json { render :show, status: :ok, location: mu_to }
      end
    end

    ## Somehow failed!  Error...
    errmsgs = []
    [@to_index, other_index(@to_index)].each do |ind|
      errmsgs += @musics[ind].errors.full_messages if !@musics[ind].destroyed?
    end
    logger.error "ERROR: Merge-Musics somehow failed with errors.full_messages="+errmsgs.inspect

    errmsgs_safe = errmsgs.map{|i| ERB::Util.html_escape(i)}.join("  ")
    msg0 = 'Failed to merge Musics'
    if !mu_other.destroyed?
      msg0 << " with " + view_context.link_to("ID=#{mu_other.id}", music_path(mu_other))
    end
    msg1 = (msg0 + '.  ' + errmsgs_safe).html_safe
    opts = flash_html_safe(alert: msg1)  # defined in /app/controllers/application_controller.rb

    respond_to do |format|
      hsstatus = {status: :unprocessable_entity}
      format.html { redirect_to music_path(mu_to), **(hsstatus.merge opts) }
      format.json { render json: errmsgs, **hsstatus }
    end
  end

  private
    # Use callback for setup for new
    def set_music
      @music = Music.find(params[:id])
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_musics
      @musics = []
      @musics << Music.find(params[:id])
      begin
        @musics << get_other_model(@musics[0])  # defined in base_merges_controller.rb
      rescue ActiveRecord::RecordNotFound
        # Specified Title for Edit is not found.  For update, this should never happen through UI.
        # As a result, @musics.size == 1
      end
    end

    # Merge Engage and adjust dependent Harami1129
    #
    # Some Engages will have different {Engage#music} and contribution.
    # Some (rare) Engages that belong to Music to be deleted remain unchanged
    # and as a result will be cascade-deleted.
    def merge_engage_harami1129
      index2use = merge_param_int(:engage)  # defined in base_merges_controller.rb
      engages_to_copy =       @musics[index2use].engages
      engages_to_supplement = @musics[other_index(index2use)].engages

      engages_to_copy.each do |eng|
        eng.update!(music: @musics[@to_index])
      end

      engages_to_supplement.each do |eng|
        hows = engages_to_copy.where(engage_how: eng.engage_how)
        if hows.exists?
          if hows.where(artist: eng.artist).exists?
            # The same Artist with the same EngageHow exists. So, this record will be
            # cascade-deleted when the Music is deleted. As a result, year and note
            # in this record are discarded.
            #
            # If it has dependent Harami1129(s), its deletion would raise an Error.
            eng_to_switch_to = hows.where(artist: eng.artist).first
            eng.harami1129s.each do |harami1129|
              harami1129.update!(engage: eng_to_switch_to)
            end
            next
          else
            eng.contribution = nil
          end
        end
        eng.music = @musics[@to_index]
        eng.save!
      end
    end

    # Overwrite the one of attributes of model, unless it is nil (in which case the other is used).
    #
    # * prefecture_place: 'prefecture_place',
    # * genre: 'genre',
    # * year: 'year',
    #
    # @param metho [Symbol]
    def merge_overwrite(metho)
      attr = ((metho == :prefecture_place) ? :place : metho).to_s
      content = nil
      index2use = merge_param_int(metho)  # defined in base_merges_controller.rb
      [index2use, other_index(index2use)].each do |ind|
        (content = @musics[ind].send(attr)) && break
      end
      @musics[@to_index].send(attr+"=", content)
    end

    # notes are, unlike other parameters, simply merged.
    #
    # The note for the preferred comes first.
    # In an unlikely case of both notes being identical, one of them is discarded.
    def merge_note
      @musics[@to_index].note = [@musics[@to_index], @musics[other_index(@to_index)]].map{|i| i.note || ""}.uniq.join(" ")
    end

    def merge_harami_vid_music_assoc
      @musics[other_index(@to_index)].harami_vid_music_assocs.each do |hvma|
        hvma.update!(music: @musics[@to_index])
      end
    end
end
