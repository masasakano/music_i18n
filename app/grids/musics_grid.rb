# coding: utf-8
class MusicsGrid < BaseGrid

  scope do
    Music.all
  end

  ####### Filters #######

  filter(:id, :integer, header: "ID", if: Proc.new{BaseGrid.qualified_as?(:editor)})  # displayed only for editors

  filter_include_ilike(:title_ja, header: Proc.new{I18n.t("datagrid.form.title_ja_en", default: "Title [ja+en] (partial-match)")})
  filter_include_ilike(:title_en, langcode: 'en', header: Proc.new{I18n.t("datagrid.form.title_en", default: "Title [en] (partial-match)")})

  filter(:year, :integer, range: true, header: Proc.new{I18n.t('tables.year')}) # , default: proc { [User.minimum(:logins_count), User.maximum(:logins_count)] }

  filter(:genre, :enum, multiple: true, select: Proc.new{Genre.order("genres.weight").map{|mdl| [mdl.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either, article_to_head: true), mdl.id]}.to_h}, header: Proc.new{I18n.t('Genre')})

  filter(:country, :enum, multiple: false, select: Proc.new{Country.joins(:musics).distinct.map{|mdl| [mdl.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either, article_to_head: true, prefer_shorter: true), mdl.id]}.to_h}, header: Proc.new{I18n.t('Country')}) do |value|
    self.joins(:place).joins(:prefecture).joins(:country).where("countries.id = ?", value)
  end

  filter(:artists, :string, header: Proc.new{I18n.t("datagrid.form.artists", default: "Artist (partial-match)")}) do |value|  # Only for PostgreSQL!
    str = preprocess_space_zenkaku(value, article_to_tail=true)
    trans_opts = {accept_match_methods: [:include_ilike], translatable_type: 'Artist'}
    arts = Artist.find Translation.find_all_by_a_title(:titles, value, **trans_opts).uniq.map(&:translatable_id)
    # self.joins(:engages).where('engages.artist_id IN (?)', arts.map(&:id)).distinct  # This would break down when combined with order()
    ids = Music.joins(:engages).where('engages.artist_id IN (?)', arts.map(&:id)).distinct.pluck(:id)
    self.where id: ids
  end

  column_names_max_per_page_filters  # defined in base_grid.rb

  ####### Columns #######

  column(:id, class: ["align-cr", "editor_only"], header: "ID", if: Proc.new{BaseGrid.qualified_as?(:editor)}) # NOT: if MusicsGrid.current_user.moderator?  # This does not work; see above

  column(:title_ja, header: Proc.new{I18n.t('tables.title_ja')}, mandatory: true, order: proc { |scope|
    #order_str = Arel.sql("convert_to(title, 'UTF8')")
    order_str = Arel.sql('title COLLATE "ja-x-icu"')
    scope.joins(:translations).where("langcode = 'ja'").order(order_str) #.order("title")
  }) do |record|
    html_titles(record, col: :title, langcode: "ja", is_orig_char: "*") # defined in base_grid.rb
  end
  column(:ruby_romaji_ja, header: Proc.new{I18n.t('tables.ruby_romaji')}, order: proc { |scope|
    order_str = Arel.sql('ruby COLLATE "ja-x-icu", romaji COLLATE "ja-x-icu"')
    scope.joins(:translations).where("langcode = 'ja'").order(order_str) #order("ruby").order("romaji")
  }) do |record|
    str_ruby_romaji(record)  # If NULL, nothing is displayed. # defined in base_grid.rb
  end
  column(:alt_title_ja, header: Proc.new{I18n.t('tables.alt_title_ja')}, mandatory: true, order: proc { |scope|
    order_str = Arel.sql('alt_title COLLATE "ja-x-icu"')
    scope.joins(:translations).where("langcode = 'ja'").order(order_str)
  }) do |record|
    str_ruby_romaji(record, col: :alt_title)  # If NULL, nothing is displayed. # defined in base_grid.rb
  end
  column(:title_en, mandatory: true, header: Proc.new{I18n.t('tables.title_en_alt')}, order: proc { |scope| #, grid|  # add grid to get a filter to use like:  grid.trans_display_preferance
    scope_with_trans_order(scope, Music, langcode="en")  # defined in base_grid.rb
  }) do |record|
    html_title_alts(record, is_orig_char: "*")  # defined in base_grid.rb
  end

  column(:other_lang, header: Proc.new{I18n.t('layouts.Other_language_short')}) do |record|
    titles_other_langs(record, is_orig_char: "*")  # defined in base_grid.rb
  end

  column(:year, class: ["align-cr"], header: Proc.new{I18n.t('tables.year')}, mandatory: true)

  column(:genre, header: Proc.new{I18n.t(:Genre)}) do |record|
    record.genre.title_or_alt(langcode: I18n.locale)
  end
  column(:place, header: Proc.new{I18n.t('tables.place')}) do |record|
    record.place.pref_pla_country_str(langcode: I18n.locale, lang_fallback_option: :either, prefer_shorter: true)
  end

  # Valid only for PostgreSQL
  # To make it applicable for other DBs, see  https://stackoverflow.com/a/68998474/3577922)
  column(:artists, html: true, header: Proc.new{I18n.t("application.menu_artists", default: "Artists")}, mandatory: true, order: proc { |scope|
    #order_str = Arel.sql("convert_to(title, 'UTF8'), convert_to(alt_title, 'UTF8')")
    #order_str = Arel.sql('title COLLATE "ja_JP", alt_title COLLATE "ja_JP"')
    #order_str = Arel.sql('title COLLATE "C", alt_title COLLATE "C"')
    order_str = Arel.sql('title COLLATE "ja-x-icu", alt_title COLLATE "ja-x-icu"')
#Rails.logger.debug sprintf("DEBUG:SCOPE=: #{scope.inspect}")
    ids = Music.joins(:artists).joins("INNER JOIN translations ON translations.translatable_id = artists.id AND translations.translatable_type = 'Artist'").order(order_str).map(&:id).uniq  # if scope is used instead of Music, it seems to be heavily affected by cache
#Rails.logger.debug sprintf("DEBUG:ids: #{ids.inspect}")
    #scope.joins("INNER JOIN unnest('{#{ids.join(',')}}'::int[]) WITH ORDINALITY t_ord(id, ord) USING (id)").order("t_ord.ord")  # This should work, too, unless there is another JOIN.
    scope.joins("INNER JOIN unnest('{#{ids.join(',')}}'::int[]) WITH ORDINALITY t_ord(id, ord) ON musics.id = t_ord.id").order("t_ord.ord")
  }) do |record|
    #record.engages.joins(:engage_how).order('engage_hows.weight').pluck(:artist_id).uniq.map{|i| art = Artist.find(i); sprintf '%s [%s]', ActionController::Base.helpers.link_to(art.title_or_alt, Rails.application.routes.url_helpers.artist_path(art, locale: I18n.locale)), ERB::Util.html_escape(art.engage_how_titles(record).join(', '))}.join(', ').html_safe
    record.engages.joins(:engage_how).order('engage_hows.weight').pluck(:artist_id).uniq.map{|i| art = Artist.find(i); sprintf '%s [%s]', link_to(art.title_or_alt, artist_path(art)), html_escape(art.engage_how_titles(record).join(', '))}.join(', ').html_safe  # NOTE: the option "html: true" is essential to use artist_path directly (as opposed to Rails.application.routes.url_helpers.artist_path). Also, in the latter case, "locale: I18n.locale" is essential for some reason (otherwise the URL with no locale is returned).
  end
  column(:n_harami_vids, html: true, class: ["text-end"], header: Proc.new{I18n.t("tables.n_harami_vids", default: "# of HaramiVids")}) do |record|
    ActionController::Base.helpers.link_to(I18n.t(:times_hon, count: record.harami_vids.distinct.count.to_s), Rails.application.routes.url_helpers.music_path(record)+"#sec_harami_vids_for")
  end

  column(:note, html: true, order: false, header: Proc.new{I18n.t("tables.note", default: "Note")}){ |record|
    sanitized_html(auto_link50(record.note)).html_safe
  }

  column(:updated_at, class: ["editor_only"], header: Proc.new{I18n.t('tables.updated_at')}, if: Proc.new{BaseGrid.qualified_as?(:editor)})
  column(:created_at, class: ["editor_only"], header: Proc.new{I18n.t('tables.created_at')}, if: Proc.new{BaseGrid.qualified_as?(:editor)})
  column(:actions, html: true, mandatory: true, header: "") do |record|  # Proc.new{I18n.t("tables.actions", default: "Actions")}
    #ar = [ActionController::Base.helpers.link_to('Show', record, data: { turbolinks: false })]
    ar = [link_to(I18n.t('layouts.Show'), music_path(record), data: { turbolinks: false })]
    if can? :update, record
      ar.push(('<span  class="editor_only">'+link_to('Edit', edit_music_path(record))+'</span>').html_safe)
      if can?(:update, Musics::MergesController)
        ar.push(('<span  class="editor_only">'+link_to('Merge', musics_new_merges_path(record))+'</span>').html_safe)
        #if can? :destroy, record
        #  ar.push link_to('Destroy', music_path(record), method: :delete, data: { confirm: (t('are_you_sure')+" "+t("are_you_sure.merge")).html_safe })
        #end
      end
    end
    ar.compact.join(' / ').html_safe
  end

end

