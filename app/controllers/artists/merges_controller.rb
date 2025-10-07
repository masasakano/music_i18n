class Artists::MergesController < BaseMergesController
  # This constant should be defined in each sub-class of BaseMergesController
  # to indicate the mandatory parameter name for +params+
  MODEL_SYM = :artist

  # Array of used keys in the form of the class like :other_music_id (or :other_artist_id)
  FORM_MERGE_KEYS = %i(other_artist_id other_artist_title to_index lang_orig lang_trans engage prefecture_place sex birthday note)  ## memo_editor)

  before_action :set_artist,  only: [:new]
  before_action :set_artists, only: [:edit, :update]

  # @raise [ActionController::UrlGenerationError] if no Artist ID is found in the path.
  def new
  end

  # @raise [ActionController::UrlGenerationError] if no Artist ID is found in the path.
  # @raise [ActionController::ParameterMissing] if the other Artist ID is not specified (as GET).
  def edit
    msg = _msg_if_invalid_prm_in_merging(@artists, "Artist") # defined in base_merges_controller.rb

    if msg  # e.g., when non-existent Artist-ID is specified by the user.
      return respond_to do |format|
        format.html { redirect_to artists_new_merges_path(@artists[0]), alert: msg } # status: redirect
        format.json { render json: {error: msg}, status: :unprocessable_content }
      end
    end
    @merged_artist = get_merged_model(@artists)  # defined in base_merges_controller.rb
    @all_checked_disabled = all_checked_disabled(@artists) # defined in base_merges_controller.rb
  end

  def update
    raise 'This should never happen - necessary parameter is missing. params='+params.inspect if 2 != @artists.size
    @all_checked_disabled = all_checked_disabled(@artists) # defined in base_merges_controller.rb

    mdl_self, mdl_other, priorities = get_self_other_priorities(@artists)
    begin
      ActiveRecord::Base.transaction(requires_new: true) do  # "requires_new" option necessary for testing.
        _ = mdl_self.merge_other(mdl_other, priorities: priorities, save_destroy: true, user: current_user)
        #raise ActiveRecord::Rollback, "Force rollback." if ...
      end
    rescue
      msg = "ERROR(#{File.basename __FILE__}): merging failed: ID(after-merged)=#{mdl_self.id}; models=#{@artists.inspect}"
      logger.error msg
      warn msg
      raise ## Transaction failed!  Rolled back.
    end

    _update_render(@artists)  # defined in base_merges_controller.rb
  end

  private

    # Use callback for setup for new
    def set_artist
      @artist = Artist.find(params[:id])
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_artists
      set_to_index  # set @to_index; defined in base_merges_controller.rb

      @artists = []
      @artists << Artist.find(params[:id])
      begin
        @artists << get_other_model(@artists[0])  # defined in base_merges_controller.rb
      rescue ActiveRecord::RecordNotFound
        # Specified Title for Edit is not found (which could happen).  For update, this should never happen through UI.
        # As a result, @artists.size == 1
        raise if :edit != action_name.to_sym
      end
    end

end
