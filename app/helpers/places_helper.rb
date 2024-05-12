# coding: utf-8
module PlacesHelper
  # Returns a HTML-safe String, including a link (if eligible)
  #
  # @param pla [Place]
  # @return [String]
  def show_pref_place_country(pla)
    return "" if !pla

    ar = pla.title_or_alt_ascendants(langcode: I18n.locale, prefer_alt: true, lang_fallback_option: :either)
    # Titles of Place, Prefecture, Country

    pla_title =
      if can?(:read, pla)
        link_to (ar[0].blank? ? "NO-TRANSLATION" : ar[0]), pla
      else
        ar[0]
      end
    pla_title = '— '+pla_title+' ' if pla_title.present?
    pla_title = pla_title.html_safe

    sprintf('%s %s(%s)', h(ar[1]), pla_title, h(ar[2])).html_safe
  end
end
