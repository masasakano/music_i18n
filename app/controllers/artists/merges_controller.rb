class Artists::MergesController < BaseMergesController
  # This constant should be defined in each sub-class of BaseMergesController
  # to indicate the mandatory parameter name for +params+
  MODEL_SYM = :artist

  # Array of used keys in the form of the class like :other_music_id (or :other_artist_id)
  FORM_MERGE_KEYS = %i(other_artist_id other_artist_title to_index lang_orig lang_trans engage prefecture_place sex birthday wiki_en wiki_ja note)

  before_action :set_artist,  only: [:new]
  before_action :set_artists, only: [:edit, :update]

  # @raise [ActionController::UrlGenerationError] if no Artist ID is found in the path.
  def new
  end

  # @raise [ActionController::UrlGenerationError] if no Artist ID is found in the path.
  # @raise [ActionController::ParameterMissing] if the other Artist ID is not specified (as GET).
  def edit
    if !(2..3).cover?(@artists.size)
      msg = 'No Artist matches the given one. Try a different title or ID.'
      return respond_to do |format|
        format.html { redirect_to artists_new_merges_path(@artists[0]), alert: msg } # status: redirect
        format.json { render json: {error: msg}, status: :unprocessable_entity }
      end
    end
    @all_checked_disabled = all_checked_disabled(@artists) # defined in base_merges_controller.rb
  end

  def update
    raise 'This should never happen - necessary parameter is missing. params='+params.inspect if !(2..3).cover?(@artists.size)
    @to_index = merge_params[FORM_MERGE[:to_index]].to_i   # defined in base_merges_controller.rb
    @all_checked_disabled = all_checked_disabled(@artists) # defined in base_merges_controller.rb
    begin
      ActiveRecord::Base.transaction do
        merge_lang_orig(@artists)   # defined in base_merges_controller.rb
        merge_lang_trans(@artists)  # defined in base_merges_controller.rb
        merge_engage_harami1129(@artists)  # defined in base_merges_controller.rb
        %i(prefecture_place sex wiki_en wiki_ja).each do |metho| 
          merge_overwrite(@artists, metho) # defined in base_merges_controller.rb
        end
        merge_birthday
        merge_note(@artists)  # defined in base_merges_controller.rb
        merge_created_at(@artists)  # defined in base_merges_controller.rb

        @artists[@to_index].save!
        @artists[other_index(@to_index)].reload  # Without this HaramiVidArtistAssoc is cascade-destroyed!
        @artists[other_index(@to_index)].destroy!
        #raise ActiveRecord::Rollback, "Force rollback." if ...
      end
    rescue
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
      @artists = []
      @artists << Artist.find(params[:id])
      begin
        @artists << get_other_model(@artists[0])  # defined in base_merges_controller.rb
        @artists << get_merged_model(@artists)    # defined in base_merges_controller.rb
      rescue ActiveRecord::RecordNotFound
        # Specified Title for Edit is not found.  For update, this should never happen through UI.
        # As a result, @artists.size == 1
      end
    end

    # Overwrite the Birthday-related columns of the model, unless it is all nil (in which case the other is used).
    # @artist is modified but not saved in this routine.
    #
    # @return [void]
    def merge_birthday
      bday_attrs = %i(birth_year birth_month birth_day)
      bday3s = {}
      index2use = merge_param_int(:birthday)  # defined in base_merges_controller.rb
      [index2use, other_index(index2use)].each do |ind|
        bday_attrs.each do |attr|
          bday3s[attr] = @artists[ind].send(attr)
        end
        break if !bday3s.values.compact.empty?
      end
      bday3s.each_pair do |attr, val|
        @artists[@to_index].send(attr.to_s+"=", val)
      end
    end

end
