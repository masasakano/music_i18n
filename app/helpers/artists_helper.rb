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

  # Returns String of html_safe (HTML-anchored) Artist-titles up to a given maximum number.
  #
  # If it exceeds the given maximum number, a notice is appended.
  #
  # @example
  #    <%= list_linked_artists(ea_hvid.artists) %> <%# defined in ArtistsHelper %>
  #
  # @param with_link: [Boolean] if true (Def), link_to is employed.
  # @return comma-separated html_safe Strings for many Artist links
  def list_linked_artists(rela, max_items: 10, with_link: true, with_bf_for_trimmed: false)
    print_list_inline_upto(rela, model: Artist, items_suffix: t(:artist_postfix).pluralize(I18n.locale), max_items: max_items, with_link: with_link, with_bf_for_trimmed: with_bf_for_trimmed)
  end
end
