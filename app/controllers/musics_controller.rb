# coding: utf-8
class MusicsController < ApplicationController
  include ModuleCommon # for split_hash_with_keys

  skip_before_action :authenticate_user!, :only => [:index, :show]  # Revert application_controller.rb so Index is viewable by anyone.
  load_and_authorize_resource except: [:index, :show, :new, :create]  # excludes :new and :create and manually authorize! in the methods (otherwise the default private method "*_params" seems to be read!)
  before_action :set_music, only: [:show]
  before_action :set_countries, only: [:new, :create, :edit, :update] # defined in application_controller.rb
  before_action :event_params_two, only: [:update, :create]

  # Symbol of the main parameters in the Form (except "place_id"), which exist in DB
  MAIN_FORM_KEYS = %w(year genre_id note)

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = ([
    :artist_name, :year_engage, :engage_hows, :contribution,  # form-specific keys that do not exist in Model
    :artist_id,  # artist_id is allowed as GET in some cases to call index and new
  ] + MAIN_FORM_KEYS + PARAMS_PLACE_KEYS).uniq  # PARAMS_PLACE_KEYS defined in application_controller.rb
  # they, including place_id, will be handled in music_params_two()

  # Permitted main parameters for params() that are (1-level nested) Array
  PARAMS_ARRAY_KEYS = [:engage_hows]

  # GET /musics
  # GET /musics.json
  def index
    @musics = Music.all
    set_artist_prms  # set @artist, @artist_name, @artist_title
    @artist_music_ids = (@artist ? @artist.musics.distinct.pluck(:id) : nil)
    
    # May raise ActiveModel::UnknownAttributeError if malicious params are given.
    # It is caught in application_controller.rb
    @grid = MusicsGrid.new(order: :created_at, descending: true, **grid_params) do |scope|
      nmax = BaseGrid.get_max_per_page(grid_params[:max_per_page])
      scope.page(params[:page]).per(nmax)
    end
  end

  # GET /musics/1
  # GET /musics/1.json
  def show
  end

  # GET /musics/new
  def new
    @music = Music.new
    set_artist_prms  # set @artist, @artist_name, @artist_title
    authorize! __method__, @music  # necessary because load_and_authorize_resource is skipped!
  end

  # GET /musics/1/edit
  def edit
  end

  # POST /musics
  # POST /musics.json
  def create
    # Parameters: {"authenticity_token"=>"[FILTERED]", "music"=>{"langcode"=>"ja", "is_orig"=>"nil", "title"=>"The Lunch Time", "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"", "place.prefecture_id.country_id"=>"", "place.prefecture_id"=>"", "place_id"=>"", "genre_id"=>"", "year"=>"", "note"=>"", "artist_name"=>"", "year_engage"=>"", "engage_hows"=>["", "592497512", "746859435"], "contribution"=>""}, "commit"=>"Create Music"}

    @music = Music.new(@hsmain)
    authorize! __method__, @music
    add_unsaved_trans_to_model(@music, @hstra) # defined in application_controller.rb

    # @music.errors would be added if something goes wrong.
    artist = helpers.get_artist_from_params @prms_all['artist_name'], @music

    # IF nothing has gone wrong in finding an Artist if specified,
    # here we save @music as well as its main Translation.
    @msg_alerts = []
    if !@music.errors.present?  # Not even attempt to save if artist does not exist at ll.
      save_return = @music.save
      #save_engages(@prms_all, artist) if save_return && artist  # not run if artist is not specified.  ## With this, engage_hows are not permitted.
      begin
        # This may add an Error to @msg_alerts
        save_engages(@prms_all, artist) if save_return && artist  # not run if artist is not specified.
      rescue => err
        logger.error "ERROR in saving Engage in MusicsController#create Music-ID=#{@music.id} (which should never happen through UI): "+err.message+" / params[:music]=#{params[:music].inspect}"
        # Something goes seriously wrong (which should never happen when called from UI).
        respond_to do |format|
          msg = [(flash[:alert] || ""), @msg_alerts.join(" "), "Consequently, although Music was successfully created, the creation of one (or more) of Music-Artist links failed for an unknown reason. You may try again later. If the problem persists, contact the site administrator."].join(" ")
          format.html { redirect_to @music, notice: msg, alert: msg }
        end
        return
      end
    end

    respond_to do |format|
      if !@music.errors.present? && save_return
        extra_str = " / Artists=#{ApplicationRecord.logger_titles(@music.artists.uniq)}"
        logger_after_create(@music, extra_str: extra_str, method_txt: __method__)  # defined in application_controller.rb
        if @msg_alerts.empty?
          format.html { redirect_to @music, notice: 'Music was successfully created.', alert: flash[:alert]} # alert may be set by an external process
        else
          msg = flash[:alert]+" "+@msg_alerts.join(" ")
          format.html { redirect_to @music, notice: msg, alert: msg }
        end
        format.json { render :show, status: :created, location: @music }
      else
        format.html { render :new }
        format.json { render json: @music.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /musics/1
  # PATCH/PUT /musics/1.json
  def update
    # Parameters: {"authenticity_token"=>"[FILTERED]", "music"=>{"place.prefecture_id.country_id"=>"", "place.prefecture_id"=>"", "place_id"=>"", "genre_id"=>"", "year"=>"", "note"=>""}, "commit"=>"Create Music"}

    def_respond_to_format(@music, :updated){
      @music.update(@hsmain)
    } # defined in application_controller.rb
  end

  # DELETE /musics/1
  # DELETE /musics/1.json
  def destroy
    @music.destroy
    respond_to do |format|
      format.html { redirect_to musics_url, notice: 'Music was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Sets @hsmain and @hstra from params
    #
    # +action_name+ (+create+ ?) is checked inside!
    #
    # @return NONE
    def event_params_two
      set_hsparams_main_tra(:music) # defined in application_controller.rb
    end

    def grid_params
      params.fetch(:musics_grid, {}).permit!
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_music
      @music = Music.find(params[:id])
    end

    ## Only allow a list of trusted parameters through.
    ## This is automatically read for :new in load_and_authorize_resource
    def music_params
      params.require(:music).permit(MAIN_FORM_KEYS.map(&:to_sym)+[:place_id])
    end

    # set @artist, @artist_name, @artist_title from a given URL parameter
    def set_artist_prms
      artist_id_str = (!params[:artist_id].blank? && params[:artist_id]) || params[:music] && params[:music][:artist_id]
      if artist_id_str.blank?
        @artist = @artist_name = @artist_title = nil
      else
        @artist = Artist.find(artist_id_str.to_i)
        @artist_title = @artist.title_or_alt
        @artist_name  = sprintf "%s (ID=%d)", @artist_title, @artist.id
      end
    end

    # Save Engages.
    #
    # Any errors would not be fatal.
    # @msg_alerts may be set.
    #
    # @param engage_hows [Array<String>] String of Integers like "5"
    # @param artist [Artist] for {Engage}
    # @return [NilClass]
    def save_engages(hsprm, artist)
      hsprm['engage_hows'].map{|i| i.blank? ? nil : i.to_i}.compact.uniq.each do |ei|
        eh = EngageHow.find(ei)
        if !eh
          msg = sprintf "Invalid ID=(%d) for EngageHow is specified, which should not happen.", ei
          logger.error msg
          @msg_alerts << msg
          next
        end

        year = (hsprm['year_engage'].blank? ? hsprm['year'] : hsprm['year_engage']) # Same as Year for Music

        # Find a potential Engage with 4 unique parameters.
        eng = Engage.find_or_initialize_by(artist: artist, music: @music, engage_how: eh, year: year)
        eng.contribution = hsprm['contribution'] if !hsprm['contribution'].blank?
        if eng.new_record?
          eng_status = eng.save
          @msg_alerts << 'Engage='+eh.title(langcode: ja)+' is failed to be saved.' if !eng_status
          next
        end

        # Engage exists. do nothing in principle.
        # Alert is raised only when an inconsistent "contribution" is specified.
        msg = sprintf "Engage ID=(%d) is specified to be created by User=(%d) in Music#create/update, but it already exists and hence nothing is done.", eng.id, current_user.id
        logger.info msg
        msg = sprintf "Engage in year=%s with %s already exists. Contribution is not updated in the way specified. Go to its edit panel to edit it.", year.inspect, eh.title(langcode: 'ja')
        @msg_alerts << msg if !hsprm['contribution'].blank? && hsprm['contribution'].to_i != eng.contribution
      end
    end # save_engages(hsprm)
end
