class ArtistMusicPlays::EditMultisController < ApplicationController
  include ModuleCommon # for split_hash_with_keys
  include ApplicationHelper # for get_bool_from_params

  before_action :set_params, only: %i(index edit create update show)  # This also authorize!
  load_and_authorize_resource :artist_music_play, only: %(create)

  # Basic Keys directly under :artist_music_play
  BASIC_KEYS  = %i(event_item_id artist_id music_id)

  # Nested Keys under :artist_music_play for a Hash of integer-like-string keys to a value
  NESTED_KEYS = %i(play_role_id instrument_id contribution_artist cover_ratio note to_destroy)

  # GET parameters of {EventItem}, {Artist} and {Music} IDs are mandatory.
  def index
  end

  # show is necessary as the fallback from update
  def show
  end

  def edit
  end

  def update
    update_or_create
  end

  def create
    update_or_create
  end

  def update_or_create
    return do_format_html if @amp.errors.present?

    stats = {
      created: [],  # Created ArtistMusicPlay-s
      updated: [],  # Updated ArtistMusicPlay-s
      untouched: [],  # Unchanged ArtistMusicPlay-s
      n_destroyed: nil,
    }

    begin
      ActiveRecord::Base.transaction(requires_new: true) do
        # destroys some existing records first (to avoid potential restrictions on create, if any).
        stats[:n_destroyed] = destroy_amps

        @amps.each do |eamp|
          key, verb = (eamp.new_record? ? [:created, "Creating"] : [:updated, "Updating"])
          if !significantly_changed?(eamp)  # defined in module_common.rb
            stats[:untouched] << eamp
            next
          end

          result = eamp.save

          if result
            stats[key] << eamp
            next
          end

          msg = "ERROR(#{__method__}): #{verb} ArtistMusicPlay failed: #{eamp.inspect}"
          logger.error msg
          @amp.copy_errors_from(eamp)  # defined in application_record.rb
          raise ActiveRecord::Rollback, msg+" Forced rollback." 
        end
      end
    rescue => err
      ## Transaction or processing failed with an uncaught error...
      msg = sprintf "(%s#%s) ArtistMusicPlay-s failed to be updated by User(ID=%s) with error: %s", self.class.name, __method__, current_user.id, err.message
      logger.error msg
      raise
    end

    do_format_html(stats)
  end


  # @param stats [Hash, NilClass] #see update_or_create
  #    Not used if in error.
  def do_format_html(stats=nil)
    if @amp && @amp.errors.present?
      respond_to do |format|
        format.html { render :index, status: :unprocessable_entity}  # A bit unusual, but render :index
        format.json { render json: @amp.errors, status: :unprocessable_entity }
      end
    else
      msg = sprintf "Created %d, updated %d, and destroyed %d ArtistMusicPlays successfully.", stats[:created].size, stats[:updated].size, stats[:n_destroyed]

      respond_to do |format|
        format.html { redirect_to event_item_path(@event_item), success: msg } # "success" defined in /app/controllers/application_controller.rb
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    #
    # Sets @templates (permitted params), @amp (ArtistMusicPlay), @amps (ArtistMusicPlay-s),
    # @to_destroys (Array), @event_item, @music, @artist
    #
    # Params:
    #   Parameters: {"authenticity_token"=>"[FILTERED]", "artist_music_play"=>{"event_item_id"=>"20", "artist_id"=>"1227", "music_id"=>"2244", "play_role_id"=>{"4"=>"2", "0"=>"4"}, "instrument_id"=>{"4"=>"2", "0"=>"5"}, "contribution_artist"=>{"4"=>"", "0"=>""}, "cover_ratio"=>{"4"=>"", "0"=>""}, "note"=>{"4"=>"", "0"=>""}}, "to_destroy"=>{"4"=>"true"}, "commit"=>"Submit", "id"=>"4", "locale"=>"en"}
    # where the ID(s) of the existing ArtistMusicPlay-s is 4 in this case, and
    # that for the new record is 0 by definition (in this code).
    #
    # NOTE: if the checkbox is not checked, the key "to_destroy" does NOT exist.
    #    The values should exist for the other parameters should exist.
    #    In the above, ["to_destroy"]["0"] does not exist because a new record cannot be destroyed.
    def set_params
      if params[:id].present? && !@amp
        # show, edit, update
        @amp = ArtistMusicPlay.find(params[:id]) 
        authorize!(action_name.to_sym, @amp)
      elsif !@authorized
        # index, create
        authorize!(action_name.to_sym, ArtistMusicPlay)
      end

      # Set instance variable @templates
      _build_templates

      @event_item  = (@amp ? @amp.event_item : EventItem.find(@templates[:event_item_id]))
      @music       = (@amp ? @amp.music      : Music.find(@templates[:music_id]))
      @artist      = (@amp ? @amp.artist     : Artist.find(@templates[:artist_id]))
      raise "Essential parameters are missing for some reason: #{[@event_item, @music, @artist].inspect}" if !@event_item || !@music || !@artist

      # sets @amp and @amps (the latter is an Array (former) or relation (latter) of ArtistMusicPlay-s
      # Also @amp.errors may be set.
      if @templates.has_key?(:play_role_id) && @templates[:play_role_id].respond_to?(:keys)
        _set_artist_music_plays_for_save  # create, update; sets @to_destroys
      else
        _set_artist_music_plays_for_form  # new, edit
        @to_destroys = nil
      end

      @amp_others = ArtistMusicPlay.where(event_item: @event_item)
      @amp_others = @amp_others.where.not(id: @amp.id) if @amp.id
    end

    # Set instance variable @templates (from params in the first-time call) or @amp (after failed create)
    def _build_templates
      case action_name
      when "index", "new"
        @templates = params.require(:artist_music_play).permit(*BASIC_KEYS)
      when "edit", "show"
        @templates = ((pms=params.permit(:artist_music_play)[:artist_music_play]) ? pms.permit(*BASIC_KEYS) : {})
      else
        nested_permits = NESTED_KEYS.map{|i| [i, {}]}.to_h
        @templates = params.require(:artist_music_play).permit(*BASIC_KEYS, **nested_permits).tap{|prms| prms.require([:play_role_id, :instrument_id])}
      end
    end

    # Set instance variables from @templates (from params in the first-time call) or @amp (after failed create)
    def _set_artist_music_plays_for_form
      @amps = ArtistMusicPlay.where(event_item: @event_item, music: @music, artist: @artist).joins(:play_role).joins(:instrument).order('play_roles.weight', 'instruments.weight')

      raise "Wrong ArtistMusicPlay is specified for some reason. contac the code developer. amp=#{@amp.inspect}" if @amp && !@amps.include?(@amp) 

      @amp ||= (@amps.exists? ? @amps.first : ArtistMusicPlay.new(event_item: @event_item, music: @music, artist: @artist))
      # If there is no existing ArtistMusicPlay (namely, complete "create"), a dummy is given,
      # which is passed to simple_form.
      # View ignores the dummy (aka new_record?) ArtistMusicPlay.
    end

    def _set_artist_music_plays_for_save
      @amps = []
      all_amp_ids = @templates[:play_role_id].keys  # Integer-like String
      err_infos = {}  # Hash of ID(String) => {column_name => Error-message}

      all_amp_ids.each do |eamp_id|
        nested_cols = NESTED_KEYS.excluding(:to_destroy).map{|ek| [ek, @templates[ek][eamp_id.to_s]]}.to_h  # Symbol keys

        if "0" == eamp_id
          stats = %i(play_role_id instrument_id).map{|ek| [ek, @templates[ek].has_key?("0") && @templates[ek]["0"].present?]}.to_h
          next if (vals=stats.values).all?{|i| false == i}  # New ArtistMusicPlays record is not specified.
          if !vals.all?
            # Inconsistently specified
            err_infos[eamp_id] ||= {}
            err_infos[eamp_id] = stats.select{|_, v| !v}.map{|k, _| [k, " must be specified (together with #{("instrument_id" == k.to_s) ? "PlayRole" : "Instrument"})."]}.to_h
            next
          end

          hsin = BASIC_KEYS.map{|ek| [ek, @templates[ek]]}.to_h
          hsin.merge! nested_cols
          @amps << ArtistMusicPlay.new(**hsin)
          next
        end

        amp = ArtistMusicPlay.find eamp_id

        # sanity checks
        BASIC_KEYS.each do |ek|
          raise "Inconsistent basic parameters (#{ek.inspect}): #{[@templates[ek], amp.send(ek)].inspect}" if @templates[ek].to_i != amp.send(ek)
        end

        amp.attributes = nested_cols
        @amps << amp
      end

      @amp ||= ((@amp || !@amps.empty?) ? @amps.first : ArtistMusicPlay.new(event_item: @event_item, music: @music, artist: @artist)) # the last one is a dummy record
      add_errors(err_infos)  # add errors, if any, to @amp

      # Array
      @to_destroys =
        if @templates[:to_destroy].present?
          @templates[:to_destroy].to_h.find_all{|ek, ev| get_bool_from_params(ev) }.map(&:first)  # defined in application_helper.rb
        else
          []
        end
    end

    # @amp.errors.add
    #
    # @note
    #   It seems it is not possible to specify a complicated column name in the form
    #   so the field is marked...
    #
    # @param err_infos [Hash<String => Hash<String,Symbol => String>>] Hash of ArtistMusicPlay#ID(String) => {column_name => Error-message}
    def add_errors(err_infos)
      err_infos.each_pair do |eid, ea_errs|
        ea_errs.each_pair do |colname, msg|
          # field_id = sprintf("%s_%s", colname, eid)
          field_id = sprintf("%s"+((0 == eid.to_i) ? "-new" : ""), colname.to_s)
          @amp.errors.add field_id, msg.sub(/\A */, ": ")
        end
      end
    end

    # Destory specified ArtistMusicPlays, providing they satisfy certain conditions
    # (no conditions at the moment).
    #
    # @return [Integer] Number of the destroyed records.
    # @raise [ActiveRecord::Rollback] if one of destroying fails
    def destroy_amps
      @to_destroys.each do |eid|
        result = (eamp=ArtistMusicPlay.find(eid)).destroy
        if !result
          msg = "ERROR(#{__method__}): Destroying ArtistMusicPlay failed for some reason: #{eamp.inspect}"
          logger.error msg
          eamp.errors.full_messages.each do |ems|
            @amp.errors.add :base, ems
          end
          raise ActiveRecord::Rollback, msg+" Forced rollback." 
        end
      end

      return @to_destroys.size
    end
end
