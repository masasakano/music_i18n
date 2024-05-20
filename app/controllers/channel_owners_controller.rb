# coding: utf-8
class ChannelOwnersController < ApplicationController
  #before_action :set_channel_owner, only: %i[ show edit update destroy ]
  load_and_authorize_resource except: [:create] # This sets @channel_owner
  before_action :model_params_multi, only: [:create, :update]

  # PARAMS KEY for Auto-Complete Artist
  PARAMS_KEY_AC = ChannelOwner::PARAMS_KEY_AC

  # Symbol of the main parameters in the Form (except "place_id"), which exist in DB
  MAIN_FORM_KEYS = %i(themselves artist_id artist_with_id note) + [PARAMS_KEY_AC]  # artist_id is hidden

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = MAIN_FORM_KEYS
  # these will be handled in model_params_multi()

  # GET /channel_owners or /channel_owners.json
  def index
    @channel_owners = ChannelOwner.all
  end

  # GET /channel_owners/1 or /channel_owners/1.json
  def show
  end

  # GET /channel_owners/new
  def new
    @channel_owner = ChannelOwner.new
  end

  # GET /channel_owners/1/edit
  def edit
  end

  # POST /channel_owners or /channel_owners.json
  def create
    @channel_owner = ChannelOwner.new(@hsmain)
    authorize! __method__, @channel_owner

    artist_in = _get_equivalent_artist

    if artist_in
      @channel_owner.artist = artist_in
      @channel_owner.set_unsaved_translations_from_artist  # set @unsaved_translations referring to the Artist
      #@channel_owner.unsaved_translations = _unsaved_translations_equivalent_artist(artist_in)
    else
      # Even if @channel_owner.errors.any?, it is better to set unsaved_translation so the input strings in the forms are preserved.
      add_unsaved_trans_to_model(@channel_owner, @hstra) # defined in application_controller.rb
    end

    result = def_respond_to_format(@channel_owner)       # defined in application_controller.rb

    # Adjusts each Translation's update_user and updated_at if there is an equivalent user.
    # These are not critical and so not included in DB-Transaction in the save above.
    if result && @channel_owner.artist
      _update_user_for_equivalent_artist(@channel_owner.artist)
    end
  end

  # PATCH/PUT /channel_owners/1 or /channel_owners/1.json
  def update
      @hsmain.each_pair do |ek, ev|
        next if "artist_id" == ek.to_s
        @channel_owner.send(ek.to_s+"=", ev)
      end
    artist_in = _get_equivalent_artist
    if artist_in
      @channel_owner.artist = artist_in
    elsif !@channel_owner.themselves
      @channel_owner.artist = nil
    end

    result = def_respond_to_format(@channel_owner, :updated){
      #@channel_owner.update(@hsmain)
      @channel_owner.synchronize_translations_to_artist
      @channel_owner.save
    } # defined in application_controller.rb

    # Assign the equivalent user if there is any and adjusts each Translation's update_user and updated_at
    # These are not critical and so not included in DB-Transaction in the save/update above.
    if result && @channel_owner.artist
      @channel_owner.translations.reset
      _update_user_for_equivalent_artist(@channel_owner.artist)  # adjust update_user and updated_at
    end
  end

  # DELETE /channel_owners/1 or /channel_owners/1.json
  def destroy
    def_respond_to_format_destroy(@channel_owner)  # defined in application_controller.rb
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_channel_owner
      @channel_owner = ChannelOwner.find(params[:id])
    end

    # Sets @hsmain and @hstra and @prms_all from params
    #
    # +action_name+ (+create+ ?) is checked inside!
    #
    # @return NONE
    def model_params_multi
      hsall = set_hsparams_main_tra(:channel_owner) # defined in application_controller.rb
    end


    # @return [Artist, NilClass] Artist if :artist_with_id is specified through UI.
    def _get_equivalent_artist
      #if @hsmain[PARAMS_KEY_AC].present?   # @channel_owner.send(PARAMS_KEY_AC) is defined for create but NOT for update
      if @channel_owner.send(PARAMS_KEY_AC).present?   # is defined for create but NOT for update
        if !@channel_owner.themselves  # convert_param_bool(@prms_all[:themselves], true_int: 1)
          flash[:warning] ||= []
          flash[:warning] << "Specified equivalent Artist is ignored because they are specified to be not equivalent."
        else
          artist = BaseMergesController.other_model_from_ac(Artist.new, @prms_all[PARAMS_KEY_AC], controller: self)
          if !artist
            @channel_owner.errors.add PARAMS_KEY_AC, " No existing Artist is found."
          end
        end
      elsif @channel_owner.themselves && !@channel_owner.artist  # the latter for update
        @channel_owner.errors.add PARAMS_KEY_AC, " must be specified when themselves? is checked."
      end
      artist
    end
  
    # @return [Array<Translation>] Unsaved translations copied from the those of the equivalent Artist
    def _unsaved_translations_equivalent_artist(artist)
      # a set of nearly identical translations
      artist.translations.map{|etrans|
        new_trans = etrans.dup
        new_trans.translatable = nil
        new_trans
      }
    end
  
    # Adjusts each Translation's update_user and updated_at
    #
    # @note updated_at is adjusted while created_at stays — meaning it makes
    #   updated_at < created_at because the Translation for ChannelOwner
    #   was newly created whereas the corresponding Translation for Artist
    #   was last updated (long time) before.
    #
    # @param artist [Artist] the equivalent Artist to self (ChannelOwner).
    # @return [void]
    def _update_user_for_equivalent_artist(artist)
      @channel_owner.translations.reset
      artist.best_translations.each_pair do |lc, etrans|
        #hs = ["", "alt_"].map{ |prefix|
        #  %w(title ruby romaji).map{ |base|
        #    metho = prefix+base
        #    [metho, etrans.send(metho)]
        #  }
        #}.inject([],:+).to_h
        #tra_cowner = @channel_owner.translations.find_by(hs)

        hs = %w(update_user_id updated_at).map{ |metho|
          [metho, etrans.send(metho)]
        }.to_h
        @channel_owner.best_translations[lc].update_columns(hs)  # skips all validations AND callbacks
      end
    end

end

# Parameters: {"authenticity_token"=>"[FILTERED]", "channel_owner"=>{"langcode"=>"ja", "title"=>"", "ruby"=>"", "romaji"=>"", "alt_title"=>"", "alt_ruby"=>"", "alt_romaji"=>"", "themselves"=>"0", "artist_with_id"=>"", "artist_id"=>"", "note"=>""}, "commit"=>"Submit", "locale"=>"en"}

