# coding: utf-8
class EngagesGrid < ApplicationGrid

  scope do
    Engage.all
  end

  ####### Filters #######

  filter_n_column_id(:engage_url, mandatory: true)  # defined in application_grid.rb

  filter_partial_str(:artists, header: Proc.new{I18n.t('datagrid.form.artists_multi')}, self_models: :engages)
  filter_partial_str(:musics,  header: Proc.new{I18n.t('datagrid.form.musics_multi')},  self_models: :engages)
  filter(:engage_how, :enum, multiple: true, select: Proc.new{EngageHow.order(:weight).map{|mdl| [mdl.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either, article_to_head: true), mdl.id]}.to_h}, header: Proc.new{I18n.t("engages.engage_how", default: "EngageHow")})

  column_names_max_per_page_filters  # defined in base_grid.rb ; calling column_names_filter() and filter(:max_per_page)

  ####### Columns #######

  # ID first (already defined in the head of the filters section)

  column_model_trans_belongs_to(:music, mandatory: true, header: Proc.new{I18n.t(:Music, default: "Music")})  # defined in application_grid.rb
  column_model_trans_belongs_to(:artist, mandatory: true, header: Proc.new{I18n.t(:Artist, default: "Artist")})  # defined in application_grid.rb
  column_model_trans_belongs_to(:engage_how, mandatory: true, with_link: false, header: Proc.new{I18n.t("engages.engage_how", default: "EngageHow")})  # defined in application_grid.rb

  column(:year, mandatory: true)
  column(:contribution, mandatory: true)

  column_note(mandatory: true) # defined in application_grid.rb
  columns_upd_created_at  # defined in application_grid.rb

  column_actions(edit_path_method: :edit_engage_multi_how_path)  # defined in application_grid.rb

end

