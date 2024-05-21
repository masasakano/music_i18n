module ArtistsHelper
  # @param channels [#map]
  def channels2displayed_list(channels)
    arout = []
    archans = channels.map{ |echan| [echan.channel_platform, echan.channel_type]}.sort
    archans.each do |ach|
      if arout.size > 0 && arout[-1][0] == ach[0]
        arout[-1][1] << ach[1]
      else
        arout << [ach[0], [ach[1]]]
      end
    end 

    arout.map{|ea|
      sprintf("%s (%s)",
              ea[0].title_or_alt(prefer_alt: false, langcode: I18n.locale, lang_fallback_option: :either, str_fallback: "", article_to_head: true),
              ea[1].map{|j| j.title_or_alt(prefer_alt: false, langcode: I18n.locale, lang_fallback_option: :either, str_fallback: "", article_to_head: true)}.join(" / "))
    }.join(t(:comma))
  end
end
