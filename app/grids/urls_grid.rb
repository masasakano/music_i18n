# coding: utf-8
class UrlsGrid < ApplicationGrid

  scope do
    Url.all
  end

  ####### Filters #######

  filter_n_column_id(:url_url)  # defined in application_grid.rb

  filter(:url, :string, multiple: false, header: "URL") do |value, scope|
    scope.where("url ILIKE ?", "%#{value}%")
  end

 filter_include_ilike(:title_ja, header: Proc.new{I18n.t("datagrid.form.title_ja_en", default: "Title [ja+en] (partial-match)")}, input_options: {autocomplete: 'off'})

 filter(:url_langcode, :enum, header: "Locales", checkboxes: true, select: Proc.new{([]+Url.all.pluck(:url_langcode).uniq.compact).sort{|a, b|
   ar = [a, b].map{|i|
     case i
     when "ja"
       "a"
     when "aa"
       "a"*50
     when "en"
       "aa"
     when "fr"
       "aaa"
     when "", nil
       "z"*999
     else
       i
     end
   }
   ar[0] <=> ar[1]
 }.map{|c| [(c.present? ? c : "None"), c]} }) # ja, en, cn, fr, de, es, it, pt, zh, ...

  filter(:site_category_id, :enum, dummy: true, header: Proc.new{I18n.t(:SiteCategories)}, checkboxes: true, select: Proc.new{ SiteCategory.order(:weight).map{|es| [es.title_or_alt_for_selection, es.id]} }) do |values|
    self.joins(:site_category).where("site_categories.id" => values)
  end

  filter(:anchorable_type, :enum, dummy: true, header: "Classes", checkboxes: true, select: Proc.new{ Anchoring.pluck(:anchorable_type).uniq.compact.sort.map{|c| [c, c]} }) do |values|
    self.joins(:anchorings).where("anchorings.anchorable_type" => values)
  end

#  filter(:published_date, :date, range: true, header: Proc.new{I18n.t('tables.start_date')+" (< #{Date.current.to_s})"}) # , default: proc { [User.minimum(:logins_count), User.maximum(:logins_count)] }

  filter(:create_user, header: 'Create/Update User ("SELF" for yourself)') do |value|
    #cuser = ((defined?(CURRENT_USER) && CURRENT_USER) || TranslationsGrid.CURRENT_USER)  # Former is invalid and so the latter is accepted!
    cuser = ApplicationGrid::CURRENT_USER
    value = cuser.display_name if cuser && 'SELF' == value.strip.upcase
    self.joins("JOIN users ON users.id = translations.create_user_id OR users.id = translations.update_user_id").where('users.display_name = ?', value.strip)
  end

  column_names_max_per_page_filters  # defined in application_grid.rb ; calling column_names_filter() and filter(:max_per_page)

  ####### Columns #######

  # ID first (already defined in the head of the filters section)

  column(:site_category, html: true, mandatory: true,  header: Proc.new{I18n.t(:SiteCategory, default: "SiteCategory")}, order: ->(scope) {
    scope.joins(:site_category).order('site_categories.weight')
  } ) do |record|
    ((sc=record.site_category) ? sc.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either) : nil)
  end

  column(:url_langcode, mandatory: true, header: Proc.new{I18n.t(:language_short).capitalize}, tag_options: {class: ["text-center"]})

  column(:url, html: true, mandatory: true){ |record|
    # auto_link50(Addressable::URI.unencode(record.url))
    auto_link(record.url){|txt| truncate(Addressable::URI.unencode(txt).strip.sub(%r@^https://@, ""), length: 50) if txt }
  }

  column_title_ja         # defined in application_grid.rb
  column_title_en(Url)  # defined in application_grid.rb

  column(:url_noralized, mandatory: false, tag_options: { class: ["editor_only"] }, if: Proc.new{ApplicationGrid.qualified_as?(:editor)})
  column(:domain, mandatory: false, html: true, tag_options: { class: ["editor_only"] }, header: Proc.new{I18n.t(:Domain)}, if: Proc.new{ApplicationGrid.qualified_as?(:editor)}, order: ->(scope){
           scope.joins(:domain).order("domains.domain")
         } ) do |record|
    link_to record.domain.domain, record.domain, title: "Internal (pID=#{record.domain.id})"
  end
  column(:domain_title, mandatory: false, html: true, tag_options: { class: ["editor_only"] }, header: Proc.new{I18n.t(:DomainTitle)}, if: Proc.new{ApplicationGrid.qualified_as?(:editor)}) do |record|
    link_to record.domain_title.title_or_alt_for_selection, record.domain_title, title: "Generic title for the domain (pID=#{record.domain_title.id})"
  end

  column(:published_date, mandatory: false)
  column(:last_confirmed_date, mandatory: false)

  column(:n_amps, dummy: true, mandatory: true, tag_options: {class: ["text-center"]}, header: Proc.new{I18n.t('urls.table_head.n_links')}, if: Proc.new{ApplicationGrid.qualified_as?(:editor)}) do |record|
    record.anchorables.count
  end

  column(:anchorables,  html: true, mandatory: false, header: 'Anchorables<sup>†(Note)</sup>'.html_safe) do |record|
    print_list_inline(record.anchorables){ |tit, anchorable|  # SELECT "dintinct" would not work well with ordering.
      titmod = definite_article_to_head(tit)
      next titmod if !can?(:read, anchorable)
      ret = link_to(truncate(titmod, length: 30), Rails.application.routes.url_helpers.polymorphic_path(anchorable, only_path: true))
      anc = anchorable.anchorings.find_by(url_id: record.id)
      postfix = ERB::Util.html_escape(anc.note.strip).gsub(/"/, '&quot;') if anc.note.present?
      sprintf('[%s] %s<span title="(Anchoring#note) %s">†</span>', anchorable.class.name, ret, postfix).html_safe
    }  # defined in application_helper.rb
  end

  column(:weight, mandatory: false, tag_options: {class: ["editor_only"]}, if: Proc.new{ApplicationGrid.qualified_as?(:moderator)})

  column_display_user(:update_user, tag_options: {class: ["editor_only"]})  # defined in application_grid.rb
  column_display_user(:create_user, tag_options: {class: ["editor_only"]})  # defined in application_grid.rb

  column_note             # defined in application_grid.rb
  columns_upd_created_at(Url)  # defined in application_grid.rb

  column_actions  # defined in application_grid.rb

end

