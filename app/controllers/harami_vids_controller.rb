# coding: utf-8
class HaramiVidsController < ApplicationController
  include ModuleCommon  # for contain_asian_char

  skip_before_action :authenticate_user!, :only => [:index, :show]
  load_and_authorize_resource except: [:index, :show, :create] # This sets @harami_vid for  :edit, :update, :destroy
  before_action :set_harami_vid, only: [:show]  # sets @harami_vid
  before_action :model_params_multi, only: [:create, :update]
  before_action :set_event_event_items, only: [:show, :edit, :update] # sets @event_event_items (which may be later overwritten if reference_harami_vid_id is specified)
  before_action :set_countries, only: [:new, :create, :edit, :update] # defined in application_controller.rb

  # params key for auto-complete Artist
  PARAMS_KEY_AC = BaseMerges::BaseWithIdsController.formid_autocomplete_with_id(Artist).to_sym

  # Symbol of the main parameters in the Form (except "place" (or "place_id"?)), which exist in DB or as setter methods
  # NOTE: "event_item_ids" is a key for an Array, hence defined separately in model_params_multi (as an exception)
  MAIN_FORM_KEYS = %i(uri duration note) + [
    "form_channel_owner", "form_channel_type", "form_channel_platform",
    "form_new_artist_collab_event_item", # which EventItem-ID (or new) is used to refer to the new EventItem and/or new Collab.
    "form_new_event",  # for Event-ID (NOT EventItem) for a new EventItem to add
    "artist_name", "artist_sex", "form_engage_hows", "form_engage_year", "form_engage_contribution",
    "artist_name_collab", "form_instrument", "form_play_role",
    "music_collab", "music_name", "music_timing", "music_genre", "music_year",
    "reference_harami_vid_id",  # For GET in new
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
    _set_reference_harami_vid_id  # sets reference_harami_vid_id, release_date, place, and @event_event_items, maybe @ref_harami_vid via GET method
    @places = Place.all  # necessary??
  end

  # GET /harami_vids/1/edit
  def edit
    if !@harami_vid.event_items.exists?
      flash[:warning] ||= []
      flash[:warning] << "Please make sure to add an Event(Item)."
    end

    _set_reference_harami_vid_id  # sets reference_harami_vid_id, release_date, place, and @event_event_items, maybe @ref_harami_vid via GET method
    @places = Place.all  # necessary??
  end

  # POST /harami_vids
  # POST /harami_vids.json
  def create
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

    _set_reference_harami_vid_id  # Sets reference_harami_vid_id, @event_event_items, @ref_harami_vid

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
    _set_reference_harami_vid_id  # Sets reference_harami_vid_id, @event_event_items, @ref_harami_vid

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
      %i(duration music_timing).each do |ek|
        params[:harami_vid][ek] =  helpers.hms2sec(params[:harami_vid][ek]) if params[:harami_vid][ek].present?  # converts from HH:MM:SS to Integer seconds; defined in application_helper.rb
      end
      set_hsparams_main_tra(:harami_vid, array_keys: [:event_item_ids]) # defined in application_controller.rb
    end

    # Set @event_event_items and @original_event_items
    #
    # @event_event_items is a Hash with each key (of Integer, {Event#id}) pointing to
    # an Array of EventItems that HaramiVid has_many:
    #
    #    @event_event_items = {
    #       event_1.id => [EventItem1, EventItem2, ...],
    #       event_2.id => [EventItem5, EventItem6, ...],
    #    }
    #
    # maybe the sum of EventItems for two HaramiVids
    #
    # This routine may be called twice - once as a before_action callback and later from _set_reference_harami_vid_id
    # When called from _set_reference_harami_vid_id , +harami_vid2+(!) is @harami_vid, and +harami_vid+ is
    # @ref_harami_vid (which corresponds to ID of @harami_vid.reference_harami_vid_id)
    def set_event_event_items(harami_vid: @harami_vid, harami_vid2: nil)
      @event_event_items = {}  # Always initialized. This was not defined for "show", "new"
      ary = [(harami_vid || @harami_vid).id, (harami_vid2 ? harami_vid2.id : nil)].compact.uniq  # uniq should never be used, but playing safe
      EventItem.joins(:harami_vid_event_item_assocs).where("harami_vid_event_item_assocs.harami_vid_id" => ary).order("event_id", "start_time", "duration_minute", "event_ratio").distinct.each do |event_item|
        # Because of "distinct", order by "xxx.yyy" would not work...
        # For "edit", this will be overwritten later if reference_harami_vid_id is specified by GET
        @event_event_items[event_item.event.id] ||= []
        @event_event_items[event_item.event.id] << event_item
      end
    end

    # Sets reference_harami_vid_id, @event_event_items, @ref_harami_vid, and maybe release_date and place
    #
    # See {#set_event_event_items} for @event_event_items.
    # @ref_harami_vid is the ID of the reference HaramiVid given (which may be passed to +new+ and then +create+).
    #
    # @note
    #   GET parameter +reference_harami_vid_id+ is passed as the root-level parameter in params,
    #   NOT inside +harami_vids: {}+
    #
    # @return [void]
    def _set_reference_harami_vid_id
      @original_event_items = @harami_vid.event_items.to_a  # to preserve the originally associated EventItems

      return if  @hsmain && (prm=@hsmain[:reference_harami_vid_id]).blank?
      return if !@hsmain && (prm=params.permit(:reference_harami_vid_id)[:reference_harami_vid_id]).blank?

      @harami_vid.reference_harami_vid_id ||= prm  # via either POST (@hsmain) or GET method; for POST this should have been already set.
      @ref_harami_vid = HaramiVid.find(prm)

      case action_name
      when "new"
        @harami_vid.release_date = @ref_harami_vid.release_date
        @harami_vid.place        = @ref_harami_vid.place
      when "edit"
        @harami_vid.release_date = @ref_harami_vid.release_date if (!@harami_vid.release_date && @ref_harami_vid.release_date) || (@harami_vid.release_date && @ref_harami_vid.release_date && @harami_vid.release_date <= TimeAux::DEF_FIRST_DATE_TIME && @harami_vid.release_date < @ref_harami_vid.release_date)
        @harami_vid.place = @ref_harami_vid.place if (!@harami_vid.place && @ref_harami_vid.place) || (@harami_vid.place && @ref_harami_vid.place && @ref_harami_vid.place.encompass_strictly?(@harami_vid.place))
      when "create", "update"
        # Do nothing
      else
        raise "Unsupported action of #{action_name} for #{__method__} . Contact the code developer."
      end

      hsprm = {
        harami_vid:  @ref_harami_vid,
        harami_vid2: (@harami_vid.new_record? ? nil : @harami_vid),
      }
      set_event_event_items(**hsprm)
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
          raise "Something goes very wrong." if @harami_vid.new_record?  # @harami_vid must have been saved (if failed in saving, this point should not be reached.)
          [:update_event_item_assocs,# @assocs[:dissociated_event_items]  # for update only
           :make_harami_vid_music_assoc_from_events, # @assocs[:harami_vid_music_assocs]  # plural
           :find_or_create_music,    # @assocs[:music]
           :find_or_create_harami_vid_music_assoc,   # @assocs[:harami_vid_music_assoc]   # singular
           :find_or_create_artist,   # @assocs[:artist]
           :find_or_create_engage,   # @assocs[:engage]
           :find_or_artist_collab,   # @assocs[:artist_collab]
           :create_an_event_item,    # @assocs[:new_event_item]  # See this method for the algorithm
           :create_artist_music_plays,# @assocs[:artist_music_play]  # used for some case of "update" only
          ].each do |task|
            self.send task
            rollback_clear_flash if @harami_vid.errors.any?
          end
          if @assocs[:artist_collab].present? && @assocs[:music_collab].blank?
            @harami_vid.errors.add :music_name, I18n.t("harami_vids.warn_collab_without_music")  # Valid Music must be given when you add an Artist-to-collaborate.
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
        @harami_vid.errors.add form_attr, ": Existing #{model.class.name} is not found, yet failed to create a new one: "+msg
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

    # Update existing associations for EventItems
    #
    # Usually for update only, unless +reference_harami_vid_id+ is specified with GET.
    #
    # Sets @assocs[:dissociated_event_items] and @assocs[:new_associated_event_items],
    # each element of which is an EventItem.  The latter is valid only when +reference_harami_vid_id+ is set.
    #
    # Basically, all the EventItems that are *NOT* specified in :event_item_ids
    # are destroyed.
    #
    # See {#set_event_event_items} and {#_set_reference_harami_vid_id} about @event_event_items and @original_event_items
    def update_event_item_assocs
      @assocs[:dissociated_event_items] = nil
      return if !@prms_all[:event_item_ids]
      # NOTE: On update, the above should not be nil in principle EXCEPT for the case
      # where old HaramiVids that have no EventItem associated. In such a case, View UI
      # does not provide the form field for [:event_item_ids] because otherwise
      # simple_form prevents the data from submitting as the field has no selection items
      # yet simple_form insists you must select at least one. (n.b., FYI, newly created HaramiVids
      # always have at least one EventItem and you cannot nullify the association).
      # Hence, this "return" above is necessary to deal with such cases.
      #
      # If @harami_vid has no EventItems, both @harami_vid.event_items is empty AT THE MOMENT
      # though later processing may modify it.  Instance variable @original_event_items
      # (set in {#set_event_event_items}) preserves the Array of EventItems, and so it should be
      # empty, and also @event_event_items (see {#set_event_event_items} and {#_set_reference_harami_vid_id}) is empty.
      # The surest way to check the existence of EventItem before processing is
      # +!@original_event_items.empty?+
      #
      # When it is empty, @prms_all[:event_item_ids] should be non-existent and so
      # the following should not be executed.

      @assocs[:dissociated_event_items] = []
      @assocs[:new_associated_event_items] = []

      leave_ids = @prms_all[:event_item_ids].select{|i| i.present?}.map(&:to_i)  # removes an empty one which is usually added by simple_form
      if leave_ids.empty?
        msg = ": "+I18n.t('errors.at_least_one_of_them_must_be_checked')
        @harami_vid.errors.add :event_item_ids, msg
      end

      @harami_vid.reload
      #_set_reference_harami_vid_id  # set @event_event_items

      @event_event_items.each_value do |ar_event_items|  # The key is ID for Event (identical to eeit.event.id), value is an Array of EventItem-s
        ar_event_items.each do |eeit|
          if leave_ids.include?(eeit.id)  # Association is not destroyed.
            next if @harami_vid.event_items.include?(eeit)
            ## This only happens when +reference_harami_vid_id+ is specified.
            @harami_vid.event_items << eeit  # NOTE: TODO: The result is not checked!!
            @assocs[:new_associated_event_items] << eeit
            next
          end
          @assocs[:dissociated_event_items].push eeit
          next if @harami_vid.event_items.destroy(eeit)
          msg_core = sprintf("Event=%s, EventItem=%s",
                             eeit.event.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either).inspect,
                             eeit.machine_name.inspect
                            )
          @harami_vid.errors.add :event_item_ids, "Failed to destroy the association (#{msg_core})."
        end
      end
    end

    # Creates {HaramiVidMusicAssoc} from EventItems
    #
    # This method checks where the Musics associated to the specified EventItem
    # (through ArtistMusicPlay) are all included in this HaramiVid (through HaramiVidMusicAssoc),
    # and add any missing Musics to HaramiVidMusicAssoc with timing=nil (not ideal,
    # but there is no way this app knows the timing information), while issuing
    # a warning, telling null timing is set.
    #
    # The case of missing happens:
    #
    # 1. if EventItems are provided from +@ref_harami_vid+ (the GET argument),
    # 2. if the wrong EventItem is specified (?? which would not happen currently,
    #    but may happen if the UI changes in such a way),
    # 3. if ArtistMusicPlay is manually and directly edited by a developer in an inconsistent way.
    #
    # Another possibility is that an existing EventItem is specified on update
    # in adding a newly-associated Music.  In such a case, the Music is **NOT**
    # added to the other HaramiVid(s), partly because the app does not know
    # its timings, and this method raises a warning to prompt
    # the user (=editor) to add the Music to the other HaramiVids.
    #
    # Set @assocs[:harami_vid_music_assocs] (plural)
    #
    # See {#set_event_event_items} about @event_event_items
    #
    # @return [HaramiVidMusicAssoc, NilClass] nil if failed to save either of Music and HaramiVidMusicAssoc or not specified in the first place.
    def make_harami_vid_music_assoc_from_events
begin  # for DEBUGging
      @assocs[:harami_vid_music_assocs] ||= []  # (plural) should not have been defined before, but playing safe.
      @harami_vid.reload  # This should have been saved alreaedy.
      @event_event_items.each_value do |ar_event_items|  # The key is ID for Event (identical to eeit.event.id), value is EventItem # should be set from update_event_item_assocs()
        ar_event_items.each do |eeit|
          next if @assocs[:dissociated_event_items].include? eeit
          eeit.musics.each do |ea_mu|
            next if @harami_vid.musics.include? ea_mu
            flash[:warning] ||= []
            flash[:warning] << "Though a played Music (#{helpers.link_to(ea_mu.title, ea_mu, target: '_blank')}) contained in #{helpers.link_to('EventItem', eeit, target: '_blank', title: eeit.machine_title)} is not found for this HaramiVid. Music is newly associated to this HaramiVid with null timing for now - please edit it later. Or, if the Music is actually not played in this HaramiVid, associate a different (or new) EventItem to this HaramiVid. Note that you may edit the EventItem to split it into two instead of creating one from scratch."
            if @ref_harami_vid && @ref_harami_vid.musics.include?(ea_mu)
              # Copies the values like timing from HaramiVidMusicAssoc for @ref_harami_vid, but adjusts somewhat.
              hvma = @ref_harami_vid.harami_vid_music_assocs.where(music_id: ea_mu.id).first.dup  # should be unique
              hvma.timing = nil
              hvma.harami_vid = @harami_vid
              flash[:warning][-1] << " Music is newly associated with null timing."
            else
              hvma = HaramiVidMusicAssoc.new(music: ea_mu, harami_vid: @harami_vid)
            end
            @assocs[:harami_vid_music_assocs] << hvma
            _save_or_add_error(hvma)  # "form_attr: :base" - this should never happen anyway.
            @harami_vid.reload
          end
        end
      end
rescue => err
  print "DEBUG(#{File.basename __FILE__}:#{__method__}): Error is raised:\n ";p err
  raise
end
    end

    # Set @assocs[:music]
    # @return [Music, NilClass] nil if failed to save Music or not specified in the first place.
    def find_or_create_music
      prm_name = "music_name"
      @assocs[:music] = nil
      return if !@hsmain.has_key?(prm_name)  # This is the case when reference_harami_vid_id is given in GET

      return if @hsmain[prm_name].blank?

      extra_prms_for_new = {
        genre: (((genid=@hsmain[:music_genre]).present? ? Genre.find_by_id(genid.to_i) : nil) || Genre.unknown),  # with UI, should be always found
        year:   ((year=@hsmain[:music_year]).present? ? year.to_i : nil),  # can be nil
      }
      @assocs[:music] = _find_or_create_artist_or_music(Music, prm_name, extra_prms_for_new)  # can be nil.
    end

    # Set @assocs[:music] and @assocs[:harami_vid_music_assoc] (singular) and initialize @event_item_for_new_artist_collab
    #
    # @event_item_for_new_artist_collab may be later updated in +create_an_event_item+
    #
    # @return [HaramiVidMusicAssoc, NilClass] nil if failed to save either of Music and HaramiVidMusicAssoc or not specified in the first place.
    def find_or_create_harami_vid_music_assoc
begin  # for DEBUGging
      prm_name = "music_timing"
      _set_event_item_for_new_artist_collab  # sets (initializes) @event_item_for_new_artist_collab
      return (@assocs[:harami_vid_music_assoc]=nil) if @assocs[:music].blank?

      timing = ((t=@hsmain[prm_name]).present? ? t : nil)
      @assocs[:harami_vid_music_assoc] = _find_or_create_harami_vid_music_assoc_core(hvid=@harami_vid, timing: timing, form_attr: prm_name.to_sym)

      return @assocs[:harami_vid_music_assoc] if !@event_item_for_new_artist_collab 


      ## Checking out the other HaramiVid-s associated with the specified EventItem for a new collaboration
      #  They all must have the Music (through HaramiVidMusicAssoc).
      #  Otherwise, an error is set.
      #
      #  This is tricky in the sense one cannot add a new Music to either of the HaramiVids
      # with a shared EventItem as long as you specify the EventItem for adding a Music.
      # Although Music-association is through HaramiVidMusicAssoc and has nothing to do
      # with HaramiVidEventAssoc, this app conceptually (if not technically) demands that
      # (pretty much) any Music in a HaramiVid should have at least one ArtistMusicPlay
      # with an EventItem. To create an ArtistMusicPlay requires an EventItem.  Once
      # an ArtistMusicPlay is created for EventItem, it means all HaramiVids that share
      # the EventItem share the ArtistMusicPlay, too, meaning an Artist (the default Artist)
      # plays a Music in the EventItem, and this also means the Music must be included
      # in all the HaramiVids (with timing information), or otherwise the situation is
      # is mutually inconsistent.  Therefore, you must associate the Music through
      # (multiple HaramiVidEventAssoc) to all the HaramiVids simultaneously to eliminate
      # the contradictory situation --- which is impractical (though it can be done
      # given that only a few HaramiVids at most share the same EventItem and so you just
      # specify the number of timings for the HaramiVids)...  For this reason, in practice
      # you must use an EventItem that is not shared by any other HaramiVids when you add a Music to HaramiVid.
      @event_item_for_new_artist_collab.harami_vids.where.not("harami_vids.id" => @harami_vid.id).each do |hvid|
        next if hvid.musics.where(id: @assocs[:music].id).exists?
        msg = ": Adding a new collab-Artist for Music of (#{helpers.link_to(@assocs[:music].title, @assocs[:music], target: '_blank')}) for #{helpers.link_to('EventItem', @event_item_for_new_artist_collab, target: '_blank', title: @event_item_for_new_artist_collab.machine_title)} contradicts the fact that another #{helpers.link_to('HaramiVid', hvid, target: '_blank')} is not associated with the Music (via HaramiVidMusicAssoc). Either edit the other #{helpers.link_to('HaramiVid', hvid, target: '_blank')} to first associate the Music (with no collab-Artist) for a different EventItem or choose a a different (or new) EventItem to this HaramiVid in specifying a collab-Artist. Note that you may edit the EventItem to split it into two instead of creating one from scratch.".html_safe
        @harami_vid.errors.add :form_new_artist_collab_event_item, msg
        #@assocs[:harami_vid_music_assocs] << _find_or_create_harami_vid_music_assoc_core(hvid)  # :base for a potential Error
#ERB::Util.html_escape
      end

      @assocs[:harami_vid_music_assoc]
rescue => err
  print "DEBUG(#{File.basename __FILE__}:#{__method__}): Error is raised:\n ";p err
  raise
end
    end


    # Sets @event_item_for_new_artist_collab
    #
    # At this stage, +@event_item_for_new_artist_collab+ is nil if
    # specified for a new EventItem.  It will be updated in +create_an_event_item+
    #
    # @return [EventItem, NilClass] EventItem for a new Music and/or collab-Artist
    def _set_event_item_for_new_artist_collab
      @event_item_for_new_artist_collab = 
        if (s=@harami_vid.form_new_artist_collab_event_item).present? && DEF_FORM_NEW_ARTIST_COLLAB_EVENT_ITEM_NEW.to_i != s.to_i
          EventItem.find(s)
        else
          nil  # set to nil if 0 == @harami_vid.form_new_artist_collab_event_item
        end
    end
    private :_set_event_item_for_new_artist_collab


    # Set @assocs[:music], @assocs[:harami_vid_music_assoc] (singular), @assocs[:harami_vid_music_assocs] (plural)
    # @param hvid [HaramiVid]
    # @param timing: [Integer, NilClass]
    # @param form_attr: [Symbol] :base in default. For error-handling.
    # @return [HaramiVidMusicAssoc, NilClass] nil if failed to save either of Music and HaramiVidMusicAssoc or not specified in the first place.
    def _find_or_create_harami_vid_music_assoc_core(hvid=@harami_vid, timing: nil, form_attr: nil)
begin  # for DEBUGging
      hvma = HaramiVidMusicAssoc.find_or_initialize_by(harami_vid: hvid, music: @assocs[:music])

      if timing
        hvma.timing = timing
        if hvma.timing_changed? && !hvma.new_record?
          flash[:notice] ||= []
          flash[:notice] << sprintf("Timing for Music (%s) is updated to %s .", @assocs[:music].title_or_alt(langcode: I18n.locale, lang_fallback_option: :either), hvma.timing)
        end
      end
      hs = {}
      hs[:form_attr] = form_attr if form_attr
      _save_or_add_error(hvma, **hs)
rescue => err
  print "DEBUG(#{File.basename __FILE__}:#{__method__}): Error is raised:\n ";p err
  raise
end
    end
    private :_find_or_create_harami_vid_music_assoc_core

    # Set @assocs[:artist]
    def find_or_create_artist
      prm_name = "artist_name"
      return(@assocs[:artist] = nil) if @hsmain[prm_name].blank?
      raise if @harami_vid.new_record?  # sanity check (@harami_vid should have been saved already.)

      extra_prms_for_new = {
        sex: (((sexid=@hsmain[:artist_sex]).present? ? Sex.find_by_id(sexid.to_i) : nil) || Sex.unknown)  # with UI, should be always found
      }
      @assocs[:artist] = _find_or_create_artist_or_music(Artist, prm_name, extra_prms_for_new) # Set @assocs[:artist]
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

    # Set @assocs[:artist_collab]
    def find_or_artist_collab
      prm_name = "artist_name_collab"
      @assocs[:artist_collab] = nil
      return if !@hsmain.has_key?(prm_name)  # This is the case when reference_harami_vid_id is given in GET
      return if @hsmain[prm_name].blank?
      @assocs[:artist_collab] = _find_or_create_artist_or_music(Artist, prm_name, find_only: true)
      @assocs[:artist_collab]
    end


    # Set @assocs[:music] or @new_artist
    # @param klass [Class] either Artist or Music
    # @param prm_key [String] form key like "artist_name"
    # @param extra_prms_for_new [Hash] e.g., {sex: Sex.unknown} to create an Artist
    # @return [ApplicationRecord, NilClass] either Music, Artist, or nil if faiiling to save
    # @raise [ActiveRecord::RecordNotFound] if a String containing the completely-wrong ID is passed,
    #    which should never happen with auto-complete or with a standard manual input in UI.
    def _find_or_create_artist_or_music(klass, prm_key, extra_prms_for_new={}, find_only: false)
      raise "hsmain=#{@hsmain.inspect}" if !@hsmain.has_key? prm_key  # sanity check (this method should never be called in such cases)
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

    # Create an EventItem for a specified Event if specified, and HaramiVidEventItemAssoc, and sets @assocs[:new_event_item] and @event_item_for_new_artist_collab
    #
    # Creating an EventItem is mandatory for "create", but NOT for "update".
    #
    # If a new EventItem is specified, usually at least Music should be specified, too, though
    # not specifying a Music is accepted.  If a Music is specified, HARAMIchan's ArtistMusicPlay
    # will be at least added in the next step: create_artist_music_plays
    # In addition, ArtistMusicPlay with a collab-Artist may be added if specified.
    #
    # Each EventItem usually has a list of Musics (and playing Artists, including HARAMIchan).
    # And when a HaramiVid has an associated EventItem, all the Musics in the EventItem
    # must be played in the video — if not, you should create a separate EventItem(s)
    # tailored to HaramiVid.
    #
    # For example, if Artist A plays Musics X, Y, Z, where they collaborate with
    # another Artist B for Music Z only, and Artist A publishes Video of playing X, Y, Z,
    # and Artist B publishes Video of Z only.  Then, you should make two EventItems:
    # one (i) pointing to the first two Musics X and Y, and the other (ii), the last Music Z. 
    # Video by Artist A has (=is associated with) two EventItems (i) and (ii), and
    # Video by Artist B has the latter EventItem only.
    #
    # == Algorithm
    #
    # 1. if +reference_harami_vid_id+ is specified (by GET), this process is totally skipped,
    #    because U/I disables "form_new_event". Else,
    # 2. create_an_event_item (this method) / "form_new_event" / @assocs[:new_event_item] and in some cases @assocs[:artist_music_play]
    #    1. for "update", this can be nil. If so, skipped.
    #    2. for "update", if this parameter is specified
    #       1. Creates a new EventItem.
    #       2. If form_new_artist_collab_event_item is 0 (=new-one), follow the same processing as for "create".
    #       3. If not (i.e., the value is other than 0 (pID of an existing EventItem)), return from here.
    #    3. for "create", 
    #       1. a new EventItem for the specified Event is created in principle.
    #       2. as long as Music is specified, ArtistMusicPlay is created, that for HARAMIchan (piano, main-instrument) is always created.
    #       3. Another ArtistMusicPlay is also created at this stage if artist-collab is specified.
    # 3. create_artist_music_plays / / @assocs[:artist_music_play] (if not yet set)
    #    1. skip if "create" or @assocs[:artist_music_play] is already set or either of collab-artist and music is not specified.
    #    2. Else, a new entry of {ArtistMusicPlay} for :artist-collab is created.
    #    3. If ArtistMusicPlay is created, that for HARAMIchan (piano, main-instrument) is also created unless a record is already associated.
    #
    # Here, +@event_item_for_new_artist_collab+ points to the EventItem for a Music or the new Artist-Collab.
    # It was initialized in +find_or_create_harami_vid_music_assoc+ but here it may be updated
    # for the case where it points to the new EventItem, which is created in this method.
    # +@event_item_for_new_artist_collab+ will be used even if there is no new EventItem
    # as long as Music to associate to the HaramiVid is specified, where Music can be new or existing.
    # Note that a new ArtistMusicPlay for the EventItem of +@event_item_for_new_artist_collab+
    # for the default Artist is also created, as long as a Music is specified, plus
    # another ArtistMusicPlay if Collab-Artist is also specified.
    def create_an_event_item
begin
      prm_name = "form_new_event"
      @assocs[:new_event_item] = nil
      @event_item_for_new_artist_collab = 
        if (s=@harami_vid.form_new_artist_collab_event_item).present? && DEF_FORM_NEW_ARTIST_COLLAB_EVENT_ITEM_NEW.to_i != s.to_i
          EventItem.find(s)
        else
          nil  # set to nil if 0 == @harami_vid.form_new_artist_collab_event_item
        end

      evt_id=@hsmain[prm_name]
      if evt_id.blank?
        case action_name
        when "create"
          if @hsmain[:reference_harami_vid_id].blank?
            raise "Bad new Event parameter is specified."
            # b/c this should never happen via UI unless reference_harami_vid_id is specified via GET!
          else
            return
          end
        when "update"
          if DEF_FORM_NEW_ARTIST_COLLAB_EVENT_ITEM_NEW.to_i == @harami_vid.form_new_artist_collab_event_item.to_i && (@assocs[:artist_collab].present? || @assocs[:music].present?)  # i.e., it says new, yet Form-for a new Event is blank, AND yet either of Music or Artist-collab is specified, which means the Event-form must be significant (if neither of the latter two is specified, the former does not mater). Note @assocs[:music] is used to add either/both a new Music (through HaramiVidMusicAssoc) and new collab (i.e., ArtistMusicPlay).
            @harami_vid.errors.add :form_new_artist_collab_event_item, " is specified to be New, but no Event is selected for it."
          end
          return
        else
          raise "Should never happen."
        end
      end

      event = Event.find(evt_id.to_i)  # should never fail via UI
      ev_kind = 
        if event.default? && @harami_vid.place.present? && (!event.place || event.place.encompass_strictly?(@harami_vid.place))
          EventItem.new_default(:HaramiVid, place: @harami_vid.place, event_group: event.event_group, save_event: false) # unsaved Event or unsaved EventItem
        else
          EventItem.new_default(:HaramiVid, event: event, save_event: false) # unsaved EventItem
        end

      set_up_event_item_and_associate(ev_kind)  # sets @assocs[:new_event_item]

      # @event_item_for_new_artist_collab is updated (from nil to EventItem) if it should point to the newly created EventItem
      @event_item_for_new_artist_collab ||=
        if (s=@harami_vid.form_new_artist_collab_event_item).blank?
          # for "create"
          @assocs[:new_event_item]
        elsif DEF_FORM_NEW_ARTIST_COLLAB_EVENT_ITEM_NEW.to_i == s.to_i
          # for "update"
          @assocs[:new_event_item]
        else
          raise "should not happen..."  # because it should have returned for "update" with the condition being false.
        end

rescue => err
  print "DEBUG(#{File.basename __FILE__}:#{__method__}): Error is raised:\n ";p err
  raise
end
    end # def create_an_event_item

    # Creates new ArtistMusicPlay-s; sets @assocs[:music_collab] and @assocs[:artist_music_play]
    #
    # This method does 3 things (3 steps in this order):
    #
    # 1. In an unusual case on update (see below for detail), creates
    #    the same number of ArtistMusicPlay-s as +@harami_vid.musics+.
    #    for the default Artist and for the newly associated EventItem (which may be new).
    # 2. Creates an ArtistMusicPlay for the default Artist and
    #    specified Music @assocs[:music_collab] for the specified (or new) EventItem.
    #    Note that this is undesirable in rare occasions, i.e.,
    #    the Music is featured in the HaramiVid but the default Artist does not play it.
    #    In such a case, the user should manually destroy the default association (the ArtistMusicPlay) later.
    # 3. Creates an ArtistMusicPlay for the specified collab-Artist @assocs[:artist_collab],
    #    @assocs[:music_collab] and the newly associated EventItem.
    #
    # Step 1 should be irrelevant for any newly created HaramiVids.
    # However, legacy HaramiVids have no EventItems associated, hence
    # in reality this happens very frequently at the time of writing.
    # A @harami_vid may have over 100 Musics, meaning that number of
    # ArtistMusicPlay-s can be created in one processing.
    # Basically, there are following three potential cases.
    #
    # (1) on update for a legacy HaramiVid where no EventItems were associated.
    #    (A) call {HarmiVid#associate_harami_existing_musics_plays} to associate
    #        all associated Musics with a newly specified EventItem.
    #        the same number of ArtistMusicPlay-s are created.
    #    (B) Plus, if a new Music @assocs[:music] is specified with UI (not recommended...),
    #        the Music will get also accosiated with the default Artist and the EventItem.
    #    (C) Same, but +ref_harami_vid+ is given in params (create or update).
    #        See {HaramiVid#associate_harami_existing_musics_plays} for detail.  Complicated...
    #        Basically, as long as Musics agree between the two HaramiVids, that is fine,
    #        because all ArtistMusicPlay have been already created.
    #        If not, how to associate or not is complicated.
    # (1) on create, where up to 1 Music is specified, or on update.
    #     (1) run steps 2 and 3.
    #
    # == alert - error
    #
    # This method issues an error when both a new Music @assocs[:music] and collab-Artist
    # @assocs[:artist_collab] are specified, meaning this method will create an ArtistMusicPlay,
    # and when the specified EventItem @assocs[:new_event_item] for it is associated with
    # other HaramiVid(s) not all of which are associated with the Music @assocs[:music],
    # because the situation is contradictory - all the HaramiVid-s associated with an ArtistMusicPlay should
    # be associated with the Music {ArtistMusicPlay#music} via {HaramiVidMusicAssoc}.
    #
    # If the user wants to do so, the user should do either of the following:
    #
    # 1. simply specify a new EventItem to go with the new-collab relationship,
    # 2. first add the Music to all the other HaramiVid-s sharing the same EventItem, and retry.
    #
    # == alert - warning
    #
    # In rare cases, where +ref_harami_vid+ is given in GET,
    # `HaramiVid#associate_harami_existing_musics_plays` may set warnings: see the comment
    # in the method for detail.
    #
    # @note HaramiVidEventItemAssoc must have been already created, so nothing is done about it here.
    def create_artist_music_plays
begin
      raise "Strange..." if @assocs[:artist_music_play].present?
      prm_name = "music_collab"
      @assocs[:music_collab] =
        if @hsmain[:music_collab].blank?
          nil
        else
          Music.find(@hsmain[:music_collab])
        end

      ### NOTE: This is a temporary measure (to circumvent the existing tests)...
      # With UI, @assocs[:music_collab] must be specified when "artist_name_collab" is specified.
      @assocs[:music_collab] ||= @assocs[:music]

      @assocs[:artist_music_play_haramis] ||= []  # should be empty at this stage.

      if @original_event_items.empty?  # See {#_set_reference_harami_vid_id}
        arin = (@assocs[:new_event_item].present? ? [@assocs[:new_event_item]] : [])
        if !arin.empty? || @harami_vid.event_items.exists?
          @assocs[:artist_music_play_haramis] = @harami_vid.associate_harami_existing_musics_plays(*arin, music_except: @assocs[:music])  # form_attr: :base
          # For update, if @harami_vid does not have existing EventItems (which only happens
          # for legacy HaramiVids), ArtistMusicPlay-s should be defind for all Musics
          # of @harami_vid and for the default Artist.
          #
          # Here, @assocs[:music] is specified to be ignored because 
          # the EventItem @event_item_for_new_artist_collab should be used to create
          # an ArtistMusicPlay with it.

          if !@harami_vid.warning_messages.empty?
            # Warning messages are added by HaramiVid#associate_harami_existing_musics_plays
            flash[:warning] ||= []
            flash[:warning].concat @harami_vid.warning_messages
          end
        end
      end

      if @assocs[:music]   # || @event_item_for_new_artist_collab.blank?  # Even if @event_item_for_new_artist_collab.blank?, if an existing EventItem can be used to create a default ArtistMusitPlay, then it is OK.  If not, associate_harami_music_play would set an error on @harami_vid
        associate_harami_music_play(event_item: @event_item_for_new_artist_collab)
      end

      return if !@assocs[:artist_collab] || !@assocs[:music_collab] || @event_item_for_new_artist_collab.blank?

      hvid_errs = _find_all_event_items_associated_with_harami_vid_without_the_music
      if hvid_errs.present?
        @harami_vid.errors.add :form_new_artist_collab_event_item, " the specified EventItem for a new collab is associated with another HaramiVid (ID=#{hvid_err.id}: #{hvid_err.title.inspect}) that does not have the Music (#{@assocs[:music].title.inspect}). You must either first associate the Music to the HaramiVid or simply specify a new (or different) EventItem for the collab-Artist-Music."
        return
      end

      instrument = ((val=@hsmain[:form_instrument]).blank? ? Instrument.default(:HaramiVid) : Instrument.find(val))
      play_role  = ((val=@hsmain[:form_play_role]).blank?  ? PlayRole.default(:HaramiVid)   : PlayRole.find(val))

      form_attr = (("create" == action_name) ? :base : :form_new_artist_collab_event_item)
      associate_artist_music_play(instrument, play_role, event_item: @event_item_for_new_artist_collab, form_attr: form_attr) # defines @assocs[:artist_music_play]
rescue => err
  print "DEBUG(#{File.basename __FILE__}:#{__method__}): Error is raised:\n ";p err
  raise
end
    end

    # Returns (the first) HaramiVid that is associated with the
    # EventItem of interest yet is not associated with the specified Music.
    #
    # The situation is contradictory and should be marked.
    #
    # @return [HaramiVid, NilClass] nil if none is found (which is great)
    def _find_all_event_items_associated_with_harami_vid_without_the_music
      raise "Should not happen. Contact the code developer." if [@assocs[:music_collab], @assocs[:artist_collab], @event_item_for_new_artist_collab].any?(&:blank?)

      @event_item_for_new_artist_collab.harami_vids.where.not("harami_vids.id" => @harami_vid.id).find_all{|hvid|
        !hvid.musics.include? @assocs[:music_collab]
      }  # This could be rewritten with a single SQL statement.
    end

    # Save a new EventItem, setting @assocs[:new_event_item], and creates HaramiVidEventItemAssoc
    #
    # @param evt_kind [Event, EventItem] Either Event or EventItem
    def set_up_event_item_and_associate(evt_kind)
      @assocs[:new_event_item] ||= nil
      if evt_kind.new_record?  # It should be always new_record?
        return if !_save_or_add_error(evt_kind)
      end
      evit = ((EventItem == evt_kind.class) ? evt_kind.reload : evt_kind.unknown_event_item)

      evit.update!(publish_date: @harami_vid.release_date)  # EventItem is always new, hence this is OK.

      raise "There should be only one New EventItem - contact the code developer: #{evt_kind.inspect}" if @assocs[:new_event_item].present? && (@assocs[:new_event_item] != evit)

      @assocs[:new_event_item] ||= evit
      @harami_vid.event_items << evit if !@harami_vid.event_items.include?(evit)  # Added HaramiVidEventItemAssoc
      @harami_vid.event_items.reset
    end

    def set_up_event_item_and_amp(event_item, instrument, play_role)
      set_up_event_item_and_associate(event_item)
      associate_artist_music_play(instrument, play_role)
    end

    def set_up_event_item_and_amp_harami(event_item, instrument, play_role)
      set_up_event_item_and_associate(event_item)
      associate_harami_music_play
    end

    # New entry of ArtistMusicPlay for :artist_collab and at the same time for HARAMIchan
    def associate_artist_music_play(instrument, play_role, event_item: @assocs[:new_event_item], form_attr: :base)
      associate_harami_music_play(event_item: event_item)

      @assocs[:artist_music_play] = ArtistMusicPlay.find_or_initialize_by(
        event_item: event_item,
        artist:     @assocs[:artist_collab],
        music:      @assocs[:music_collab],
        instrument: instrument,
        play_role:   play_role,
      )

      if !@assocs[:artist_music_play].new_record?
        @harami_vid.errors.add :form_instrument, ": "+t('harami_vids.edit.identical_amp', default: "An identical combination (Music, Instrument, etc) for an existing association for the collab-Artist is specified. You can register a new combination but not a duplication.")
        return
      end

      _save_or_add_error(@assocs[:artist_music_play], form_attr: form_attr)  # :base for create b/c uncertain which parameter is wrong.
    end

    # New entry of ArtistMusicPlay for HARAMIchan
    #
    # If there is an ArtistMusicPlay for HARAMIchan for some reason, nothing is newly created.
    # Usually only the argument you may want to specify is event_item
    #
    # Note Music used here is @assocs[:music] and NOT @assocs[:music_collab] - the default
    # ArtistMusicPlay for the latter should be already present, unless Editor has deliberately
    # destroyed it, in which case this app respects the Editor's action and does nothing here.
    #
    # @example
    #   associate_harami_music_play(event_item: @event_item_for_new_artist_collab)
    #
    # @return [void]
    def associate_harami_music_play(instrument=nil, play_role=nil, event_item: @assocs[:new_event_item], music: @assocs[:music], form_attr: :base)
      return if music.blank?
      @assocs[:artist_music_play_haramis] ||= []

      # music.reload  # NOTE: this is desirable only for debugging output with Translation
      model =
        if event_item
          ArtistMusicPlay.initialize_default_artist(:HaramiVid, event_item: event_item, music: music, instrument: instrument, play_role: play_role)  # new for the default ArtistMusicPlay (event_item and music are mandatory to specify.
        else
          arids = @harami_vid.event_items.ids
          if arids.empty?
            @harami_vid.errors.add :form_new_artist_collab_event_item, ": must select Event(Item) when specifying a Music."
            return
          else
            ArtistMusicPlay.initialize_default_artist(:HaramiVid, event_item_ids: arids, event_item: event_item, music: music, instrument: instrument, play_role: play_role)  # new for the default ArtistMusicPlay (event_item and music are mandatory to specify.
          end
        end

      return if !model.new_record?

      _save_or_add_error(model, form_attr: form_attr)  # :base for create b/c uncertain which parameter is wrong.
      @assocs[:artist_music_play_haramis] << model  # model remains a new_record? in an unlikely case where model.save fails above
      @harami_vid.reload
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

