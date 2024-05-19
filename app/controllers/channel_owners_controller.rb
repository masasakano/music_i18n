# coding: utf-8
class ChannelOwnersController < ApplicationController
  #before_action :set_channel_owner, only: %i[ show edit update destroy ]
  load_and_authorize_resource except: [:create] # This sets @channel_owner
  before_action :model_params_multi, only: [:create, :update]

  # params key for auto-complete Artist
  PARAMS_KEY_AC = BaseMerges::BaseWithIdsController.formid_autocomplete_with_id(Artist).to_sym

  # Symbol of the main parameters in the Form (except "place_id"), which exist in DB
  MAIN_FORM_KEYS = %i(themselves artist_id note)

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = MAIN_FORM_KEYS + [PARAMS_KEY_AC] # == :artist_with_id
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
      @channel_owner.set_unsaved_translations_from_artist
      #@channel_owner.unsaved_translations = _unsaved_translations_equivalent_artist(artist_in)
    else
      # Even if @channel_owner.errors.any?, it is better to set unsaved_translation so the input strings in the forms are preserved.
      add_unsaved_trans_to_model(@channel_owner, @hstra) # defined in application_controller.rb
    end
    result = def_respond_to_format(@channel_owner)       # defined in application_controller.rb

    # Adjusts each Translation's update_user and updated_at if there is an equivalent user.
    if result && @channel_owner.artist
      _update_user_for_equivalent_artist(@channel_owner.artist)
    end
  end

  # PATCH/PUT /channel_owners/1 or /channel_owners/1.json
  def update
    artist_in = _get_equivalent_artist
    @channel_owner.artist = artist_in if artist_in

    result = def_respond_to_format(@channel_owner, :updated){
      #@channel_owner.update(@hsmain)
      @hsmain.each_pair do |ek, ev|
        @channel_owner.send(ek.to_s+"=", ev)
      end
      @channel_owner.synchronize_translations_to_artist
      @channel_owner.save
    } # defined in application_controller.rb

    # Assign the equivalent user if there is any and adjusts each Translation's update_user and updated_at
    if result && @channel_owner.artist
      #@channel_owner.translations.destroy_all
      #_unsaved_translations_equivalent_artist(artist).each do |trans|
      #  @channel_owner.translations << trans
      #end
      #@channel_owner.reload
      @channel_owner.translations.reset
      _update_user_for_equivalent_artist(@channel_owner.artist)
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
      if @prms_all[PARAMS_KEY_AC].present?
        if !convert_param_bool(@prms_all[:themselves], true_int: 1)
          flash[:warning] ||= []
          flash[:warning] << "Specified equivalent Artist is ignored because they are specified to be not equivalent."
        else
          artist = BaseMergesController.other_model_from_ac(Artist.new, @prms_all[PARAMS_KEY_AC], controller: self)
          if !artist
            @channel_owner.errors.add PARAMS_KEY_AC, "No existing Artist is found."
          end
        end
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
      artist.translations.each do |etrans|
        hs = ["", "alt_"].map{ |prefix|
          %w(title ruby romaji).map{ |base|
            metho = prefix+base
            [metho, etrans.send(metho)]
          }
        }.inject([],:+).to_h
        tra_cowner = @channel_owner.translations.find_by(hs)
  
        hs = %w(update_user_id updated_at).map{ |metho|
          [metho, etrans.send(metho)]
        }.to_h
        tra_cowner.update_columns(hs)  # skips all validations AND callbacks
      end
    end

end

