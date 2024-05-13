# coding: utf-8
class HaramiVidsController < ApplicationController
  include ModuleCommon  # for contain_asian_char

  skip_before_action :authenticate_user!, :only => [:index, :show]
  load_and_authorize_resource except: [:index, :show, :create] # This sets @harami_vid
  before_action :set_harami_vid, only: [:show]  # load_and... would load a model for  :edit, :update, :destroy
  before_action :model_params_multi, only: [:create, :update]
  before_action :set_event_event_items, only: [:show, :edit]  # sets @event_event_items
  before_action :set_countries, only: [:new, :create, :edit, :update] # defined in application_controller.rb

  # params key for auto-complete Artist
  PARAMS_KEY_AC = BaseMerges::BaseWithIdsController.formid_autocomplete_with_id(Artist).to_sym

  # Symbol of the main parameters in the Form (except "place" (or "place_id"?)), which exist in DB or as setter methods
  MAIN_FORM_KEYS = %i(uri duration note) + [
    "form_channel_owner", "form_channel_type", "form_channel_platform",
    "form_new_event",
    "artist_name", "artist_sex", "form_engage_hows", "form_engage_year", "form_engage_contribution",
    "artist_name_collab", "form_instrument", "form_play_role",
    "music_name", "music_timing", "music_genre", "music_year",
    "form_new_artist_collab_event_item",
    "uri_playlist_en", "uri_playlist_ja",
    "release_date(1i)", "release_date(2i)", "release_date(3i)",  # Date-related parameters
  ]

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = MAIN_FORM_KEYS + [
    # "event_item_ids",  # This is a key for an Array, hence defined in model_params_multi
  ] + [PARAMS_KEY_AC] + PARAMS_PLACE_KEYS
  # these will be handled in model_params_multi()
  # See {#create} for description of "place_id" and "place".  In short, the best strategy is
  # to use @hsmain["place_id"] (or @hamsin[:place_id]), while that in params is "place".

  # Form-ID for the new EventItem in the EventItem selection for a new collab-Artist
  DEF_FORM_NEW_ARTIST_COLLAB_EVENT_ITEM_NEW = 0

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
    @places = Place.all  # necessary??
  end

  # GET /harami_vids/1/edit
  def edit
    @places = Place.all  # necessary??
  end

  # POST /harami_vids
  # POST /harami_vids.json
  def create
    #@harami_vid = HaramiVid.new(sliced_harami_vid_params)
    @harami_vid = HaramiVid.new(@hsmain)  # This sets most of the form parameters
    authorize! __method__, @harami_vid
    ## "place" is tricky
    # The original form ID is "place".  To change it is tricky, as everything, including JavaScript
    # must be consistent throughout.
    #
    # Because of how the cascade Form is set, "place" can be insignificant, whereas
    # Country etc is significant.  Weiredly, SimpleForm seems to return a "String" of
    # something like "Place<242aba232>" for "place" when the value is insignificant.
    #
    # set_hsparams_main_tra() defined in application_controller.rb called from
    # this model_params_multi() deals with it. Basically, it sets an Integer (ID of Place)
    # to "place_id"; which is set to @harami_vid above.  So, make sure to refer to "place_id"
    # as opposed to "place".

    add_unsaved_trans_to_model(@harami_vid, @hstra) # defined in application_controller.rb
    def_respond_to_format(@harami_vid){  # defined in application_controller.rb
      create_update_core{
        @harami_vid.save
      }
    }
  end

  # PATCH/PUT /harami_vids/1
  # PATCH/PUT /harami_vids/1.json
  def update
    def_respond_to_format(@harami_vid, :updated){
      create_update_core{
        @harami_vid.update(@hsmain)
      }
    } # defined in application_controller.rb
  end

  # DELETE /harami_vids/1
  # DELETE /harami_vids/1.json
  def destroy
    def_respond_to_format_destroy(@harami_vid)  # defined in application_controller.rb
  end

  ###########################################################################
  private
  ###########################################################################

    def grid_params
      params.fetch(:harami_vids_grid, {}).permit!
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_harami_vid
      @harami_vid = HaramiVid.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def harami_vid_params
      params.require(:harami_vid).permit(:release_date, :duration, :uri, :"place.prefecture_id.country_id", :"place.prefecture_id", :place, :place_id, :flag_by_harami, :uri_playlist_ja, :uri_playlist_en, :artist, :engage_how2, :music, :music_timing, :channel, :note)
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
      @event_event_items = {}  # {Event-ID => EventItems-Relation} for update
      @assocs = {}.with_indifferent_access  # associated models (like assocs[:music]), maybe newly created.
      hsall = set_hsparams_main_tra(:harami_vid, array_keys: [:event_item_ids]) # defined in application_controller.rb
    end

    # Set @event_event_items
    def set_event_event_items
      @event_event_items ||= {}  # This is not defined for "show"
      @harami_vid.events.order("start_time", "duration_hour").each do |event|
        @event_event_items[event.id] = event.event_items.order("event_items.start_time", "duration_minute")
      end
    end

    ###########################

    # Core routine for create and update
    #
    # @note uri is normalized by {HaramiVid#normalize_uri} before-validation callback.
    #
    # @return [Boolean] to pass to +respond_to+
    # @yield Either +@harami_vid.save+ or +@harami_vid.update(@hsmain)+. The returned valud should
    #   be false if the action fails.
    def create_update_core
      raise if !block_given?  # sanity check
      result = nil
      ActiveRecord::Base.transaction(requires_new: true) do
        begin
          find_or_create_channel_and_associate  # a new Channel may be created - make sure to rollback if something goes wrong
            # This may set @harami_vid.errors in an unlikely case (surely not with UI, though!)
          result = yield
          rollback_clear_flash if !result  # no more processing is needed anyway.
          [:find_or_create_music,    # @assocs[:music]
           :find_or_create_harami_vid_music_assoc, # @assocs[:harami_vid_music_assoc]
           :find_or_create_artist,   # @assocs[:artist]
           :find_or_create_engage,   # @assocs[:engage]
           :find_or_artist_collab,   # @assocs[:artist_collab]
           :update_event_item_assocs,# @assocs[:destroyed_event_items]  # for update only
           :create_an_event_item,    # @assocs[:new_event_item]  # See this method for the algorithm
           :associate_an_event_item, # @assocs[:artist_music_play]  # used for some case of "update" only
          ].each do |task|
            self.send task
            rollback_clear_flash if @harami_vid.errors.any?
          end
          if @assocs[:artist_collab].present? && @assocs[:music].blank?
            @harami_vid.errors.add :artist_name_collab, I18n.t("harami_vids.warn_collab_without_music")  # Valid Music must be given when you add an Artist-to-collaborate.
            result = false
            raise ActiveRecord::Rollback, "Force rollback."
          end
        rescue => err
          result = false
          raise ActiveRecord::Rollback, "Force rollback."
        ensure
          result = false if @harami_vid.errors.any?  # errors may be set by any of the "around"-processes
        end
      end
      result
    end # def create_update_core

    # DB rollback and clear previous flashes
    def rollback_clear_flash
      if flash[:notice] && flash[:notice].respond_to?(:push)
        flash[:notice].delete_if{|ec|
          %r@<a [^>]*href="/channels/\d+[^>]*>new Channel.+is created@ =~ ec
        }
      end
      raise ActiveRecord::Rollback, "HaramiVid was not created; hence rollback to cancel the potential creation of Channel."
    end

    # Find or create a Channel and asociate it to HaramiVid
    #
    # If not finding yet failing to create a new Channel,
    # errors are added to @harami_vid
    # This method associates a new or identified Channel to @harami_vid.channel
    #
    # The new Channel is automatically associated with Translations.
    #
    # @return [Channel, NilClass] nil if failed to save.
    def find_or_create_channel_and_associate
      ar_in = %w(owner type platform).map{ |ek|
        snake="channel_"+ek  # snake case
        klass = snake.camelize.constantize
        tmp_id = @hsmain["form_"+snake] # e.g., form_channel_platform
        val = klass.find_by_id(tmp_id.to_i) if tmp_id.present?
        # val ||= klass.default(:HaramiVid)  # Invalid ID should never be specified via UI!
        [snake, val]
      }

      raise "Bad Channel-related parameters specified." if ar_in.any?{|ea| !ea[1]}  # b/c this should never happen via UI! I don't care what screen follows to the user/robot who submitted such a request.
      chan = Channel.find_or_initialize_by(**(ar_in.to_h))
      if chan.new_record?
        return if !_save_new_channel_or_error(chan)
        _after_save_new_channel(chan)
      end
      @harami_vid.channel = chan
    end

    # @param chan [Channel] all parameters but translations should be filled.
    # @return [Channel, NilClass] nil if failed to save.
    def _save_new_channel_or_error(chan)
      chan.unsaved_translations = chan.def_initial_translations
      _save_or_add_error(chan, form_attr: :base)
    end
    private :_save_new_channel_or_error

    # Attempts to save and if fails, add errors to @harami_vid
    #
    # Checkk the result with @harami_vid.errors.any?
    #
    # @param model [ApplicationRecord]
    # @param form_attr [Symbol] usually the form's name
    # @return [ApplicationRecord, NilClass] nil if failed to save.
    def _save_or_add_error(model, form_attr: :base)
      return model if model.save  # The returned value is not used apart from its trueness.

      # With UI, the above save should not usually fail (it is never with Channel, probably not for Music).
      model.errors.full_messages.each do |msg|
        @harami_vid.errors.add form_attr, "Existing #{model.class.name} is not found, yet failed to create a new one: "+msg
      end
      return
    end
    private :_save_or_add_error

    # after-processing of a new Channel
    def _after_save_new_channel(chan)
      flash[:notice] ||= []
      chan_new_str = sprintf("%s - %s by %s", *(%w(platform type owner).map{|i| chan.send("channel_"+i).title_or_alt(langcode: I18n.locale, lang_fallback_option: :either, str_fallback: "", article_to_head: true)}))
      s = "new Channel"
      msg = sprintf("A %s (%s) was created.", (can?(:show, chan) ? view_context.link_to(s, channel_path(chan), target: "_blank") : s), chan_new_str).html_safe  # This html_safe is processed in def_respond_to_format in application_controller.rb
      flash[:notice] << msg

      chan.reload  # to load Translation
      msglog = (sprintf("INFO: a new Channel (ID=%d, title=%s) is automatically created as a result of the creation of a new HaramiVid (%s) by user ID=(%d), thouth it may be cancelled (rollback) later.",
                        chan.id, chan.title.inspect, @harami_vid.title, current_user.id) rescue msg)  # "rescue" just$to play safe
      logger.info msglog
    end
    private :_after_save_new_channel

    # Set @assocs[:music]
    # @return [Music, NilClass] nil if failed to save Music or not specified in the first place.
    def find_or_create_music
      prm_name = "music_name"
      raise "hsmain=#{@hsmain.inspect}" if !@hsmain.has_key?(prm_name)  # sanity check

      @assocs[:music] = nil
      return if @hsmain[prm_name].blank?

      extra_prms_for_new = {
        genre: (((genid=@hsmain[:music_genre]).present? ? Genre.find_by_id(genid.to_i) : nil) || Genre.unknown),  # with UI, should be always found
        year:   ((year=@hsmain[:music_year]).present? ? year.to_i : nil),  # can be nil
      }
      @assocs[:music] = _find_or_create_artist_or_music(Music, prm_name, extra_prms_for_new)  # can be nil.
    end

    # Set @assocs[:music] and @assocs[:harami_vid_music_assoc]
    # @return [HaramiVidMusicAssoc, NilClass] nil if failed to save either of Music and HaramiVidMusicAssoc or not specified in the first place.
    def find_or_create_harami_vid_music_assoc
begin  # for DEBUGging
      prm_name = "music_timing"
      return (@assocs[:harami_vid_music_assoc]=nil) if @assocs[:music].blank?

      @assocs[:harami_vid_music_assoc] = HaramiVidMusicAssoc.find_or_initialize_by(harami_vid: @harami_vid, music: @assocs[:music])
        # Next one will be used for an existing record, too. (as a plan)
      @assocs[:harami_vid_music_assoc].timing = @hsmain[prm_name].to_i if @hsmain[prm_name].present?  # it has been validated to be numeric if present(???). TODO
      is_changed = @assocs[:harami_vid_music_assoc].changed?  # TODO: issue a flash notice for moderators
      _save_or_add_error(@assocs[:harami_vid_music_assoc], form_attr: prm_name.to_sym)
rescue => err
  print "DEBUG(#{File.basename __FILE__}:#{__method__}): Error is raised:\n ";p err
  raise
end
    end

    # Set @assocs[:artist]
    def find_or_create_artist
      prm_name = "artist_name"
      return(@assocs[:artist] = nil) if @hsmain[prm_name].blank?
      raise if @harami_vid.new_record?  # sanity check
      raise "ERROR: hsmain=#{@hsmain.inspect}" if !@hsmain.has_key?(prm_name)  # sanity check

      extra_prms_for_new = {
        sex: (((sexid=@hsmain[:artist_sex]).present? ? Sex.find_by_id(sexid.to_i) : nil) || Sex.unknown)  # with UI, should be always found
      }
      @assocs[:artist] = _find_or_create_artist_or_music(Artist, prm_name, extra_prms_for_new) # Set @assocs[:artist]
    end

    # Set @assocs[:artist_collab]
    def find_or_artist_collab
      prm_name = "artist_name_collab"
      raise "ERROR: hsmain=#{@hsmain.inspect}" if !@hsmain.has_key?(prm_name)  # sanity check

      return(@assocs[:artist_collab] = nil) if @hsmain[prm_name].blank?
      @assocs[:artist_collab] = _find_or_create_artist_or_music(Artist, prm_name, find_only: true)
      if @assocs[:artist_collab].present? && @assocs[:music].blank?
        flash[:warning] ||= []
        flash[:warning] << "Collab-Artist is ignored because Music is not specified."
      end
      @assocs[:artist_collab]
    end

    # Set @assocs[:engage]
    #
    # Assuming @assocs[:music] is already set
    def find_or_create_engage
begin  # for DEBUGging
      return if @assocs[:music].blank? || @assocs[:artist].blank?  # Music or Artist is not specified; hence nor Engage is set

      @assocs[:engage] = Engage.find_or_initialize_by(music: @assocs[:music], artist: @assocs[:artist])
      if @assocs[:engage].new_record?
        eh = ((pid=@hsmain[:form_engage_hows]).present? ? EngageHow.find_by_id(pid.to_i) : EngageHow.default(:HaramiVid))  # with UI, should be always found
        @assocs[:engage].engage_how = eh
        @assocs[:engage].year         = ((val=@hsmain[:form_engage_year]).present? ? val.to_i : nil)
        @assocs[:engage].contribution = ((val=@hsmain[:form_engage_contribution]).present? ? val.to_f : nil)
      end
      _save_or_add_error(@assocs[:engage])  # , form_attr: :base  # uncertain which parameter is wrong.
rescue => err
  print "DEBUG(#{File.basename __FILE__}:#{__method__}): Error is raised:\n ";p err
  raise
end
    end


    # Set @assocs[:music] or @new_artist
    # @param klass [Class] either Artist or Music
    # @param prm_key [String] form key like "artist_name"
    # @param extra_prms_for_new [Hash] e.g., {sex: Sex.unknown} to create an Artist
    # @return [ApplicationRecord, NilClass] either Music, Artist, or nil if faiiling to save
    # @raise [ActiveRecord::RecordNotFound] if a String containing the completely-wrong ID is passed,
    #    which should never happen with auto-complete or with a standard manual input in UI.
    def _find_or_create_artist_or_music(klass, prm_key, extra_prms_for_new={}, find_only: false)
      raise "hsmain=#{@hsmain.inspect}" if !@hsmain.has_key? prm_key  # sanity check
      # tit, _, _ = Artist.resolve_base_with_translation_with_id_str(@hsmain[prm_key])

      # getting an existing record (Music|Artist)
      existing_record = BaseMergesController.other_model_from_ac(klass.new, @hsmain[prm_key], controller: self)
      return existing_record if existing_record || find_only

      hs2pass = {
        title: @hsmain[prm_key],
        langcode: (contain_asian_char?(@hsmain[prm_key]) ? "ja" : "en"),
        is_orig: true,
      }

      new_record = klass.new(**(hs2pass.merge(extra_prms_for_new)))   # eg: Music.new
      ret = _save_or_add_error(new_record, form_attr: prm_key.to_sym) # eg: music
      (ret || new_record)
    end
    private :_find_or_create_artist_or_music

    # Update existing associations for EventItems
    #
    # For update only.
    # Sets @assocs[:destroyed_event_items], each element of which is
    # an Array of [id, machine_name, Event]
    #
    # Basically, all the EventItems that are *NOT* specified in :event_item_ids
    # are destroyed.
    def update_event_item_assocs
      @assocs[:destroyed_event_items] = nil
      return if "create" == action_name || !@prms_all[:event_item_ids]  # the latter should not be nil on update, but playing safe.
      @assocs[:destroyed_event_items] = []

      leaves = @prms_all[:event_item_ids].select{|i| i.present?}.map(&:to_i)
      if leaves.empty?
        @harami_vid.errors.add :event_item_ids, ": at least one of them must remain."
      end
      @harami_vid.reload
      @event_event_items.each_value do |rela_event_items|  # The key is ID for Event (identical to eeit.event.id), value is EventItem
        rela_event_items.each do |eeit|
          next if leaves.include?(eeit)  # Association not destroyed.
          @assocs[:destroyed_event_items].push [eeit.id, eeit.machine_name, eeit.event]
          next if @harami_vid.event_items.destroy(eeit)
          msg_core = sprintf("Event=%s, EventItem=%s",
                             eeit.event.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either).inspect,
                             eeit.machine_name.inspect
                            )
          @harami_vid.errors.add :event_item_ids, "Failed to destroy the association (#{msg_core})."
        end
      end
    end

    # Create an EventItem for a specified Event, if specified
    #
    # Creating an EventItem is mandatory for "create", but NOT for "update".
    #
    # == Algorithm
    #
    # 1. create_an_event_item (this method) / "form_new_event" / @assocs[:new_event_item] and in some cases @assocs[:artist_music_play]
    #    1. for "update", this can be nil. If so, skipped.
    #    2. for "update", if this parameter is specified
    #       1. If HaramiVid is not associated for "Unknown" EventItem for the Event, use it.
    #       2. Else, a new EventItem is created.
    #       3. If form_new_artist_collab_event_item is 0, follow the same processing as for "create".
    #       4. If not (i.e., the value is other than 0 (pID of an existing EventItem)), return from here.
    #    3. for "create", "Unknown" EventItem for the Event is used in principle.
    #       1. However, if artist-collab and music are specified and no new ArtistMusicPlay can be made with the EventItem (b/c the same combination has been defined for a different video etc), a new EventItem is created so that it allows a creation of the new ArtistMusicPlay.
    #       2. for "create", ArtistMusicPlay is created at this stage if artist-collab is specified.
    # 2. associate_an_event_item / / @assocs[:artist_music_play] (if not yet set)
    #    1. skip if "create" or @assocs[:artist_music_play] is already set or either of collab-artist and music is not specified.
    #    2. Else, a new entry of {ArtistMusicPlay} is created.
    #
    def create_an_event_item
begin
      #return if @assocs[:music].blank? || @assocs[:artist].blank?  # Music or Artist is not specified; hence nor Engage is set
      prm_name = "form_new_event"
      @assocs[:new_event_item] = nil

      evt_id=@hsmain[prm_name]
      if evt_id.blank?
        case action_name
        when "create"
          raise "Bad new Event parameter is specified."
          # b/c this should never happen via UI! I don't care what screen follows to the user/robot who submitted such a request.
        when "update"
          if DEF_FORM_NEW_ARTIST_COLLAB_EVENT_ITEM_NEW.to_i == @harami_vid.form_new_artist_collab_event_item.to_i && @assocs[:artist_collab].present?
            @harami_vid.errors.add :form_new_artist_collab_event_item, "is specified to be New, but no new Event is selected for it."
          end
          return
        else
          raise "Should never happen."
        end
      end

      event = Event.find(evt_id.to_i)  # should never fail via UI
      if event.unknown? && @harami_vid.place_id.present?
        event2 = Event.default(:HaramiVid, place: Place.find(@harami_vid.place_id.to_i))
        if !event2.new_record? || event2.save
          event = event2
          event.reload
        end
      end

      event_item_created = false  # Flag to tell whether a new EventItem has been created
      def_evit = event.unknown_event_item
      if "create" != action_name && @harami_vid.event_items.include?(def_evit)
        # A new EventItem is explicitly specified in update, yet the candidate "unknown" EventItem already exists.
        # Hence, a new EventItem is created.
        tit_tmp = def_evit.default_unique_title(prefix="user", postfix: :default)
        def_evit = EventItem.initialize_new_unknown(event)
        set_up_event_item_and_associate(def_evit)
        return false if def_evit.errors.include?(:new_event_item)  # Error in saving a new EventItem for some reason
        event_item_created = true
      end

      # If "update" and if the used specifies something different from "new EventItem" for the new artist-collab association,
      # skip the rest. The case will be handled in the next step of associate_an_event_item
      return if (s=@harami_vid.form_new_artist_collab_event_item) && DEF_FORM_NEW_ARTIST_COLLAB_EVENT_ITEM_NEW.to_i != s.to_i

      return set_up_event_item_and_associate(def_evit) if !@assocs[:artist_collab] || !@assocs[:music]

      instrument = ((val=@hsmain[:form_instrument]).blank? ? Instrument.default(:HaramiVid) : Instrument.find(val))
      play_role  = ((val=@hsmain[:form_play_role]).blank?  ? PlayRole.default(:HaramiVid)   : PlayRole.find(val))

      ar_event_item =
        if event_item_created
          # meaning this is in update, and the user explicitly specifies an Event (for the EventItem),
          # yet the default "unknown" EventItem is actually already associated to HaramiVid. Hence, a new one
          # has been already created.  This (being rare) has not been tested well at the time of writing!
          [def_evit]  # For this one, ArtistMusicPlay should be always able to be saved!
        else
          # In specifying a new EventItem, the user only specifies an Event, not EventItem.
          # Hence, we determine if we need to create a new EventItem or we can reuse an existing one.
          # Suppose there are multiple EventItems belonging to the Event
          event.event_items.sort{|a,b|
            if a == def_evit
              1   # Default one comes last
            elsif b == def_evit
              -1
            else
              a <=> b
            end
          }
        end

      ar_event_item.each do |ea_evit|
        can_do = _can_create_artist_music_play?(
          ea_evit,
          @assocs[:artist_collab],
          @assocs[:music],
          instrument,
          play_role
        )
        return set_up_event_item_and_amp(ea_evit, instrument, play_role) if can_do
      end

      # All existing EventItem-s violates unique conditions to create ArtistMusicPlay,
      # meaning those EventItem-s are not suitable to associate to the HaramiVid @harami_vid .
      # So creates a new EventItem
      @assocs[:new_event_item] = EventItem.initialize_new_unknown(event)
      _save_or_add_error(@assocs[:new_event_item])  # , form_attr: :base  # uncertain which parameter is wrong.

      set_up_event_item_and_amp( @assocs[:new_event_item], instrument, play_role)
rescue => err
  print "DEBUG(#{File.basename __FILE__}:#{__method__}): Error is raised:\n ";p err
  raise
end
    end

    # Associate a new EventItem (for "update"); sets @assocs[:artist_music_play] (if not yet)
    def associate_an_event_item
begin
      return if !@assocs[:artist_collab] || !@assocs[:music] || @assocs[:artist_music_play].present?
      return if @harami_vid.form_new_artist_collab_event_item.blank?  # or if "create" == action_name

      instrument = ((val=@hsmain[:form_instrument]).blank? ? Instrument.default(:HaramiVid) : Instrument.find(val))
      play_role  = ((val=@hsmain[:form_play_role]).blank?  ? PlayRole.default(:HaramiVid)   : PlayRole.find(val))

      event_item =
        if DEF_FORM_NEW_ARTIST_COLLAB_EVENT_ITEM_NEW.to_i == @harami_vid.form_new_artist_collab_event_item.to_i
          raise "contact the code developer (@assocs[:new_event_item] is unexpectedly blank)" if @assocs[:new_event_item].blank?  # This should never happen as it should have been caught at an early stage in the previous-step method: create_an_event_item
          @assocs[:new_event_item]
        else
          EventItem.find @harami_vid.form_new_artist_collab_event_item.to_i
        end

      form_attr = (("create" == action_name) ? :base : :form_new_artist_collab_event_item)
      associate_artist_music_play(instrument, play_role, event_item: event_item, form_attr: form_attr) # defines @assocs[:artist_music_play]
rescue => err
  print "DEBUG(#{File.basename __FILE__}:#{__method__}): Error is raised:\n ";p err
  raise
end
    end

    def set_up_event_item_and_associate(event_item)
      @assocs[:new_event_item] ||= event_item
      if event_item.new_record?
         event_item.publish_date ||= @harami_vid.release_date
         _save_or_add_error(event_item)
      end

      @harami_vid.event_items << event_item if !@harami_vid.event_items.include?(event_item)  # Added HaramiVidEventItemAssoc
    end

    def set_up_event_item_and_amp(event_item, instrument, play_role)
      set_up_event_item_and_associate(event_item)
      associate_artist_music_play(instrument, play_role)
    end

    def associate_artist_music_play(instrument, play_role, event_item: @assocs[:new_event_item], form_attr: :base)
      @assocs[:artist_music_play] =
        ArtistMusicPlay.new(
          event_item: event_item,
          artist:     @assocs[:artist_collab],
          music:      @assocs[:music],
          instrument: instrument,
          play_role:   play_role,
        )
      _save_or_add_error(@assocs[:artist_music_play], form_attr: form_attr)  # :base for create b/c uncertain which parameter is wrong.

      return if ArtistMusicPlay.where(event_item_id: event_item.id, music_id: @assocs[:music].id).count > 1

      @assocs[:artist_music_play_harami] =
        ArtistMusicPlay.new(
          event_item: event_item,
          artist:     Artist.default(:HaramiVid),
          music:      @assocs[:music],
          instrument: Instrument.default(:HaramiVid),
          play_role:  PlayRole.default(:HaramiVid),
        )
      _save_or_add_error(@assocs[:artist_music_play_harami])  # :base b/c uncertain which parameter is wrong.
    end

    def _can_create_artist_music_play?(event_item, artist, music, instrument, play_role)
      return true if [event_item, artist, music, instrument, play_role].any?{|i| !i.respond_to?(:id)}

      !(ArtistMusicPlay.where(
          event_item_id: event_item.id,
          artist_id: artist.id,
          music_id:  music.id,
          instrument_id: instrument.id,
          play_role_id:  play_role.id
        ).exists?)
    end
    private :_can_create_artist_music_play?

end

###########################
# params: {"_method"=>"patch", "authenticity_token"=>"[FILTERED]", "harami_vid"=>{"uri"=>"youtu.be/2EZ5-nyu1Dg", "release_date(1i)"=>"2024", "release_date(2i)"=>"5", "release_date(3i)"=>"10", "duration"=>"842.0", "place.prefecture_id.country_id"=>"5798", "place.prefecture_id"=>"6654", "place"=>"6749", "form_channel_owner"=>"3", "form_channel_type"=>"12", "form_channel_platform"=>"2", "event_item_ids"=>["", "20"], "form_new_event"=>"", "uri_playlist_en"=>"", "uri_playlist_ja"=>"", "note"=>"", "music_name"=>"", "music_year"=>"", "music_genre"=>"122", "music_timing"=>"", "artist_name"=>"", "artist_sex"=>"0", "form_engage_hows"=>"72", "form_engage_year"=>"", "form_engage_contribution"=>"", "artist_name_collab"=>"", "form_instrument"=>"2", "form_play_role"=>"2"}, "commit"=>"Update Harami vid", "controller"=>"harami_vids", "action"=>"update", "id"=>"1046", "locale"=>"en"}

