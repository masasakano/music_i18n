class Musics::MergesController < BaseMergesController
  # This constant should be defined in each sub-class of BaseMergesController
  # to indicate the mandatory parameter name for +params+
  MODEL_SYM = :music

  # Array of used keys in the form of the class like :other_music_id (or :other_artist_id)
  FORM_MERGE_KEYS = %i(other_artist_id other_artist_title to_index lang_orig lang_trans engage prefecture_place genre year note)

  before_action :set_music,  only: [:new]
  before_action :set_musics, only: [:edit, :update]

  # @raise [ActionController::UrlGenerationError] if no Music ID is found in the path.
  def new
  end

  # @raise [ActionController::UrlGenerationError] if no Music ID is found in the path.
  # @raise [ActionController::ParameterMissing] if the other Music ID is not specified (as GET).
  def edit
    if !(2..3).cover?(@musics.size)
      msg = 'No Music matches the given one. Try a different title or ID.'
      return respond_to do |format|
        format.html { redirect_to musics_new_merges_path(@musics[0]), alert: msg } # status: redirect
        format.json { render json: {error: msg}, status: :unprocessable_entity }
      end
    end
    @all_checked_disabled = all_checked_disabled(@musics) # defined in base_merges_controller.rb
  end

  def update
    raise 'This should never happen - necessary parameter is missing. params='+params.inspect if !(2..3).cover?(@musics.size)
    @to_index = merge_params[FORM_MERGE[:to_index]].to_i  # defined in base_merges_controller.rb
    @all_checked_disabled = all_checked_disabled(@musics) # defined in base_merges_controller.rb
    begin
      ActiveRecord::Base.transaction do
        merge_lang_orig(@musics)   # defined in base_merges_controller.rb
        merge_lang_trans(@musics)  # defined in base_merges_controller.rb
        merge_engage_harami1129(@musics)  # defined in base_merges_controller.rb
        %i(prefecture_place genre year).each do |metho| 
          merge_overwrite(@musics, metho) # defined in base_merges_controller.rb
        end
        merge_note(@musics)  # defined in base_merges_controller.rb
        merge_harami_vid_music_assoc
        merge_created_at(@musics)  # defined in base_merges_controller.rb

        @musics[@to_index].save!
        @musics[other_index(@to_index)].reload  # Without this HaramiVidMusicAssoc is cascade-destroyed!
        @musics[other_index(@to_index)].destroy!
        #raise ActiveRecord::Rollback, "Force rollback." if ...
      end
    rescue
      raise ## Transaction failed!  Rolled back.
    end

    _update_render(@musics)  # defined in base_merges_controller.rb
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
        @musics << get_merged_model(@musics)    # defined in base_merges_controller.rb
      rescue ActiveRecord::RecordNotFound
        # Specified Title for Edit is not found.  For update, this should never happen through UI.
        # As a result, @musics.size == 1
      end
    end

    # merging HaramiVidMusicAssoc
    def merge_harami_vid_music_assoc
      @musics[other_index(@to_index)].harami_vid_music_assocs.each do |hvma|
        hvma.update!(music: @musics[@to_index])
      end
    end
end
