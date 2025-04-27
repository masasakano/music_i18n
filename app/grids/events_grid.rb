# coding: utf-8
class EventsGrid < ApplicationGrid

  scope do
    Event.all
  end

  ####### Filters #######

  filter_n_column_id(:event_url)  # defined in application_grid.rb

  filter(:event_group, :enum, dummy: true, select: Proc.new{
           EventGroup.all.order(:start_date).map{|i| [s=i.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either, prefer_shorter: true), i.id]}},
         header: Proc.new{I18n.t(:EventGroup, default: "Event Group")}) do |value|  # Only for PostgreSQL!
    self.joins(:event_group).where("event_group.id" => [value].flatten)
  end

  filter_include_ilike(:title_ja, header: Proc.new{I18n.t("datagrid.form.title_ja_en", default: "Title [ja+en] (partial-match)")}, input_options: {autocomplete: 'off'})

  filter(:start_time, :datetime, range: true, header: Proc.new{I18n.t('tables.start_time')+" (< #{Date.current.to_s})"}) # , default: proc { [User.minimum(:logins_count), User.maximum(:logins_count)] }
  filter(:duration_hour, :float, range: true, header: Proc.new{I18n.t('tables.duration_hour')}) # float in DB # , default: proc { [User.minimum(:logins_count), User.maximum(:logins_count)] }

  filter(:prefecture_id, :enum, multiple: true, include_blank: true,
         header: Proc.new{I18n.t("datagrid.form.prefectures")}, select: proc_select_prefectures) do |values|  # defined in application_grid.rb
    self.joins(:place).where("places.prefecture_id": values)
  end

#  filter_partial_str(:artists, header: Proc.new{I18n.t('datagrid.form.artists_multi')})
#  filter(:artist_collabs, :enum, multiple: true, include_blank: true, dummy: true, header: Proc.new{I18n.t('datagrid.form.artist_collabs_multi', default: "Collab Artists")}, select: Proc.new{
#           sorted_title_ids(Artist.joins(:artist_music_plays).distinct, langcode: I18n.locale)}) do |value|  # Only for PostgreSQL! ; sorted_title_ids() defined in application_helper.rb
#    list = [value].flatten.map{|i| i.blank? ? nil : i}.compact
#    if list.empty?
#      self
#    else
#      # self.joins(:artist_music_plays).where("artist_music_plays.artist_id" => list).distinct  # => this would fail in ordering by title (in PostgreSQL).
#      allids = Event.joins(:artist_music_plays).where("artist_music_plays.artist_id" => list).distinct.ids
#      self.where(id: allids)
#    end
#  end

#  filter_partial_str(:musics,  header: Proc.new{I18n.t('datagrid.form.musics_multi')})

#  filter(:collabs_only, :boolean, dummy: true, default: false,
#         header: Proc.new{I18n.t("harami_vids.table_filter_collabs_only", default: "Videos with Collab-Artists only?")}) do |value|
#    #(value ? self.joins(:artist_music_plays).where.not("artist_music_plays.artist_id" => Artist.default(:Event).id).distinct : self)  # => FATAL: SELECT DISTINCT, ORDER BY expressions must appear...
#    # NOTE: The first object must be Event and NOT self; if it was self, already "pagered" self (".limit(n)"?) would be passed.
#    value ? (allids=Event.joins(:artist_music_plays).where.not("artist_music_plays.artist_id" => Artist.default(:Event).id).distinct.ids; self.where(id: allids)) : self
#  end

  column_names_max_per_page_filters  # defined in application_grid.rb ; calling column_names_filter() and filter(:max_per_page)

  ####### Columns #######

  # ID first (already defined in the head of the filters section)

  column_title_ja         # defined in application_grid.rb
  column_title_en(Event)  # defined in application_grid.rb

  column(:start_time,     mandatory: true,  header: Proc.new{I18n.t('tables.start_time')})
  column(:start_time_err, mandatory: false, header: Proc.new{I18n.t('tables.start_time_err_hr_short')}) do |record|
    (err=record.start_time_err) ? sprintf("%.1f", err/3600.0) : ""
  end

  #column(:publish_date, mandatory: true, order: :publish_date)

  column(:weight, mandatory: false, tag_options: { class: ["editor_only"] }, if: Proc.new{ApplicationGrid.qualified_as?(:editor)})

  column(:duration_hour, mandatory: true, order: :duration_hour, tag_options: { class: ["align-cr"] }, header: Proc.new{I18n.t('tables.duration_hour')}) do |record| # float in DB # , default: proc { [User.minimum(:logins_count), User.maximum(:logins_count)] }
    next record.duration_hour if !record.duration_hour
    next record.duration_hour if record.duration_hour < 0
    "%.3g" % record.duration_hour
  end

  column(:place, html: true, mandatory: true, header: Proc.new{I18n.t('tables.place')}) do |record|
    #txt_caution = "".html_safe
    #if can?(:read, Event) && !record.is_place_all_consistent?(strict: true)
    #  txt_caution = '<span title="Inconsistent with Events and/or Events">†</span>'.html_safe
    #end
    ERB::Util.html_escape(record.place.pref_pla_country_str(langcode: I18n.locale, lang_fallback_option: :either, prefer_shorter: true)) #+ txt_caution
  end

  #column(:n_amps, tag_options: {class: ["align-cr", "editor_only"]}, header: Proc.new{I18n.t('datagrid.form.n_amps')}, if: Proc.new{ApplicationGrid.qualified_as?(:editor)}) do |record|
  #  record.artist_music_plays.uniq.count
  #end

  column(:musics,  html: true, mandatory: false, header: I18n.t(:Musics)) do |record|
    print_list_inline(record.music_hvids.uniq){ |tit, model|  # SELECT "dintinct" would not work well with ordering.
      titmod = definite_article_to_head(tit)
      can?(:read, Event) ? link_to(titmod, music_path(model)) : titmod
    }  # defined in application_helper.rb
  end
  column(:artists, html: true, mandatory: false, header: I18n.t(:Artists)) do |record|
    print_list_inline(record.artist_hvids.uniq){ |tit, model|  # SELECT "dintinct" would not work well with ordering.
      titmod = definite_article_to_head(tit)
      can?(:read, Event) ? link_to(titmod, artist_path(model)) : titmod
    }  # defined in application_helper.rb
  end

  column(:event_group, html: true, mandatory: false,  header: Proc.new{I18n.t(:EventGroup, default: "Event Group")}) do |record|
    ((evgr=record.event_group) ? link_to(evgr.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either), evgr) : nil)
  end

  column(:event_items, html: true, mandatory: false,  header: Proc.new{I18n.t(:EventItems, default: "Event Items")}, tag_options: { class: ["editor_only"] }, if: Proc.new{ApplicationGrid.qualified_as?(:editor)}) do |record|
    next nil if !record.event_items.exists?
    record.event_items.order("event_items.weight", "event_items.start_time",  "event_items.created_at").map.with_index{|evit, i|
      tit = sprintf("[Weight=%s] %s", ((w=evit.weight) ? w.to_s : "nil"), evit.machine_title)
      link_to(i+1, evit, title: tit)
    }.join(", ").html_safe
  end

  column_note             # defined in application_grid.rb
  columns_upd_created_at(Event)  # defined in application_grid.rb

  column_actions  # defined in application_grid.rb

end

