module HaramiVidsHelper
  def show_list_featuring_artists(event_item)
    msg = event_item.artists.map{|ea_art|
      tit = ea_art.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either, article_to_head: true)
      (can?(:show, ea_art) ? link_to(tit, ea_art) : h(tit))
    }.join(t(:comma, default: ", ")).html_safe
    msg.present? ? msg : t(:None)
  end

  # Returns collection for HaramiVid _form
  def collection_musics_with_evit(harami_vid)
    harami_vid.musics.map{|music|
      tit_mu = music.title_or_alt(langcode: I18n.locale, prefer_shorter: true, lang_fallback_option: :either)
      art = music.most_significant_artist
      tit_art = (art ? sprintf("(by %s)", art.title_or_alt(prefer_shorter: true, lang_fallback_option: :either)) : nil)
      event_items = harami_vid.event_items.joins(:artist_music_plays).where("artist_music_plays.music_id" => music.id).distinct
      evit_count = event_items.count
      tit_evit = 
        if evit_count == 0
          ""
        else
          etc = ((event_items.count > 1) ? "["+t('etc')+"]" : "")
          mtitle = event_items.pluck(:machine_title).sort{|a,b| a.size <=> b.size}.first
          [mtitle, etc].join(" ")
        end
      tit_evit = (tit_evit.blank? ? "" : "[EvItem] "+tit_evit)

      [[[tit_mu, tit_art].compact.join(" "), tit_evit].compact.join(" - "), music.id]
    } 
  end

  # Retunrs String to display in the summary/index table a colleciton of "how the collaborations are made"
  #
  # @param hvid [HaramiVid]
  # @param rela [HaramiVid::Relation]
  def collab_hows_text(hvid)
    def_artist = Artist.default(:HaramiVid)
    hvid.artist_music_plays.where.not(artist_id: def_artist.id).distinct.map{ |amp|
      model2print =
        case (apr=amp.play_role).mname
        when "inst_player_main", "inst_player"
          amp.instrument
        else
          apr
        end
      model2print.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either, article_to_head: true)
    }.compact.uniq.join(t(:comma))
  end

  private

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

end
