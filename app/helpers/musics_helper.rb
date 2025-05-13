# coding: utf-8
module MusicsHelper

  # @return [Array[String,Engage]] maybe hyperlink (if permitted)
  def engage_title_link(music, artist)
    ## construct a Hash (key of year (9999 for nil)) of Arrays of Hashes
    hsyear = {}  #
    artist.engage_how_list(music).each do |ea_hs|  # [Engage,Title,Year,Contribution]
      if hsyear.keys.include?(yr=(ea_hs[:year] || 9999))
        hsyear[yr] << ea_hs
      else
        hsyear[yr] = [ea_hs]
      end
    end

    return [] if hsyear.empty?

    can_read = can?(:read, (e1=hsyear.first[1].first[:engage]))  # If one can read one Engage, they should be allowed to read any Engage.
      # n.b., Hash#first gives a pair of Array(key, value)
    can_update = can?(:update, e1)

    years = hsyear.keys.sort
    retstr = years.map{ |eyr|
      conts = hsyear[eyr].map{ |ehs|
        ehs[:contribution] && print_1or2digits(ehs[:contribution])  # defined in application_helper.rb
      }
      contribution_str =
        if !can_update || conts.compact.empty?
          ""
        else
          '<span class="editor_only">;f=' + conts.map{|i| i ? i : "nil"}.join("/") + "</span>"
        end

      hsyear[eyr].map{ |ehs|
        dagger_contribution =
          if ehs[:contribution] && ehs[:contribution] != 1
            sprintf '<span title="%s: %s">†</span>', t("attr.contribution"), print_percent_2digits(ehs[:contribution])
          else
            ""
          end.html_safe
        if can_read
          link_to ehs[:title], ehs[:engage]
        else
          ERB::Util.html_escape(ehs[:title]) 
        end + dagger_contribution
      }.join("/")+"("+((9999 == eyr) ? t('musics.show.year_unknown') : eyr.to_s)+contribution_str+")"
    }.join(t(:comma)).html_safe

    [retstr, hsyear.first[1].first[:engage]]
  end

  # You may encupsule it sanitized_html(with auto_link50(...)).html_safe
  #
  # @return [String] to show in a cell in Artist-Engage table in Music#show
  def compile_engage_notes(artist, music)
    arnotes = artist.engages.where(music: music).map{ |eng|
      if eng.note.present?
        sprintf("[%s] %s", eng.engage_how.title_or_alt(prefer_shorter: true, langcode: I18n.locale, lang_fallback_option: :either, str_fallback: "", article_to_head: true), eng.note.strip)
      else
        nil
      end
    }.compact.join(" \n")
  end

  # @example
  #    
  # @return comma-separated html_safe Strings for many Music links
  def list_linked_musics(rela, max_num: 10)
    arsels = Music.collection_ids_titles_or_alts_for_form(rela, prioritize_is_orig: false)
    links = arsels.map.with_index{|ea, i|
      next nil if i > max_num-1
      link_to(ea[0], music_path(ea[1]))
    }

    if !links[-1]
      links.compact!
      links.push t('tables.trimmed_from', all_rows: arsels.size, items: t(:music_noun).pluralize(I18n.locale))
    end

    links.join(t(:comma)).html_safe
  end
end
