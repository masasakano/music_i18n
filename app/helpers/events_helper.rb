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
end
