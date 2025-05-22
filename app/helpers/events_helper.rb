# coding: utf-8
module EventsHelper
  def form_all_event_collection(rela=Event.all)
    rela2pass = rela.left_joins(:place).order(:start_time, :event_group_id, "places.prefecture_id", "places.id")

    Event.collection_ids_titles_or_alts_for_form(rela2pass, fmt: "%s [%s]", str_fallback: "NONE", id_assocs: [EventGroup], prioritize_is_orig: false)
  end

  # @param rela [Relation] Either EventGroup or its relation like EventGroup.all
  def form_selct_collections_evgr(rela)
    rela = rela.all if !rela.respond_to? :map
    rela.map{|i|
      grp_tit = i.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either)
      [sprintf("%s", grp_tit), i.id]
    }
  end

  # String to show (or not) EventGroup period in Event-show
  def events_show_event_group_period(event_group)
    start_date = event_group.start_date
    period_text = period_date2text(start_date, event_group.end_date) # defined in application_helper.rb
    if start_date.blank? || period_text.blank?
      return editor_only_safe_html(event_group, method: :edit, tag: "span"){
        "(#{start_date.blank? ? 'Start_date' : 'Period'} UNDEFINED)"
      }
    end

    retstr = ("("+sanitize(period_text)+")").html_safe

    def_start_date = EventGroup.default(:HaramiVid).start_date
    if def_start_date && start_date <= def_start_date + 1.days
      return editor_only_safe_html(event_group, method: :edit, tag: "span"){ retstr }
    end

    retstr
  end


  # String to show (or not) warning about inconsistency of start_time/err with EventGroup in Event-show
  #
  # Permission is irrelevant for this method.
  def events_inconsistent_time_warning_word(event)
    hs = event.period_inconsistencies_with_parent
    is_inconsistent = [:start_time, :start_time_err].any?{|ek| hs.include?(ek)}

    postfix = h(sprintf(" with EventGroup in %s (%s (± %s) - %s (± %s))",
                        (hs.include?(:start_time) ? 'Time' : 'Err'),
                        (evgr=event.event_group).start_date,
                        evgr.start_date_err,
                        evgr.end_date,
                        evgr.end_date_err))

    html_consistent_or_inconsistent(!is_inconsistent, postfix: postfix)   # defined in application_helper.rb
  end

  # @param with_link: [Boolean] if true (Def), anchored HTML is returned.
  # @param with_group_link: [Boolean, Symbol] the same as above, but for with_link. If Def(:with_link), it is linked to :with_link
  # @param with_group: [Boolean] if true (Def), EventGroup is included in the returned HTML.
  # @param fmt: [String] sprintf Format for output. Looked up ONLY when with_group is true (Def). Must contain two "%s"-s
  # @return [String] html_safe String like "My Event [Foo Group]"; here, EventGroup title is prefer_shorter
  def event_and_group_html(event, with_link: true, with_group_link: :with_link, with_group: true, fmt: "%s [%s]")
    with_group_link = with_link if :with_link == with_group_link

    event_title_raw = event.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either, article_to_head: true)
    event_title = event_title_raw.sub(/ < [^<]+$/, "")
    event_html = 
      if with_link && can?(:read, event)
        link_to event_title, event, title: h(event_title_raw)
      else
        h(event_title)
      end
    return event_html if !with_group

    eg = event.event_group
    tit = eg.title_or_alt_for_selection
    group_html = 
      if with_group_link && can?(:read, eg)
        link_to tit, eg
      else
        h(tit)
      end

    sprintf(h(fmt), event_html, group_html).html_safe
  end
end
