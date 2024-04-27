# coding: utf-8
class HaramiVidsController < ApplicationController
  include ModuleCommon  # for contain_asian_char

  skip_before_action :authenticate_user!, :only => [:index, :show]
  load_and_authorize_resource except: [:index, :show, :create] # This sets @harami_vid
  #before_action :set_harami_vid, only: [:show, :edit, :update, :destroy]
  before_action :model_params_multi, only: [:create, :update]

  # params key for auto-complete Artist
  PARAMS_KEY_AC = BaseMerges::BaseWithIdsController.formid_autocomplete_with_id(Artist).to_sym

  # Symbol of the main parameters in the Form (except "place_id"), which exist in DB or as setter methods
  MAIN_FORM_KEYS = %i(uri duration note) + [
    "form_channel_owner", "form_channel_type", "form_channel_platform",
    "event_ids", "artist_name", "form_engage_hows", "form_engage_year", "form_contribution",
    "artist_name_collab", "form_instrument", "form_play_role",
    "music_name", "music_timing", 
    "uri_playlist_en", "uri_playlist_ja",
  ]

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = MAIN_FORM_KEYS + [
    "release_date(1i)", "release_date(2i)", "release_date(3i)",
  ] + [PARAMS_KEY_AC]
  # these will be handled in model_params_multi()

#    #<ActionController::Parameters {"authenticity_token"=>"vXemGMOJoVf8XIu-9cPlPj9QPMclsq63rqimxEhVtZLO9zCmahWNZdeCCF1F3z3lmo8TGi9fm9yLAW6LqM4rpA"

  # GET /harami_vids
  # GET /harami_vids.json
  def index
    @harami_vids = HaramiVid.all

    # May raise ActiveModel::UnknownAttributeError if malicious params are given.
    # It is caught in application_controller.rb
    @grid = HaramiVidsGrid.new(order: :release_date, descending: true, **grid_params) do |scope|
      nmax = BaseGrid.get_max_per_page(grid_params[:max_per_page])
      scope.page(params[:page]).per(nmax)
    end
  end

  # GET /harami_vids/1
  # GET /harami_vids/1.json
  def show
  end

  # GET /harami_vids/new
  def new
    @harami_vid = HaramiVid.new
    #params.permit(:release_date, :duration, :uri, :place_id, :flag_by_harami, :uri_playlist_ja, :uri_playlist_en, :music_timing, :channel, :note)
    @countries = Country.all
    @prefectures = Prefecture.all
    @places = Place.all
  end

  # GET /harami_vids/1/edit
  def edit
    @countries = Country.all
    @prefectures = Prefecture.all
    @places = Place.all
  end

  # POST /harami_vids
  # POST /harami_vids.json
  def create
    #@harami_vid = HaramiVid.new(sliced_harami_vid_params)
    @harami_vid = HaramiVid.new(@hsmain)  # This sets most of the form parameters
    authorize! __method__, @harami_vid

print "DEBUG: ";p [ @harami_vid, @hsmain, @hstra, @prms_all]
    add_unsaved_trans_to_model(@harami_vid, @hstra) # defined in application_controller.rb
    def_respond_to_format(@harami_vid)              # defined in application_controller.rb
### Sets @hsmain and @hstra and @prms_all from params

#    hvid_respond_to_format(@harami_vid, :created)
  end

  # PATCH/PUT /harami_vids/1
  # PATCH/PUT /harami_vids/1.json
  def update
    def_respond_to_format(@harami_vid, :updated){
      @harami_vid.update(@hsmain)
    } # defined in application_controller.rb
#    hvid_respond_to_format(@harami_vid, :updated)
  end

  # DELETE /harami_vids/1
  # DELETE /harami_vids/1.json
  def destroy
    def_respond_to_format_destroy(@harami_vid)  # defined in application_controller.rb
  end


  # Common routine for create and update
  #
  # @see application_controller.rb
  #
  # @param mdl [ApplicationRecord]
  # @param created_updated [Symbol] Either :created(Def) or :updated
  # @param failed [Boolean] if true (Def: false), it has already failed.
  # @param redirected_path [String, NilClass] Path to be redirected if successful, or nil (Default)
  # @param back_html [String, NilClass] If the path specified (Def: nil) and if successful, HTML (likely a link to return) preceded with "Return to" is added to a Flash mesage; e.g., '<a href="/musics/5">Music</a>'
  # @param alert [String, NilClass] alert message if any
  # @param warning [String, NilClass] warning message if any
  # @param notice [String, NilClass] notice message if any
  # @param success [String, NilClass] success message if any. Default is "%s was successfully %s." but it is overwritten if specified.
  # @return [void]
  def hvid_respond_to_format(mdl, created_updated=:created, failed: false, redirected_path: nil, back_html: nil, alert: nil, **inopts)
    ret_status, render_err =
      case created_updated.to_sym
      when :created
        [:created, :new]
      when :updated
        [:ok, :edit]
      else
        raise 'Contact the code developer.'
      end

    begin
      ActiveRecord::Base.transaction do
        case created_updated.to_sym
        when :created
          mdl.save!
        when :updated
          mdl.update!(sliced_harami_vid_params)
        else
          raise 'Contact the code developer.'
        end

        ####### Make sure to add any errors to "mdl"
        ####### Make sure to fail in Exception (not mdl.save but mdl.save!)
        #### Save Artist
        #### Save Music
        #### Save HaramiVidMusicAssoc
      end
    rescue
      ## Transaction failed.
      return respond_to do |format|
        mdl.errors.add :base, alert  # alert is included in the instance
        opts = flash_html_safe(alert: alert, **inopts)  # defined in application_controller.rb
        opts.delete :alert  # because alert is contained in the model itself.
        hsstatus = {status: :unprocessable_entity}
        format.html { render render_err,       **(hsstatus.merge opts) } # notice (and/or warning) is, if any, passed as an option.
        format.json { render json: mdl.errors, **hsstatus }
      end
    end

    respond_to do |format|
      inopts = inopts.map{|k,v| [k, (v.respond_to?(:call) ? v.call(mdl) : v)]}.to_h
      alert = (alert.respond_to?(:call) ? alert.call(mdl) : alert)

      msg = sprintf '%s was successfully %s.', mdl.class.name, created_updated.to_s  # e.g., Article was successfully created.
      msg << sprintf('  Return to %s.', back_html) if back_html
      opts = flash_html_safe(success: msg.html_safe, alert: alert, **inopts) # "success" defined in /app/controllers/application_controller.rb
      format.html { redirect_to (redirected_path || mdl), **opts }
      format.json { render :show, status: ret_status, location: mdl }
    end
  end

  private
    def grid_params
      params.fetch(:harami_vids_grid, {}).permit!
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_harami_vid
      @harami_vid = HaramiVid.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def harami_vid_params
      params.require(:harami_vid).permit(:release_date, :duration, :uri, :"place.prefecture_id.country_id", :"place.prefecture_id", :place, :flag_by_harami, :uri_playlist_ja, :uri_playlist_en, :artist, :engage_how2, :music, :music_timing, :channel, :note)
    end

    # Only those that are direct parameters of HaramiVid
    def sliced_harami_vid_params
      prmret = harami_vid_params.slice(:release_date, :duration, :uri, :flag_by_harami, :uri_playlist_ja, :uri_playlist_en, :note)
      {place_id: harami_vid_params[:place]}.merge prmret
    end

    # Sets @hsmain and @hstra and @prms_all from params
    #
    # +action_name+ (+create+ ?) is checked inside!
    #
    # @return NONE
    def model_params_multi
      hsall = set_hsparams_main_tra(:harami_vid) # defined in application_controller.rb
    end

    def _preprocess_create
      _associate_channel  # "form_channel_owner", "form_channel_type", "form_channel_platform"
      _find_or_initialize_artist   # "artist_name"
      _associate_music             # "music_name"
    end

    [
    "event_ids", "artist_name", "form_engage_hows", "form_engage_year", "form_contribution",
    "artist_name_collab", "form_instrument", "form_play_role",
    "music_name", "music_timing", "uri_playlist_en", "uri_playlist_ja",]

    def _associate_channel
      hs_in = %w(owner type platform).map{ |ek|
        s="channel_"
        klass = s.camelize.contantize
        tmp_id = @prms_all["form_"+s+ek] # e.g., form_channel_platform
        val = klass.find_by_id(tmp_id.to_i) if tmp_id
        val ||= klass.default(:HaramiVid)
        [s+ek, val]
      }.to_hs

      self.unsaved_channel = Channel.find_or_initialize_by(**hs_in)
    end

    def _find_or_initialize_artist
      artist = BaseMergesController.other_model_from_ac(Artist.new, @hsmain[:artist_name], controller: self)
      if !artist
        artist = Artist.new(sex: Sex.unknown)
        tit = Artist.resolve_base_with_translation_with_id_str(@hsmain[:artist_name])
        lcode = (contain_asian_char(tit) ? "ja" : "en")
        artist.unsaved_translations << Translation.new(title: tit, langcode: lcode, is_orig: true)
      end
      self.unsaved_artist = artist
    end

    def _associate_music
      music = BaseMergesController.other_model_from_ac(Music.new, @hsmain[:music_name], controller: self)
      if !music
        music = Music.new(sex: Sex.unknown)
        tit = Music.resolve_base_with_translation_with_id_str(@hsmain[:music_name])
        lcode = (contain_asian_char(tit) ? "ja" : "en")
        music.unsaved_translations << Translation.new(title: tit, langcode: lcode, is_orig: true)
      end
      self.unsaved_music = music
    end

#    21:18:01 web.1  | E, [2024-04-26T21:18:01.793615 #15373] ERROR -- : params that caused Error: #<ActionController::Parameters {"authenticity_token"=>"vXemGMOJoVf8XIu-9cPlPj9QPMclsq63rqimxEhVtZLO9zCmahWNZdeCCF1F3z3lmo8TGi9fm9yLAW6LqM4rpA", "harami_vid"=>#<ActionController::Parameters {"langcode"=>"ja", "title"=>"", "uri"=>"", "release_date(1i)"=>"2024", "release_date(2i)"=>"4", "release_date(3i)"=>"26", "duration"=>"", "place.prefecture_id.country_id"=>"0", "place.prefecture_id"=>"", "place"=>"", "form_channel_owner"=>"3", "form_channel_type"=>"12", "form_channel_platform"=>"1", "event_ids"=>[""], "artist_name"=>"", "form_engage_hows"=>"72", "form_engage_year"=>"", "form_contribution"=>"", "artist_name_collab"=>"", "form_instrument"=>"2", "form_play_role"=>"2", "music_name"=>"", "music_timing"=>"", "uri_playlist_en"=>"", "uri_playlist_ja"=>"", "note"=>""} permitted: true>, "commit"=>"登録する", "controller"=>"harami_vids", "action"=>"create", "locale"=>"ja"} permitted: true>

end
