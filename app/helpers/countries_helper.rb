module CountriesHelper
  # Return a HTML link to {CountryMaster} if exists. Maybe an emtpy string.
  #
  # @param country [Country]
  # @return [String] it is "html_safe"-ed.
  def link_to_master(country, **opts)
    master = country.country_master
    return "" if !master

    tit_master = master.slice(*(%i(name_ja_full name_ja_short name_en_full name_en_short))).values.map{|i| i.blank? ? '' : i}
    tit_self   = %w(ja en).map{ |elc| %i(title alt_title).map{|method| country.send(method, langcode: elc)}}.flatten.map{|i| i.blank? ? '' : i}
    is_consistent = tit_master.zip(tit_self).all?{|ec| ec[0].blank? || (ec[0] == ec[1])}

    link_to((is_consistent ? 'Same' : 'Differ'), country_master_path(master), **opts).html_safe
  end

end
