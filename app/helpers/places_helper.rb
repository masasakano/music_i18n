# coding: utf-8
module PlacesHelper
  # Returns a HTML-safe String, including a link (if eligible)
  #
  # @param pla [Place]
  # @param prefer_shorter: [Boolean] for title_or_alt in base_with_translation.rb
  # @param lang_fallback_option: [Symbol, Boolean] Def: :either. For title_or_alt in base_with_translation.rb (where the Default differs).
  # @param kwd [Hash] prefer_shorter: true, **kwd
  # @return [String]
  def show_pref_place_country(pla, prefer_shorter: false, lang_fallback_option: :either, **kwd)
    return "" if !pla

    ar = pla.title_or_alt_ascendants(langcode: I18n.locale, prefer_shorter: prefer_shorter, lang_fallback_option: lang_fallback_option, **kwd)  # defined in place.rb
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
