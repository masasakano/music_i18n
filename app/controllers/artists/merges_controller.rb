class Artists::MergesController < BaseMergesController
  # This constant should be defined in each sub-class of BaseMergesController
  # to indicate the mandatory parameter name for +params+
  MODEL_SYM = :artist

  before_action :set_artist,  only: [:new]
  before_action :set_artists, only: [:edit, :update]

  # @raise [ActionController::UrlGenerationError] if no Artist ID is found in the path.
  def new
  end

  # @raise [ActionController::UrlGenerationError] if no Artist ID is found in the path.
  # @raise [ActionController::ParameterMissing] if the other Artist ID is not specified (as GET).
  def edit
  end

  def update
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
      rescue ActiveRecord::RecordNotFound
        # Specified Title for Edit is not found.  For update, this should never happen through UI.
        # As a result, @artists.size == 1
      end
    end

end
