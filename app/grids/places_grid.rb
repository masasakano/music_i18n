# coding: utf-8
class PlacesGrid < ApplicationGrid

  scope do
    Place.all
  end

  ####### Filters #######

  filter_n_column_id(:place_url)  # defined in application_grid.rb

  filter_ilike_title(:ja)  # defined in application_grid.rb
  filter_ilike_title(:en)  # defined in application_grid.rb

  filter(:prefecture_id, :enum, multiple: true, include_blank: true,
         header: Proc.new{I18n.t("datagrid.form.prefectures")}, select: proc_select_prefectures)  # defined in application_grid.rb

  column_names_max_per_page_filters  # defined in base_grid.rb

  ####### Columns #######

  # ID first (already defined in the head of the filters section)

  column_all_titles  # defined in application_grid.rb

  column_prefecture

  column(:country, mandatory: true, header: Proc.new{I18n.t(:Country)}, order: proc { |scope|
           scope.joins(:prefecture).order("prefectures.country_id")
    }) do |record|
    record.country.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either)
  end

  column_n_models_belongs_to(:n_artists, :artists, distinct: true)
  column_n_models_belongs_to(:n_events, :events, distinct: false, header: Proc.new{I18n.t('event_groups.n_events')})
  column_n_harami_vids    # defined in application_grid.rb

  ### NOTE: not displayed because very few Musics belong to a particular Place (but usually Country)
  ##column_n_models_belongs_to(:n_musics, :musics, distinct: false, header: Proc.new{I18n.t('tables.n_musics')})
  # column(:n_musics, tag_options: {class: ["align-cr", "align-r-padding3"]}, header: Proc.new{I18n.t('tables.n_musics')}) do |record|
  #   record.musics.uniq.count
  # end

  column_wiki_url         # defined in application_grid.rb
  column_note             # defined in application_grid.rb
  columns_upd_created_at(Place)  # defined in application_grid.rb

  column_actions(with_destroy: false) # defined in application_grid.rb

end

