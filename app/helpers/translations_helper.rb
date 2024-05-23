module TranslationsHelper
  # @example
  #    <td><%= cell_ruby_romaji(modelx) %></td> <%# defined in translations_helper.rb %>
  #
  # @param model [ApplicationRecord]
  # @return [String]
  def cell_ruby_romaji(model, langcode: 'ja')
    ar = %i(ruby romaji).map{|i| model.send(i, langcode: langcode, lang_fallback: false, str_fallback: "")}
    ar.join("").blank? ? "" : sprintf('[%s/%s]', *ar)
  end

  # @example
  #    <td><%= cell_alt_all(modelx) %></td> <%# defined in translations_helper.rb %>
  #
  # @param model [ApplicationRecord]
  # @return [String]
  def cell_alt_all(model, langcode: 'ja')
    ar = %i(alt_title alt_ruby alt_romaji).map{|i| model.send(i, langcode: langcode, lang_fallback: false, str_fallback: "")}
    ar[1..2].join("").blank? ? ar[0] : sprintf('%s [%s/%s]', *ar)
  end

  # @example
  #    <td><%= cell_tit_alt(modelx) %></td> <%# defined in translations_helper.rb %>
  #
  # @param model [ApplicationRecord]
  # @return [String]
  def cell_tit_alt(model, langcode: 'en')
    ar = %i(title alt_title).map{|i| model.send(i, langcode: langcode, lang_fallback: false, str_fallback: "")}
    ar[1].blank? ? ar[0] : sprintf('%s [%s]', *ar)
  end

  # @example
  #    print_two_with_brackets(tra.ruby, tra.romaji)
  #     # => "[ | tokyo]"  or  ""
  #     # => maybe "[ | ]" (editor) or  "" (public)
  #
  # @param s1 [String]
  # @param s2 [String, NilClass]
  # @return [String]
  def print_two_with_brackets(s1, s2=nil, separator: " | ")
    ar=[s1, s2]
    retstr = "["+ar.map{|i| i || ""}.join(separator)+"]"
    if (can?(:edit, Translation) || can?(:edit, Music)) || ar.any?(&:present?)
      retstr
    else
      ""
    end
  end
end
