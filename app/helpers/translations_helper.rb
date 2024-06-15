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

  # @param model [BaseWithTranslation]
  # @return [String] checked for select in Form
  def langcode_checked(model)
    if defined?(@hstra) && @hstra["langcode"].present?
      # set in set_hsparams_main_tra in application_controller.rb providing the Controller uses it.
      # @hstra is set only after create (or update) and NOT in new (or edit, but note
      # this routine should be irrelevant for "edit", because the form of BaseWithTranslation
      # for :edit does not include Translation fields).
      @hstra["langcode"]
    elsif model.respond_to?(:langcode) && model.langcode.present?
      model.langcode
    elsif (tras=model.best_translation).present?
      tras.langcode
    else
      I18n.available_locales.first.to_s  # "ja"
    end
  end

  # @param model [BaseWithTranslation]
  # @param key [Symobol, String] :title, :alt_title, :ruby, etc.
  # @return [String] checked for select in Form
  def value_a_title_in_form(model, key)
    key = key.to_s
    if defined?(@hstra) && @hstra[key].present?
      # set in set_hsparams_main_tra in application_controller.rb providing the Controller uses it.
      # @hstra is set only after create or update and NOT in new or edit.
      @hstra[key]
    elsif model.respond_to?(key) && (val=model.send(key)).present?
      val
    else
      ""
    end
  end
end
