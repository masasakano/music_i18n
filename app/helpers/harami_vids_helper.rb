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
end
