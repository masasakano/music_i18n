# coding: utf-8
class ArtistsGrid < BaseGrid

  scope do
    Artist.all
  end

  ####### Filters #######

  filter(:id, :integer, header: "ID", if: Proc.new{BaseGrid.qualified_as?(:editor)})  # displayed only for editors

  filter_include_ilike(:title_ja, header: Proc.new{I18n.t("datagrid.form.title_ja_en", default: "Title [ja+en] (partial-match)")})
  filter_include_ilike(:title_en, langcode: 'en', header: Proc.new{I18n.t("datagrid.form.title_en", default: "Title [en] (partial-match)")})

  filter(:birth_year, :integer, range: true, header: Proc.new{I18n.t('tables.year')}) # , default: proc { [User.minimum(:logins_count), User.maximum(:logins_count)] }

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

  column(:id, class: ["align-cr", "editor_only"], header: "ID", if: Proc.new{BaseGrid.qualified_as?(:editor)}) # NOT: if ArtistsGrid.is_current_user_moderator

  column(:title_ja, mandatory: true, header: Proc.new{I18n.t('tables.title_ja')}, order: proc { |scope|
    #order_str = Arel.sql("convert_to(title, 'UTF8')")
    order_str = Arel.sql('title COLLATE "ja-x-icu"')
    scope.left_joins(:translations).where("langcode = 'ja'").order(order_str) #.order("title")
    #scope.left_joins("LEFT OUTER JOIN translations ON translations.translatable_type = 'Artist' AND translations.translatable_id = artists.id AND translations.langcode = 'ja'").order(order_str) #.order("title")
  }) do |record|
    # record.title langcode: 'ja'
    html_titles(record, col: :title, langcode: "ja", is_orig_char: "*") # defined in base_grid.rb
  end
  column(:ruby_romaji_ja, header: Proc.new{I18n.t('tables.ruby_romaji')}, order: proc { |scope|
    order_str = Arel.sql('ruby COLLATE "ja-x-icu", romaji COLLATE "ja-x-icu"')
    scope.joins(:translations).where("langcode = 'ja'").order(order_str) #order("ruby").order("romaji")
    #scope.left_joins("LEFT OUTER JOIN translations ON translations.translatable_type = 'Artist' AND translations.translatable_id = artists.id AND translations.langcode = 'ja'").order(order_str) #order("ruby").order("romaji")  # for some reason this does not work!
  }) do |record|
    s = sprintf '[%s/%s]', *(%i(ruby romaji).map{|i| record.send(i, langcode: 'ja') || ''})
    s.sub(%r@/\]\z@, ']').sub(/\A\[\]\z/, '')  # If NULL, nothing is displayed.
  end
  column(:alt_title_ja, mandatory: true, header: Proc.new{I18n.t('tables.alt_title_ja')}, order: proc { |scope|
    order_str = Arel.sql('alt_title COLLATE "ja-x-icu"')
    scope.joins(:translations).where("langcode = 'ja'").order(order_str)
    #scope.left_joins("LEFT OUTER JOIN translations ON translations.translatable_type = 'Artist' AND translations.translatable_id = artists.id AND translations.langcode = 'ja'").order(order_str) #.order("title")
  }) do |record|
    s = sprintf '%s [%s/%s]', *(%i(alt_title alt_ruby alt_romaji).map{|i| record.send(i, langcode: 'ja') || ''})
    s.sub(%r@ +\[/\]\z@, '')  # If NULL, nothing is displayed.
  end
  column(:title_en, mandatory: true, header: Proc.new{I18n.t('tables.title_en_alt')}, order: proc { |scope|
    scope_with_trans_order(scope, Artist, langcode="en")  # defined in base_grid.rb
  }) do |record|
    html_title_alts(record, is_orig_char: "*")  # defined in base_grid.rb
  end

  column(:other_lang, header: Proc.new{I18n.t('layouts.Other_language_short')}) do |record|
    titles_other_langs(record, is_orig_char: "*")  # defined in base_grid.rb
  end

  column(:sex, class: ["text-center"], mandatory: true, header: Proc.new{I18n.t('tables.sex')}) do |record|
    record.sex.title(langcode: I18n.locale)
  end

  column(:birth_year, class: ["align-cr"], mandatory: false, header: Proc.new{I18n.t('artists.show.birthday')}) do |record|
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

  column(:n_musics, class: ["align-cr", "align-r-padding3"], header: Proc.new{I18n.t('tables.n_musics')}) do |record|
    record.musics.uniq.count
  end

  column(:n_harami_vids, class: ["align-cr", "align-r-padding3"], header: Proc.new{I18n.t('tables.n_harami_vids')}) do |record|
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

  column(:note, html: true, order: false, header: Proc.new{I18n.t("tables.note", default: "Note")}){ |record|
    sanitized_html(auto_link50(record.note)).html_safe
  }

  column(:updated_at, class: ["editor_only"], header: Proc.new{I18n.t('tables.updated_at')}, if: Proc.new{BaseGrid.qualified_as?(:editor)})
  column(:created_at, class: ["editor_only"], header: Proc.new{I18n.t('tables.created_at')}, if: Proc.new{BaseGrid.qualified_as?(:editor)})
  column(:actions, html: true, mandatory: true, header: "") do |record|  # Proc.new{I18n.t("tables.actions", default: "Actions")}
    #ar = [ActionController::Base.helpers.link_to('Show', record, data: { turbolinks: false })]
    ar = [link_to(I18n.t('layouts.Show'), artist_path(record), data: { turbolinks: false })]
    if can? :update, record
      ar.push(('<span  class="editor_only">'+link_to('Edit', edit_artist_path(record))+'</span>').html_safe)
      if can?(:update, Artists::MergesController)
        ar.push(('<span  class="editor_only">'+link_to('Merge', artists_new_merges_path(record))+'</span>').html_safe)
        #if can? :destroy, record
        #  ar.push link_to('Destroy', artist_path(record), method: :delete, data: { confirm: (t('are_you_sure')+" "+t("are_you_sure.merge")).html_safe })
        #end
      end
    end
    ar.compact.join(' / ').html_safe
  end

end

