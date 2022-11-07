# coding: utf-8
class ArtistsGrid < BaseGrid

  scope do
    Artist
  end

  def self.filter_include_ilike(col, type=:string, langcode: nil, **kwd)
    filter(col, type, **kwd) do |value|  # Only for PostgreSQL!
      str = preprocess_space_zenkaku(value, article_to_tail=true)
      trans_opts = {accept_match_methods: [:include_ilike]}
      trans_opts[:langcode] = langcode if langcode
      ids = self.find_all_by_a_title(:titles, str, uniq: true, **trans_opts).map(&:id)
      self.where id: ids
    end
  end

  ####### Filters #######

  #if ArtistsGrid.is_current_user_moderator  # This does now work because the method is not defined when this line is executed (even if it did, the value would not be set at this stage!).
    filter(:id, :integer, header: "ID")
  #end

  filter_include_ilike(:title_ja, header: I18n.t("datagrid.form.title_ja_en", default: "Title [ja+en] (partial-match)"))
  filter_include_ilike(:title_en, langcode: 'en', header: I18n.t("datagrid.form.title_en", default: "Title [en] (partial-match)"))

  filter(:year, :integer, range: true, header: I18n.t('tables.year')) # , default: proc { [User.minimum(:logins_count), User.maximum(:logins_count)] }

  begin
    sex_titles = Sex::ISO5218S.map{|i|
      se = Sex[i]
      Rails.logger.error "(#{__FILE__}): It seems ISO5218 in Sex.all have been modified: Sex[i=#{i.inspect}]==#{se.inspect}; Sex.all=#{Sex.all.inspect}" if !se
      word = se.title(langcode: I18n.locale)  # See log if this raises an ActionView::Template::Error, searching for "It seems ISO5218"
    }
  rescue #rescue ActionView::Template::Error  does not work for some reason!
    ## ISO5218 in one of Sexes must be modified.
    sex_titles = Sex.order(:iso5218).pluck(:iso5218).map(&:to_i).map{|i| word = Sex[i].title(langcode: I18n.locale)}
  end
  filter(:sex, :enum, checkboxes: true, select: sex_titles, header: I18n.t('tables.sex')) # , default: sex_titles) # allow_blank: false (Default; so if nothing is checked, this filter is ignored)
  # <https://github.com/bogdan/datagrid/wiki/Filters>
  #  (In Dynamic select option)
  #  IMPORTANT: Always wrap dynamic :select option with proc, so that datagrid fetch it from database each time when it renders the form.
  # NOTE: However, in this case, the contetns of Sex should not change, so it is not wrapped with Proc.

  filter(:max_per_page, :enum, select: MAX_PER_PAGES, default: 25, multiple: false, dummy: true, header: I18n.t("datagrid.form.max_per_page", default: "Max entries per page"))  # "default" is not working...

  column_names_filter(header: I18n.t("datagrid.form.extra_columns", default: "Extra Columns"), checkboxes: true)

  ####### Columns #######

  #if ArtistsGrid.is_current_user_moderator  # This does not work; see above
    column(:id, header: "ID")
  #end

  column(:title_ja, mandatory: true, header: I18n.t('tables.title_ja'), order: proc { |scope|
    #order_str = Arel.sql("convert_to(title, 'UTF8')")
    order_str = Arel.sql('title COLLATE "ja-x-icu"')
    scope.joins(:translations).where("langcode = 'ja'").order(order_str) #.order("title")
  }) do |record|
    record.title langcode: 'ja'
  end
  column(:ruby_romaji_ja, header: I18n.t('tables.ruby_romaji'), order: proc { |scope|
    order_str = Arel.sql('ruby COLLATE "ja-x-icu", romaji COLLATE "ja-x-icu"')
    scope.joins(:translations).where("langcode = 'ja'").order(order_str) #order("ruby").order("romaji")
  }) do |record|
    s = sprintf '[%s/%s]', *(%i(ruby romaji).map{|i| record.send(i, langcode: 'ja') || ''})
    s.sub(%r@/\]\z@, ']').sub(/\A\[\]\z/, '')  # If NULL, nothing is displayed.
  end
  column(:alt_title_ja, mandatory: true, header: I18n.t('tables.alt_title_ja'), order: proc { |scope|
    order_str = Arel.sql('alt_title COLLATE "ja-x-icu"')
    scope.joins(:translations).where("langcode = 'ja'").order(order_str)
  }) do |record|
    s = sprintf '%s [%s/%s]', *(%i(alt_title alt_ruby alt_romaji).map{|i| record.send(i, langcode: 'ja') || ''})
    s.sub(%r@ +\[/\]\z@, '')  # If NULL, nothing is displayed.
  end
  column(:title_en, mandatory: true, header: I18n.t('tables.title_en'), order: proc { |scope|
    scope.joins(:translations).where("langcode = 'en'").order("title")
  }) do |record|
    s = sprintf '%s [%s]', *(%i(title alt_title).map{|i| record.send(i, langcode: 'en') || ''})
    s.sub(%r@ +\[\]\z@, '')   # If NULL, nothing is displayed.
  end

  column(:sex, mandatory: true, header: I18n.t('tables.sex')) do |record|
    record.sex.title(langcode: I18n.locale)
  end

  column(:year, mandatory: false, header: I18n.t('tables.year')) do |record|
    sprintf '%s年%s月%s日', *(%i(birth_year birth_month birth_day).map{|m|
                                i = record.send m
                                (i.blank? ? '——' : i.to_s)
                              })
  end

  column(:place, header: I18n.t('tables.place')) do |record|
    ar = record.place.title_or_alt_ascendants(langcode: I18n.locale, prefer_alt: true);
    sprintf '%s %s(%s)', ar[1], ((ar[1] == Prefecture::UnknownPrefecture[I18n.locale] || ar[0].blank?) ? '' : '— '+ar[0]+' '), ar[2]
  end

  %w(ja en).each do |elc|
    kwd = 'wiki_'+elc
    column(kwd, mandatory: false, header: I18n.t('tables.'+kwd)) do |record|
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

  column(:n_musics, header: I18n.t('tables.n_musics')) do |record|
    record.musics.uniq.count
  end

  column(:n_harami_vids, header: I18n.t('tables.n_harami_vids')) do |record|
    record.harami_vids.uniq.count.to_s
  end

  column(:note, header: I18n.t('tables.note'))

  column(:updated_at, header: I18n.t('tables.updated_at'))
  column(:created_at, header: I18n.t('tables.created_at'))
  column(:actions, html: true, mandatory: true, header: I18n.t("tables.actions", default: "Actions")) do |record|
    #ar = [ActionController::Base.helpers.link_to('Show', record, data: { turbolinks: false })]
    ar = [link_to('Show', artist_path(record), data: { turbolinks: false })]
    if can? :update, record
      ar.push link_to('Edit', edit_artist_path(record))
      #if can?(:update, Artists::MergesController)
      #  ar.push ActionController::Base.helpers.link_to('Merge', artists_new_merge_users_path(record))
        if can? :destroy, record
          ar.push link_to('Destroy', artist_path(record), method: :delete, data: { confirm: (t('are_you_sure')+" "+t("are_you_sure.merge")).html_safe })
        end
      #end
    end
    ar.compact.join(' / ').html_safe
  end

end

class << ArtistsGrid
  # Setter/getter of {ArtistsGrid.current_user}
  attr_accessor :current_user
  attr_accessor :is_current_user_moderator
end

