# coding: utf-8
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

  # Returns a sorted Hash of @event_event_items by the timing of the associated Music in the HaramiVid
  #
  # see {#set_event_event_items} for the structure of Hash @event_event_items
  # All EventItems in event_event_items are assumed to be already associated to HaramiVid.
  #
  # In short, the EventItems belonging to the Event, one of EventItems of it is associated to
  # a Music that is played first in the HaramiVid come first, and all EventItems in the Event
  # are again sorted by the Music timings.
  #
  # The result is as follows:
  #
  #   {
  #     Event1-pID =>
  #       [EventItem1  (1st, 4th, 8th Music),
  #        EventItem2  (7th, 9th Music)]
  #     Event2-pID =>
  #       [EventItem1  (2nd, 3rd Music),
  #        EventItem2  (3rd, 6th, Music)]  (duplicated)
  #     Event3-pID =>
  #       [EventItem1  (5th Music), ]
  #   }
  #
  # @note When timing for a Music is nil, the associated EventItem has the highest priority.
  #
  # @param harami_vid [HaramiVid]
  # @param event_event_items [Hash] if @event_event_items is not set, automatically set here.
  # @return [Hash]
  def sorted_event_event_items_by_timing(harami_vid=@harami_vid, event_event_items=@event_event_items)
    event_event_items ||= set_event_event_items(harami_vid: harami_vid)

    # sorted_evits = harami_vid.event_items.joins(:artist_music_plays).joins(:harami_vids).joins("").joins("LEFT OUTER JOIN harami_vid_music_assocs ON harami_vid_music_assocs.harami_vid_id = harami_vids.id AND harami_vid_music_assocs.music_id = artist_music_plays.music_id").where("harami_vid_music_assocs.harami_vid_id = ?", harami_vid.id).order("harami_vid_music_assocs.timing").uniq  ### => the timing-sorted EventItems

    evit_timings_all = harami_vid.event_items.joins(:artist_music_plays).joins(:harami_vids).joins("").joins("LEFT OUTER JOIN harami_vid_music_assocs ON harami_vid_music_assocs.harami_vid_id = harami_vids.id AND harami_vid_music_assocs.music_id = artist_music_plays.music_id").where("harami_vid_music_assocs.harami_vid_id = ?", harami_vid.id).order("harami_vid_music_assocs.timing").select("id", "harami_vid_music_assocs.timing AS timing").map{|i| [i.id, i.timing]}

    evit_timings = []  # Reduced Array of [EventItem-pID, timing]-s
    evit_timings_all.each do |ea|
      evit_timings << ea if !evit_timings.any?{|epair| epair[0] == ea[0]}
    end

    event_event_items.map{ |evtid, arevit|
      [evtid,
       arevit.map{ |eet|
         evit_timings.find{ |ev_ti|
           break [eet, (ev_ti[1] || -1)] if ev_ti[0] == eet.id  # -1 (highest priority) is assigned if timing is nil
         } || [eet, Float::INFINITY]   # If a Music (associated to EventItem) is not listed in HaramiVidMusicAssoc, its timing is interpreted as Infinity (n.b., the EventItem may have other Musics that have a significant timing, hence having a higher priority).
       }.sort{|a, b| a[1]<=>b[1]}  # Array of [EventItem, timing]-s sorted by timing (per Event)
      ]  # [EventID, [[EvenItem1,timing1], [EvenItem2,timing2], ...]]
    }.sort{|a, b|  # sort for Event (using its earliest-timing EventItem
      a[1][0][1]<=>b[1][0][1]  # respectably: 1=EventItemArray, 0=Earliest-timing-EventItem-Pair, 1=Timing
    }.map{|ev_evits| [ev_evits[0], ev_evits[1].map{|epair| epair.first}]}.to_h
  end

  # Used in `/app/views/harami_vids/_event_event_items.html.erb` called from HaramiVid#show
  def trimmed_event_item_machine_title_to_display(event_item)
    if event_item.unknown?
      "Unknown"
    else
      event_item.machine_title.sub(/((?:#{Regexp.quote(EventItem::PREFIX_MACHINE_TITLE_DUPLICATE)}\d*\-)*[^-]+)\-.*/, '\1-…').sub(/(.{29}).*/, '\1…')  # "copy-" prefix or its multiples are taken into account, which can be prefixed in the controller in /app/controllers/event_items/deep_duplicates_controller.rb
    end
  end

  # Returns the default Event for a newly associated EventItem
  #
  # 1. For a new HaramiVid, the default Event.
  # 2. For an existing HaramiVid with no EventItem-s associated, the Event has to be explicitly specified (because the editor tends to forget to specify it, and the default one is usually wrong).
  # 3. For an existing HaramiVid with one or more EventItem-s, the most newly created Event among them is the default.
  #
  # @param harami_vid [HaramiVid]
  # @return [Event]
  def default_event_for_new_event_item(harami_vid=@harami_vid)
    return Event.default(:HaramiVid).id if harami_vid.new_record?
    return nil if harami_vid.events.blank?
    harami_vid.events.order(created_at: :desc).first
  end

  # @param harami_vid: [HaramiVid] 
  # @return [Url::ActiveRecord::Relation, Url::ActiveRecord_Associations_CollectionProxy] of Harami-Chronicle Urls for HaramiVid
  def harami_vid_harami_chronicle_urls(harami_vid: )
    dt_h_chronicle = DomainTitle.joins(:site_category).where("site_categories.mname" => "chronicle").order("domain_titles.created_at").first
    Url.joins(:domain).joins(events: :harami_vids).where("domains.domain_title_id" => dt_h_chronicle.id).where("harami_vids.id" => harami_vid.id).distinct
  end

  # @return [EventItem::ActiveRecord_Relation, EventItem::ActiveRecord_Associations_CollectionProxy]
  def get_event_items_relation_from_harami_vid(harami_vid, given_ref, sorted_event_event_items)
    collec = harami_vid.event_items
    collec_is_empty = !harami_vid.event_items.exists?
    if given_ref
      collec2 = given_ref.event_items
      return (collec_is_empty ? collec2 : collec.or(collec2)).distinct
    elsif !collec_is_empty
      collec3 = sorted_event_item_collection(collec, harami_vid, sorted_eei: sorted_event_event_items)  # defined in event_items_helper.rb
      return collec3 if collec3
    end
    collec
  end

  # @return [Hash] pID(EventItem) => LinkText  (link only for Editors) for HaramiVid
  def prepare_evit_list_for_table(harami_vid)
    events = harami_vid.events
    parent_evits = harami_vid.event_items

    can_read = can?(:read, EventItem)
    hs_evits = {}  # pID => txt [String]
    events.order(:start_time, :event_group_id).uniq.map{|eev| eev.event_items}.flatten.each_with_index do |ea_evit, ind|  # EAch-EVent-ITem
      link_core = ((incl=parent_evits.include?(ea_evit)) ? tag.span(class: ["text-warning-regular"]){(ind+1).to_s} : (ind+1).to_s)
      link_txt = (can_read ? link_to(link_core, ea_evit) : link_core)
      hs_evits[ea_evit.id] = (
        tag.span(title: h(ea_evit.machine_title), class: ["text-warning-regular": parent_evits.include?(ea_evit)]){ link_txt } +
        (incl ? tag.span(title: t("harami_vids.show.CommonEventItem")){tag.sup(){"†"}} : "")
      ).html_safe
    end
    hs_evits
  end

  # @return [String] List of (possibly) links of numbered EventItem-s.
  def evit_list_for_hvid(hvid, hs_evits)
    hvid_evids = hvid.event_items.ids
    hs_evits.map{|pid, linktxt|
      hvid_evids.include?(pid) ? linktxt : nil
    }.compact.join(t(:comma)).html_safe
  end

  # @return [String] safe_html of title of (potentially multiple) Event(s)
  def events_and_groups_html(harami_vid, separator: " | ", **opts)
    n_events = harami_vid.events.distinct.count
    harami_vid.events.uniq.map{|event| event_and_group_html(event, with_group: (1==n_events), **opts)}.join(separator).html_safe # defined in events_helper.rb
  end

  private

    # Set @event_event_items
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
    # This routine may be called twice - once as a before_action callback and later from +_import_reference+
    # When called from +_import_reference+, +harami_vid2+(!) is @harami_vid, and +harami_vid+ is
    # @ref_harami_vid (which corresponds to ID of @harami_vid.reference_harami_vid_kwd)
    def set_event_event_items(harami_vid: @harami_vid, harami_vid2: nil)
      @event_event_items = {}  # Always initialized. This was not defined for "show", "new"
      ary = [(harami_vid || @harami_vid).id, (harami_vid2 ? harami_vid2.id : nil)].compact.uniq  # uniq should never be used, but playing safe
      EventItem.joins(:harami_vid_event_item_assocs).where("harami_vid_event_item_assocs.harami_vid_id" => ary).order("event_id", "start_time", "duration_minute", "event_ratio").distinct.each do |event_item|
        # Because of "distinct", order by "xxx.yyy" would not work...
        # For "edit", this will be overwritten later if reference_harami_vid_kwd is specified by GET
        @event_event_items[event_item.event.id] ||= []
        @event_event_items[event_item.event.id] << event_item
      end
    end

end
