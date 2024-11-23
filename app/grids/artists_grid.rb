# coding: utf-8
class ArtistsGrid < ApplicationGrid

  scope do
    Artist.all
  end

  ####### Filters #######

  filter_n_column_id(:artist_url)  # defined in application_grid.rb

  filter_include_ilike(:title_ja, header: Proc.new{I18n.t("datagrid.form.title_ja_en", default: "Title [ja+en] (partial-match)")})
  filter_include_ilike(:title_en, langcode: 'en', header: Proc.new{I18n.t("datagrid.form.title_en", default: "Title [en] (partial-match)")})

  filter(:birth_year, :integer, range: true, header: Proc.new{I18n.t('artists.index.birth_year')}) # , default: proc { [User.minimum(:logins_count), User.maximum(:logins_count)] }

  def self.sex_titles
    begin
      Sex::ISO5218S.map{|i|
        se = Sex[i]
        Rails.logger.error "(#{__FILE__}): It seems ISO5218 in Sex.all have been modified: Sex[i=#{i.inspect}]==#{se.inspect}; Sex.all=#{Sex.all.inspect}" if !se
        [se.title(langcode: I18n.locale), se.id]  # See log if this raises an ActionView::Template::Error, searching for "It seems ISO5218"
      }.to_h
    rescue #rescue ActionView::Template::Error  does not work for some reason!
      ## ISO5218 in one of Sexes must be modified.
      Sex.order(:iso5218).pluck(:iso5218).map(&:to_i).map{|i| se = Sex[i]; [se.title(langcode: I18n.locale), se.id]}.to_h
    end
  end
  filter(:sex, :enum, checkboxes: true, select: Proc.new{sex_titles}, header: Proc.new{I18n.t('tables.sex')}) # , default: sex_titles) # allow_blank: false (Default; so if nothing is checked, this filter is ignored)
  # <https://github.com/bogdan/datagrid/wiki/Filters>
  #  (In Dynamic select option)
  #  IMPORTANT: Always wrap dynamic :select option with proc, so that datagrid fetch it from database each time when it renders the form.
  # NOTE: However, in this case, the contetns of Sex should not change, so it is not wrapped with Proc.

  column_names_max_per_page_filters  # defined in base_grid.rb

  ####### Columns #######

  # ID first (already defined in the head of the filters section)

  column(:title_ja, mandatory: true, header: Proc.new{I18n.t('tables.title_ja')}, order: proc { |scope|
    #order_str = Arel.sql("convert_to(title, 'UTF8')")
    order_str = Arel.sql('title COLLATE "ja-x-icu"')
    scope.left_joins(:translations).where("langcode = 'ja'").order(order_str) #.order("title")
    #scope.left_joins("LEFT OUTER JOIN translations ON translations.translatable_type = 'Artist' AND translations.translatable_id = artists.id AND translations.langcode = 'ja'").order(order_str) #.order("title")
  }) do |record|
    html_titles(record, col: :title, langcode: "ja", is_orig_char: "*") # defined in base_grid.rb
  end
  column(:ruby_romaji_ja, header: Proc.new{I18n.t('tables.ruby_romaji')}, order: proc { |scope|
    order_str = Arel.sql('ruby COLLATE "ja-x-icu", romaji COLLATE "ja-x-icu"')
    scope.joins(:translations).where("langcode = 'ja'").order(order_str) #order("ruby").order("romaji")
    #scope.left_joins("LEFT OUTER JOIN translations ON translations.translatable_type = 'Artist' AND translations.translatable_id = artists.id AND translations.langcode = 'ja'").order(order_str) #order("ruby").order("romaji")  # for some reason this does not work!
  }) do |record|
    str_ruby_romaji(record)  # If NULL, nothing is displayed. # defined in base_grid.rb
  end
  column(:alt_title_ja, mandatory: true, header: Proc.new{I18n.t('tables.alt_title_ja')}, order: proc { |scope|
    order_str = Arel.sql('alt_title COLLATE "ja-x-icu"')
    scope.joins(:translations).where("langcode = 'ja'").order(order_str)
    #scope.left_joins("LEFT OUTER JOIN translations ON translations.translatable_type = 'Artist' AND translations.translatable_id = artists.id AND translations.langcode = 'ja'").order(order_str) #.order("title")
  }) do |record|
    str_ruby_romaji(record, col: :alt_title)  # If NULL, nothing is displayed. # defined in base_grid.rb
  end
  column(:title_en, mandatory: true, header: Proc.new{I18n.t('tables.title_en_alt')}, order: proc { |scope|
    scope_with_trans_order(scope, Artist, langcode="en")  # defined in base_grid.rb
  }) do |record|
    html_title_alts(record, is_orig_char: "*")  # defined in base_grid.rb
  end

  column(:other_lang, header: Proc.new{I18n.t('layouts.Other_language_short')}) do |record|
    titles_other_langs(record, is_orig_char: "*")  # defined in base_grid.rb
  end

  column(:sex, tag_options: {class: ["text-center"]}, mandatory: true, header: Proc.new{I18n.t('tables.sex')}) do |record|
    record.sex.title(langcode: I18n.locale)
  end

  column(:birth_year, tag_options: {class: ["align-cr"]}, mandatory: false, header: Proc.new{I18n.t('artists.show.birthday')}) do |record|
    sprintf '%s年%s月%s日', *(%i(birth_year birth_month birth_day).map{|m|
                                i = record.send m
                                (i.blank? ? '——' : i.to_s)
                              })
  end

  column(:place, header: Proc.new{I18n.t('tables.place')}) do |record|
    record.place.pref_pla_country_str(langcode: I18n.locale, lang_fallback_option: :either, prefer_shorter: true)
  end

  column(:channel_owner, header: Proc.new{I18n.t('ChannelOwner')}) do |record|
    (co=record.channel_owner) ? ActionController::Base.helpers.link_to(I18n.t("ChannelOwner"), Rails.application.routes.url_helpers.channel_owner_url(co, only_path: true)) : ""
  end

  column(:n_musics, tag_options: {class: ["align-cr", "align-r-padding3"]}, header: Proc.new{I18n.t('tables.n_musics')}) do |record|
    record.musics.uniq.count
  end

  column(:n_harami_vids, tag_options: {class: ["align-cr", "align-r-padding3"]}, header: Proc.new{I18n.t('tables.n_harami_vids')}) do |record|
    record.harami_vids.uniq.count.to_s
  end

  %w(ja en).each do |elc|
    kwd = 'wiki_'+elc
    column(kwd, mandatory: false, order: false, header: Proc.new{I18n.t('tables.'+kwd)}) do |record|
      uri = record.wiki_uri(elc)
      if uri.blank?
        '——'
      else
        str_link = File.basename(uri)
        str_link = CGI.unescape(str_link) if str_link.include? '%'
        ActionController::Base.helpers.link_to(str_link, uri).html_safe
      end
    end
  end

  column_note             # defined in application_grid.rb
  columns_upd_created_at  # defined in application_grid.rb

  column_actions(with_destroy: false) do |record| # defined in application_grid.rb
    # This is relevant only when User can :update
    can?(:update, Musics::MergesController) ? link_to('Merge', artists_new_merges_path(record)) : nil
  end

end

