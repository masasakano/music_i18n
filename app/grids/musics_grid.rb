# coding: utf-8
class MusicsGrid < ApplicationGrid
  extend ApplicationHelper ##################################################################################

  scope do
    Music.all
  end

  ####### Filters #######

  filter_n_column_id(:music_url)  # defined in application_grid.rb

  filter_include_ilike(:title_ja, header: Proc.new{I18n.t("datagrid.form.title_ja_en", default: "Title [ja+en] (partial-match)")})
  filter_include_ilike(:title_en, langcode: 'en', header: Proc.new{I18n.t("datagrid.form.title_en", default: "Title [en] (partial-match)")})

  filter(:year, :integer, range: true, header: Proc.new{I18n.t('tables.year')}) # , default: proc { [User.minimum(:logins_count), User.maximum(:logins_count)] }

  filter(:genre, :enum, multiple: true, select: Proc.new{Genre.order("genres.weight").map{|mdl| [mdl.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either, article_to_head: true), mdl.id]}.to_h}, header: Proc.new{I18n.t('Genre')})

  filter(:country, :enum, multiple: false, select: Proc.new{Country.joins(:musics).distinct.map{|mdl| [mdl.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either, article_to_head: true, prefer_shorter: true), mdl.id]}.to_h}, header: Proc.new{I18n.t('Country')}) do |value|
    self.joins(:place).joins(:prefecture).joins(:country).where("countries.id = ?", value)
  end

  filter(:artists, :string, header: Proc.new{I18n.t("datagrid.form.artists", default: "Artist (partial-match)")}, input_options: {"data-1p-ignore" => true}) do |value|  # Only for PostgreSQL!
    str = preprocess_space_zenkaku(value, article_to_tail=true)
    trans_opts = {accept_match_methods: [:include_ilike], translatable_type: 'Artist'}
    arts = Artist.find Translation.find_all_by_a_title(:titles, value, **trans_opts).uniq.map(&:translatable_id)
    # self.joins(:engages).where('engages.artist_id IN (?)', arts.map(&:id)).distinct  # This would break down when combined with order()
    ids = Music.joins(:engages).where('engages.artist_id IN (?)', arts.map(&:id)).distinct.pluck(:id)
    self.where id: ids
  end

  column_names_max_per_page_filters  # defined in base_grid.rb

  ####### Columns #######

  # ID first (already defined in the head of the filters section)

  column_all_titles  # defined in application_grid.rb

  column(:year, tag_options: {class: ["align-cr"]}, header: Proc.new{I18n.t('tables.year')}, mandatory: true)

  column_model_trans_belongs_to(:genre, header: Proc.new{I18n.t(:Genre)}, with_link: false)  # defined in application_grid.rb
  column_place  # defined in application_grid.rb

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

  column_n_harami_vids    # defined in application_grid.rb

  column_note             # defined in application_grid.rb
  columns_upd_created_at  # defined in application_grid.rb

  column_actions(with_destroy: false) do |record| # defined in application_grid.rb
    # This is relevant only when User can :update
    can?(:update, Musics::MergesController) ? link_to('Merge', musics_new_merges_path(record)) : nil
  end

end

