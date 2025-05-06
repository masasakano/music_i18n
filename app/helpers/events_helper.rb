# coding: utf-8
module EventsHelper
  # @param rela [Relation] Either Event or its relation like Event.all
  def form_selct_collections(rela)
    rela = rela.all if !rela.respond_to? :map
    rela.map{|i|
      evt_tit = i.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either)
begin      
      grp_tit = i.event_group.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either)
rescue
  print "DEBUG:helper1234: ev="; p [i, i.event_group]
  raise
end
      [sprintf("%s [%s]", evt_tit, grp_tit), i.id]
    }
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
end
