module HaramiVidsHelper
  def show_list_featuring_artists(event_item)
    msg = event_item.artists.map{|ea_art|
      tit = ea_art.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either, article_to_head: true)
      (can?(:show, ea_art) ? link_to(tit, ea_art) : h(tit))
    }.join(t(:comma, default: ", ")).html_safe
    msg.present? ? msg : t(:None)
  end
end
