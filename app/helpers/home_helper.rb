module HomeHelper
  # Returns "artist1 + ……<br>artist2<br>..." for Home#index View
  #
  # where artist1 and artist2 are the links for {Artist},
  # whereas '……' is the link for {Music}
  #
  # @param harami_vid [HaramiVid]
  # @param langcode [String]
  # @return [String]
  def view_home_artist(harami_vid, langcode='en')
    harami_vid.musics.map{|ea_mu|
      arts = ea_mu.sorted_artists.uniq
      n_arts = arts.count
      art1st = arts[0]
      next '&mdash;'.html_safe if 0 == n_arts || art1st.unknown?
      tit = (art1st.title(langcode: langcode) || art1st.title)
      s1 = link_to(tit, artist_path(art1st))
      next s1 if 1 == n_arts
      s1+', '+link_to('……', music_path(ea_mu))
    }.join('<br>').html_safe
  end

  # Returns "music<br>music<br>..." for Home#index View
  #
  # @param harami_vid [HaramiVid]
  # @param langcode [String]
  # @return [String]
  def view_home_music(harami_vid, langcode)
    harami_vid.musics.map{|ea_mu|
      timing = harami_vid.timing(ea_mu)
      tit = ea_mu.title(langcode: langcode.to_s, lang_fallback: false, str_fallback: nil)
      if !tit && 'en' == langcode.to_s
        tit = ea_mu.romaji(langcode: 'ja')  # English fallback => Romaji in JA
        tit &&= '['+tit+']'
      end
      link_str = (tit.blank? ? '&mdash;' : link_to(tit, music_path(ea_mu)))
      hms_or_ms = sec2hms_or_ms(timing)
      ylink_en = link_to_youtube(hms_or_ms, harami_vid.uri, timing)  # defined in application_helper.rb
#ylink_en = link_to_youtube sprintf('%d'+I18n.t('s_time')+'—', (timing || 0)), uri, timing  # defined in application_helper.rb
      sprintf "%s (%s)", link_str, ylink_en
    }.join('<br>').html_safe
  end

end
