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

  column_all_titles  # defined in application_grid.rb

  column_model_trans_belongs_to(:sex, tag_options: {class: ["text-center"]}, mandatory: true, order: false, header: Proc.new{I18n.t('tables.sex')}, with_link: false)  # defined in application_grid.rb

  column(:birth_year, html: true, tag_options: {class: ["align-cr"]}, mandatory: false, header: Proc.new{I18n.t('artists.show.birthday')}) do |record|
    fmt =
      case I18n.locale
      when :ja, "ja", nil
        '%s年%s月%s日'
      else
        '%s-%s-%s'
      end
    sprintf fmt, *(%i(birth_year birth_month birth_day).map{|m|
                     i = record.send m
                     (i.blank? ? '——' : i.to_s)
                   })
  end

  column_place  # defined in application_grid.rb

  column(:channel_owner, header: Proc.new{I18n.t('ChannelOwner')}) do |record|
    (co=record.channel_owner) ? ActionController::Base.helpers.link_to(I18n.t("ChannelOwner"), Rails.application.routes.url_helpers.channel_owner_url(co, only_path: true)) : ""
  end
  ### Here, this method below is not called so that the link-text is special and it is not sortable
  # column_model_trans_belongs_to(:channel_owner, header: Proc.new{I18n.t('ChannelOwner')}, with_link: :class)  # defined in application_grid.rb

  column_n_models_belongs_to(:n_musics, :musics, distinct: false, header: Proc.new{I18n.t('tables.n_musics')})
  column_n_harami_vids    # defined in application_grid.rb

  %w(ja en).each do |elc|
    kwd = 'wiki_'+elc
    column(kwd, mandatory: false, order: false, header: Proc.new{I18n.t('tables.'+kwd)}) do |record|
      uri = record.wiki_uri(elc)
      if uri.blank?
        '——'
      else
        str_link = File.basename(uri)
        str_link = CGI.unescape(str_link) if str_link.include? '%'
        ActionController::Base.helpers.link_to(str_link, uri, target: "_blank")
      end
    end
  end

  column_note             # defined in application_grid.rb
  columns_upd_created_at(Artist)  # defined in application_grid.rb

  column_actions(with_destroy: false) do |record| # defined in application_grid.rb
    # This is relevant only when User can :update
    can?(:update, Musics::MergesController) ? link_to('Merge', artists_new_merges_path(record)) : nil
  end

end

