# coding: utf-8
class HaramiVidsGrid < BaseGrid

  scope do
    HaramiVid.all
  end

  ####### Filters #######

  filter(:id, :integer, header: "ID", if: Proc.new{CURRENT_USER && CURRENT_USER.editor?})  # displayed only for editors

  filter_include_ilike(:title_ja, header: Proc.new{I18n.t("datagrid.form.title_ja_en", default: "Title [ja+en] (partial-match)")})
  filter_include_ilike(:title_en, langcode: 'en', header: Proc.new{I18n.t("datagrid.form.title_en", default: "Title [en] (partial-match)")})

  filter(:duration, :integer, range: true, header: Proc.new{I18n.t('tables.duration')}) # float in DB # , default: proc { [User.minimum(:logins_count), User.maximum(:logins_count)] }
  filter(:release_date, :date, range: true, header: Proc.new{I18n.t('tables.release_date')}) # , default: proc { [User.minimum(:logins_count), User.maximum(:logins_count)] }

  filter(:channel_owner, :enum, dummy: true, select: Proc.new{
           ChannelOwner.joins(channels: :harami_vids).distinct.map{|i| [s=i.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either), i.id]}},  # filtering out those none of HaramiVid belong to
         header: Proc.new{I18n.t("harami_vids.table_head_ChannelOwner", default: "Channel owner")}) do |value|  # Only for PostgreSQL!
    self.joins(channel: :channel_owner).where("channel_owner.id" => [value].flatten)
  end
  filter(:channel_type, :enum, dummy: true, select: Proc.new{
           ChannelType.joins(channels: :harami_vids).distinct.order(:weight).map{|i| [s=i.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either), i.id]}},  # filtering out those none of HaramiVid belong to
         header: Proc.new{I18n.t("harami_vids.table_head_ChannelType", default: "Channel type")}) do |value|  # Only for PostgreSQL!
    self.joins(channel: :channel_type).where("channel_type.id" => [value].flatten)
  end
  # filter(:flag_by_harami, :xboolean, header: Proc.new{I18n.t('datagrid.form.by_harami_full', default: "Produced by Haramichan?")})

  filter_partial_str(:artists, header: Proc.new{I18n.t('datagrid.form.artists_multi')})
  filter_partial_str(:musics,  header: Proc.new{I18n.t('datagrid.form.musics_multi')})

  column_names_max_per_page_filters  # defined in base_grid.rb
  # column_names_filter(header: Proc.new{I18n.t("datagrid.form.extra_columns", default: "Extra Columns")}, checkboxes: true)
  # filter(:max_per_page, :enum, select: MAX_PER_PAGES, default: 25, multiple: false, dummy: true, header: Proc.new{I18n.t("datagrid.form.max_per_page", default: "Max entries per page")})

  ####### Columns #######

  column(:id, class: ["align-cr"], header: "ID", if: Proc.new{CURRENT_USER && CURRENT_USER.editor?}) do |record|
    to_path = Rails.application.routes.url_helpers.harami1129_url(record, {only_path: true}.merge(ApplicationController.new.default_url_options))
    ActionController::Base.helpers.link_to record.id, to_path
  end

  column(:title_ja, mandatory: true, header: Proc.new{I18n.t('tables.title_ja')}, order: proc { |scope|
    #order_str = Arel.sql("convert_to(title, 'UTF8')")
    order_str = Arel.sql('title COLLATE "ja-x-icu"')
    scope.joins(:translations).where("langcode = 'ja'").order(order_str) #.order("title")
  }) do |record|
    record.title langcode: 'ja', lang_fallback: false
  end
  column(:title_en, mandatory: (I18n.locale.to_sym != :ja), header: Proc.new{I18n.t('tables.title_en')}, order: proc { |scope|
    scope_with_trans_order(scope, HaramiVid, langcode="en")  # defined in base_grid.rb
  }) do |record|
    record.title langcode: 'en', lang_fallback: false
  end

  column(:release_date, mandatory: true, header: Proc.new{I18n.t('tables.release_date')})
  #date_column(:release_date, mandatory: true)  # => ERROR...

  column(:duration, range: true, class: ["align-cr"], header: Proc.new{I18n.t('tables.duration')}) do |record| # float in DB # , default: proc { [User.minimum(:logins_count), User.maximum(:logins_count)] }
    (i=record.duration) ? i.round : ""
  end
  column(:n_musics, class: ["align-cr"], header: Proc.new{I18n.t('datagrid.form.n_musics_general')}) do |record|
    record.musics.uniq.count
  end

  column(:musics,  html: true, mandatory: true, header: I18n.t(:Musics)) do |record|
    print_list_inline(record.musics.uniq){ |tit, model|  # SELECT "dintinct" would not work well with ordering.
      can?(:read, EventItem) ? link_to(tit, music_path(model)) : tit
    }  # defined in application_helper.rb
  end
  column(:artists, html: true, mandatory: true, header: I18n.t(:Artists)) do |record|
    print_list_inline(record.artists.uniq){ |tit, model|  # SELECT "dintinct" would not work well with ordering.
      can?(:read, EventItem) ? link_to(tit, artist_path(model)) : tit
    }  # defined in application_helper.rb
  end

  column(:place, header: Proc.new{I18n.t('tables.place')}) do |record|
    ar = record.place.title_or_alt_ascendants(langcode: I18n.locale, prefer_alt: true);
    sprintf '%s %s(%s)', ar[1], ((ar[1] == Prefecture::UnknownPrefecture[I18n.locale] || ar[0].blank?) ? '' : '— '+ar[0]+' '), ar[2]
  end

  column(:uri, mandatory: true, order: false) do |record|
    link_to_youtube record.uri, record.uri
  end

  column(:channel, html: true, header: Proc.new{sprintf "%s [%s]", I18n.t(:Channel, default: "Channel"), I18n.t("harami_vids.table_head_ChannelType", default: "Type")}) do |record|
    tit = ((cha=record.channel) ? cha.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either) : nil)
    kind = ((cha && typ=cha.channel_type) ? typ.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either) : "").sub(/の?チャンネル|\s*channel/i, "")
    next "" if !tit
    tit = h(tit)
    sprintf("%s [%s]", (can?(:read, cha) ? link_to(tit, channel_path(cha)) : tit), kind).html_safe
  end

  column(:owner, html: true, header: Proc.new{I18n.t("harami_vids.table_head_ChannelOwner", default: "Owner")}) do |record|
    tit = ((cha=record.channel) ? cha.channel_owner.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either) : nil)
    next "" if !tit
    (can?(:read, cha) ? link_to(tit, channel_owner_path(cha)) : tit)
  end

  column(:platform, html: true, header: Proc.new{I18n.t("harami_vids.table_head_ChannelPlatform", default: "Platform")}) do |record|
    tit = ((cha=record.channel) ? cha.channel_platform.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either) : nil)
    next "" if !tit
    tit
  end

  column(:events, html: true, header: Proc.new{I18n.t(:Events)}) do |record|
    print_list_inline(record.events){ |tit, model|
      can?(:read, EventItem) ? link_to(tit, event_path(model)) : tit
    }  # defined in application_helper.rb
  end

  column(:collabs, html: true, header: Proc.new{I18n.t("harami_vids.table_head_collabs", default: "featuring Artists")}) do |record|
    print_list_inline(record.artist_collabs){ |tit, model|
      tit = definite_article_to_head(tit)
      can?(:read, Artist) ? link_to(tit, artist_path(model)) : tit
    }  # defined in application_helper.rb
  end

  column(:flag_by_harami, class: ["align-cr"], header: Proc.new{I18n.t('datagrid.form.by_harami', default: "By Harami?")}) do |record|
    (record ? "Y" : (record.nil? ? "" : "N"))
  end

  column(:uri_playlist_ja, mandatory: false, order: false, header: Proc.new{I18n.t('datagrid.form.uri_playlist', langcode: "ja")}) do |record|
    link_to_youtube record.uri_playlist_ja, record.uri_playlist_ja
  end
  column(:uri_playlist_en, mandatory: false, order: false, header: Proc.new{I18n.t('datagrid.form.uri_playlist', langcode: "en")}) do |record|
    link_to_youtube record.uri_playlist_en, record.uri_playlist_en
  end

  column(:note, order: false, header: Proc.new{I18n.t('tables.note')})

  column(:updated_at, header: Proc.new{I18n.t('tables.updated_at')}, if: Proc.new{CURRENT_USER && CURRENT_USER.editor?})
  column(:created_at, header: Proc.new{I18n.t('tables.created_at')}, if: Proc.new{CURRENT_USER && CURRENT_USER.editor?})
  column(:actions, html: true, mandatory: true, order: false, header: Proc.new{I18n.t("tables.actions", default: "Actions")}) do |record|
    #ar = [ActionController::Base.helpers.link_to('Show', record, data: { turbolinks: false })]
    ar = [link_to('Show', harami_vid_path(record), data: { turbolinks: false })]
    if can? :update, record
      ar.push link_to('Edit', edit_harami_vid_path(record))
      if can? :destroy, record
        ar.push link_to('Destroy', harami_vid_path(record), method: :delete, data: { confirm: t('are_you_sure').html_safe })  # confirm: (t('are_you_sure')+" "+t("are_you_sure.merge")).html_safe
      end
    end
    ar.compact.join(' / ').html_safe
  end

end

