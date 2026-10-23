# coding: utf-8
class MusicsController < ApplicationController
  include BaseWithTranslationControllerMethods  # for model_params, set_kind_from_params etc
  include ModuleCommon # for split_hash_with_keys
  include ModuleGridController # for set_grid
  include ModuleMemoEditor   # for memo_editor attribute
  include ModuleWikiUrl  # for wiki_url fetch_h1_wiki methods

  skip_before_action :authenticate_user!, :only => [:index, :show]  # Revert application_controller.rb so Index is viewable by anyone.
  load_and_authorize_resource except: [:index, :show, :new, :create]  # excludes :new and :create and manually authorize! in the methods (otherwise the default private method "*_params" seems to be read!)
  before_action :set_music, only: [:show]
  before_action :set_countries, only: [:new, :create, :edit, :update] # defined in application_controller.rb
  before_action :event_params_two, only: [:update, :create]

  # Symbol of the main parameters in the Form (except "place_id"), which exist in DB
  MAIN_FORM_KEYS ||= []
  MAIN_FORM_KEYS.concat(%w(year genre_id note))
                .concat(%w(artist_name engage_hows year_engage contribution))
                .concat(MODULE_WIKI_URL_ATTRIBUTES)

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = ([
    :artist_name, :year_engage, :engage_hows, :contribution,  # form-specific keys that do not exist in Model
    :artist_id,  # artist_id is allowed as GET in some cases to call index and new
  ] + MAIN_FORM_KEYS + PARAMS_PLACE_KEYS).uniq  # PARAMS_PLACE_KEYS defined in application_controller.rb
  # they, including place_id, will be handled in music_params_two()

  # Permitted main parameters for params() that are (1-level nested) Array
  PARAMS_ARRAY_KEYS = [:engage_hows]

  # Required in {BaseWithTranslationControllerMethods}: +[:disallow_nil, :allow_nil, :always_nil]+
  ORIG_LOCALE_TYPE_ON_CREATE = :disallow_nil

  # GET /musics
  # GET /musics.json
  def index
    @musics = Music.all
    set_artist_prms  # set @artist, @artist_name, @artist_title
    @artist_music_ids = (@artist ? @artist.musics.distinct.pluck(:id) : nil)

    if_hs_def = Proc.new{ |grid_prms|
      grid_prms[:title_ja].blank?
    }

    set_grid(Music, hs_def: {order: :updated_at, descending: true}, if_hs_def: if_hs_def) { |scope, grid_prms| # setting @grid; defined in concerns/module_grid_controller.rb
      next scope if grid_prms[:order].present? && (grid_prms[:order] != :updated_at || !grid_prms[:descending])
      next scope if grid_prms[:title_ja].blank?
      music_ids = Music.find_all_translations_by_partial_str(grid_prms[:title_ja], min_ja_chars: 1, min_en_chars: 1).pluck(:translatable_id).uniq
      order_by_given_ids(scope, music_ids) # defined in ModuleCommon
    }
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
    # Parameters: {"music" => {"genre_id" => "379794497", "year" => "1984", "artist_name" => "ＡI  ", "year_engage" => "", "engage_hows" => ["", "592497512", "746859435"], "contribution" => "", "note" => "", "memo_editor" => "my random memo", "translations_attributes" => [{"title" => "Yesterday", "ruby" => "イエスタデイ", "romaji" => "Iesutadei", "langcode" => "ja", "kind" => "full", "start_year" => "1998", "end_year" => "", "is_formal" => "true", "is_official" => "true", "is_true_name" => "0", "is_for_record" => "0", "is_literal" => "0", "is_internal" => "0", "note" => "Original Japanese music name"}, {"title" => "TestMusic No.2-1", "ruby" => "", "romaji" => "", "langcode" => "en", "kind" => "", "start_year" => "", "end_year" => "", "is_formal" => "true", "is_official" => "false", "is_true_name" => "0", "is_for_record" => "0", "is_literal" => "1", "is_internal" => "1", "note" => "International release name"}]}, "place_id" => "10877227", "prefecture_id" => "647877836", "country_id" => "756077872", "locale" => "en"}
    # No "is_orig" or "weight" on :create

    ## @record = @music = Music.new(@hsmain)
    mparams = set_record_and_authorize  # sets @record, @music and authorize; defined in base_with_translation_controller_methods.rb
    set_orig_locale_on_create(mparams)  # defined in base_with_translation_controller_methods.rb

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
          format.html { redirect_to @music, success: 'Music was successfully created.', alert: msg }
        end
        return
      end
    end

    respond_to do |format|
      if !@music.errors.present? && save_return
        extra_str = " / Artists=#{ApplicationRecord.logger_titles(@music.artists.uniq)}"
        logger_after_create(@music, extra_str: extra_str, method_txt: __method__)  # defined in application_controller.rb
        format.html { redirect_to @music, success: 'Music was successfully created.', alert: (flash[:alert] || [])+@msg_alerts} # alert may be set by an external process
        format.json { render :show, status: :created, location: @music }
      else
        format.html { render :new }
        format.json { render json: @music.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /musics/1
  # PATCH/PUT /musics/1.json
  def update
    @record = @music
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


  # Method also used in system tests
  #
  # @example
  #    title, field_string = MusicsController.artist_name_and_id_for_field(artist)
  #
  # @param artist [Artist]
  # @return [Array<String>] 2-element array of Title and "Title ID=(??)", the latter of which is used for a field in Music-show
  def self.artist_name_and_id_for_field(artist)
    artist_title = artist.title_or_alt  # in the original language!
    artist_name  = sprintf "%s (ID=%d)", artist_title, artist.id  # This format conforms my (simple) auto-complete (as opposed to "Name [en] [ID=%d]")
    [artist_title, artist_name]
  end

  ################################
  private
  ################################

    # Sets @hsmain and @hstra from params
    #
    # +action_name+ (+create+ ?) is checked inside!
    #
    # @return NONE
    def event_params_two
      set_hsparams_main_tra(:music) # defined in application_controller.rb
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_music
      @music = Music.find(params[:id])
    end

    # Overwrites (modifies) that in {BaseWithTranslationControllerMethods}
    #
    # This accepts +:place_id+ whether it appears at the top level or under :music
    # and incorporates it into the permitted {#model_params}
#    def model_params
#      extracted_place_id = params[:place_id].presence || params.dig(:music, :place_id)
#      super.with_defaults(place_id: extracted_place_id)
#    end

    # set @artist, @artist_name, @artist_title from a given URL parameter
    def set_artist_prms
      artist_id_str = (!params[:artist_id].blank? && params[:artist_id]) || params[:music] && params[:music][:artist_id]
      if artist_id_str.blank?
        @artist = @artist_name = @artist_title = nil
      else
        @artist = Artist.find(artist_id_str.to_i)
        if @artist
          @artist_title, @artist_name = self.class.artist_name_and_id_for_field(@artist)  # @artist_name is input in the View field
        else
          @artist_name = @artist_title = nil
          msg = "Specified Artist-ID (#{artist_id_str}) is non-existent."
          flash[:alert] ||= []
          flash[:alert] << msg
          logger.warn "ERROR: Music-new GET parameter is wrong for some reason: "+msg
        end
        # @artist_title_for_ac =  Artist.base_with_translation_with_id_str(@artist, print_id: true)
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
