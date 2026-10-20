module TranslationsHelper
  # HTML title elements for Flag-display
  FLAG_TITLES = {
    is_formal:   "Most formal name? (unique per language)",
    is_official: "Official Translation?",
    is_literal:  "Literal Translation? (mostly for Music titles)",
    is_true_name:  "True name like birth-name? (for persons)",
    is_for_record: "For record only? (while rarely used, like the true name of some artists)",
    is_internal: "For internal use only? (e.g., typical mis-spelling, used for auto-complete)",
  }

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
  # @return [String] checked for select in Form.
  def langcode_checked(model)
    if defined?(@hstra) && @hstra["langcode"].present?
      # set in set_hsparams_main_tra in application_controller.rb providing the Controller uses it.
      # @hstra is set only after create (or update) and NOT in new (or edit, but note
      # this routine should be irrelevant for "edit", because the form of BaseWithTranslation
      # for :edit does not include Translation fields).
      @hstra["langcode"]
    elsif model.respond_to?(:langcode) && model.langcode.present?
      model.langcode
    elsif (tra_langcode=model.best_translation&.langcode).present?
      # Note that the caller (in View) might raise ActionView::Template::Error if nil was ever returned.
      # For this reason, the return must be always significant.
      tra_langcode
    else
      I18n.available_locales.first.to_s  # "ja"
    end
  end

  # @param model [BaseWithTranslation, NilClass]
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

  # If {Translation#weight} is too high, the {Translation} may need to be hidden from public display.
  #
  # @param trans [Translation]
  # @param all_trans_of_langcode [#map] Relation or Array of {Translation} for the same translatable and langcode
  def self.should_hide_for_public?(trans, all_trans_of_langcode)
    all_trans_of_langcode.size > 1 &&
      trans.weight &&
      trans.weight > Translation::MAX_WEIGHT_VISIBLE &&
      trans.weight != Float::INFINITY
  end

  # Common String part of Parent/Child Translation link in Translation-Show
  #
  # @param target_trans [Translation] Parent/Child Translation of the current Translation (self-reference)
  def anchor_to_sync_target(target_trans)
    parent_bws = target_trans.translatable
    return if !parent_bws

    klass_name = parent_bws.class.name
    link_to_model =
      if can?(:show, parent_bws)
        link_to klass_name, parent_bws
      else
        klass_name
      end

    link_to_id = 
      if can?(:show, target_trans)
        sprintf(" (pID=%s)", link_to("#{target_trans.id}", target_trans)).html_safe
      else
        target_trans.id.to_s
      end

    (link_to_model + " Translation" + link_to_id).html_safe
  end

  # Anchor-String of Parent/Child Translation link in Translation Table cells
  #
  # @param translation [Translation] Current {Translation}
  def word_to_sync_target(translation)
    if (tgt=translation.sync_parent).present?
      link_to "From", tgt, title: "Parent Translation"
    elsif (tgt=translation.sync_child).present?
      link_to "To",   tgt, title: "Child Translation"
    else
      "".html_safe
    end
  end

  # @return [String] re start_year and end_year
  def period_translation(translation, null_if_nil: false)
    return (null_if_nil ? "" : "&mdash;").html_safe if !translation.start_year && !translation.end_year
    sprintf("%s &ndash; %s", translation.start_year, translation.end_year).html_safe
  end

  def flags_translation(translation)
    arret = []

    FLAG_TITLES.map{|em, etext|
      sprintf('<span title="%s: %s" class="%s">%s</span>', em, etext, "flag_"+em.to_s, _ternary_flag_display(translation.send(em)))
    }.join(" / ").html_safe
  end

    def _ternary_flag_display(value)
      ret = 
        if false == value
          "F"
        elsif value.blank?
          "&ndash;"  # => "–"
        else
          "T"
        end
      ret.html_safe
    end
    private :_ternary_flag_display
end
