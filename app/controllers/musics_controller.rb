class MusicsController < ApplicationController
  include ModuleCommon # for split_hash_with_keys

  skip_before_action :authenticate_user!, :only => [:index, :show]
  before_action :set_music, only: [:show, :edit, :update, :destroy]
  load_and_authorize_resource except: [:index, :show]

  # String of the main parameters in the Form (except "place_id")
  MAIN_FORM_KEYS = %w(year genre_id note)

  # GET /musics
  # GET /musics.json
  def index
    @musics = Music.all
    set_artist_prms  # set @artist, @artist_name, @artist_title
    @artist_music_ids = (@artist ? @artist.musics.distinct.pluck(:id) : nil)
  end

  # GET /musics/1
  # GET /musics/1.json
  def show
  end

  # GET /musics/new
  def new
    @music = Music.new
    @countries = Country.all
    @prefectures = Prefecture.all
    #@places = Place.all
    set_artist_prms  # set @artist, @artist_name, @artist_title
  end

  # GET /musics/1/edit
  def edit
    @countries = Country.all
    @prefectures = Prefecture.all
    #@places = Place.all
  end

  # POST /musics
  # POST /musics.json
  def create
    # Parameters: {"authenticity_token"=>"[FILTERED]", "music"=>{"langcode"=>"ja", "is_orig"=>"nil", "title"=>"", "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"", "place.prefecture_id.country_id"=>"", "place.prefecture_id"=>"", "place_id"=>"", "genre_id"=>"", "year"=>"", "note"=>"", "artist_name"=>"", "year_engage"=>"", "engage_hows"=>["", ""], "contribution"=>""}, "commit"=>"Create Music"}
    params.permit!
    hsprm = params.require(:music).permit(
      :year, :genre_id, :note,
      :langcode, :is_orig, :title, :ruby, :romaji, :alt_title, :alt_ruby, :alt_romaji,
      :"place.prefecture_id.country_id", :"place.prefecture_id", :place_id,
      :artist_name, :year_engage, :engage_hows, :contribution)

    hsprm.permit!

    hsmain = params[:music].slice(*MAIN_FORM_KEYS)
    @music = Music.new(**(hsmain.merge({place_id: helpers.get_place_from_params(hsprm).id})))

    hsprm_tra, resths = split_hash_with_keys(
                 params[:music],
                 %w(langcode is_orig title ruby romaji alt_title alt_ruby alt_romaji))
    tra = Translation.preprocessed_new(**hsprm_tra.merge({'is_orig' => true})) # is_orig passed from the form is ignored, which is anyway a hidden parameter.

    @music.unsaved_translations << tra

    artist = helpers.get_artist_from_params hsprm['artist_name'], @music

    @msg_alerts = []
    if !@music.errors.present?  # Not even attempt to save if artist does not exist at ll.
      save_return = @music.save
      #save_engages(hsprm, artist) if save_return && artist  # not run if artist is not specified.  ## With this, engage_hows are not permitted.
      save_engages(params[:music], artist) if save_return && artist  # not run if artist is not specified.
    end

    respond_to do |format|
      if !@music.errors.present? && save_return
        if @msg_alerts.empty?
          format.html { redirect_to @music, notice: 'Music was successfully created.', alert: flash[:alert]} # alert may be set by an external process
        else
          msg = flash[:alert]+" "+@msg_alerts.join(" ")
          format.html { redirect_to @music, notice: msg, alert: msg }
        end
        format.json { render :show, status: :created, location: @music }
      else
        @countries = Country.all
        @prefectures = Prefecture.all
        format.html { render :new }
        format.json { render json: @music.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /musics/1
  # PATCH/PUT /musics/1.json
  def update
    # Parameters: {"authenticity_token"=>"[FILTERED]", "music"=>{"place.prefecture_id.country_id"=>"", "place.prefecture_id"=>"", "place_id"=>"", "genre_id"=>"", "year"=>"", "note"=>""}, "commit"=>"Create Music"}
    params.permit!
    hsprm = params.require(:music).permit(
      :year, :note,
      :"place.prefecture_id.country_id", :"place.prefecture_id", :place_id)
    hsprm.permit!

    hsmain = params[:music].slice(*MAIN_FORM_KEYS)
    hs2pass = hsmain.merge({place_id: helpers.get_place_from_params(hsprm).id})

    respond_to do |format|
      if @music.update(hs2pass)
        format.html { redirect_to @music, notice: 'Music was successfully updated.' }
        format.json { render :show, status: :ok, location: @music }
      else
        format.html { render :edit }
        format.json { render json: @music.errors, status: :unprocessable_entity }
      end
    end
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
    # Use callbacks to share common setup or constraints between actions.
    def set_music
      @music = Music.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
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
      hsprm['engage_hows'].map{|i| i.blank? ? nil : i.to_i}.compact.each do |ei|
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
