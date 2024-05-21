module ArtistsHelper
  # @param channels [#map]
  def channels2displayed_list(channels)
    arout = []
    archans = channels.map{ |echan| [echan.channel_platform, echan.channel_type, echan]}.sort
    archans.each do |ach|
      if arout.size > 0 && arout[-1][0] == ach[0]
        arout[-1][1] << [ach[1], ach[2]]
      else
        arout << [ach[0], [[ach[1], ach[2]]]]
      end
    end 

    arout.map{|ea|
      sprintf("%s (%s)",
              h(ea[0].title_or_alt(prefer_alt: false, langcode: I18n.locale, lang_fallback_option: :either, str_fallback: "", article_to_head: true)),
              ea[1].map{|tup_type_chan|
                tit=tup_type_chan[0].title_or_alt(prefer_alt: false, langcode: I18n.locale, lang_fallback_option: :either, str_fallback: "", article_to_head: true)
                can?(:show, tup_type_chan[1]) ? link_to(tit, channel_path(tup_type_chan[1])) : h(tit)
              }.join(" / ")).html_safe
    }.join(t(:comma)).html_safe
  end
end
