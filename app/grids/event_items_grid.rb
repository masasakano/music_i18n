# coding: utf-8
class EventItemsGrid < ApplicationGrid

  scope do
    EventItem.all
  end

  ####### Filters #######

  filter_n_column_id(:event_item_url)  # defined in application_grid.rb

  filter(:machine_title, :string) do |value|  # Only for PostgreSQL!
    self.where("event_items.machine_title ILIKE ?", "%"+value+"%")
  end

  filter(:start_time, :datetime, range: true, header: Proc.new{I18n.t('tables.start_time')+" (< #{Date.current.to_s})"}) # , default: proc { [User.minimum(:logins_count), User.maximum(:logins_count)] }
  filter(:duration_minute, :float, range: true, header: Proc.new{I18n.t('tables.duration')}) # float in DB # , default: proc { [User.minimum(:logins_count), User.maximum(:logins_count)] }

  filter(:event_group, :enum, dummy: true, select: Proc.new{
           EventGroup.all.order(:start_date).map{|i| [s=i.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either, prefer_shorter: true), i.id]}},
         header: Proc.new{I18n.t(:EventGroup, default: "Event Group")}) do |value|  # Only for PostgreSQL!
    self.joins(event: :event_group).where("event_group.id" => [value].flatten)
  end

#  filter_partial_str(:artists, header: Proc.new{I18n.t('datagrid.form.artists_multi')})
#  filter(:artist_collabs, :enum, multiple: true, include_blank: true, dummy: true, header: Proc.new{I18n.t('datagrid.form.artist_collabs_multi', default: "Collab Artists")}, select: Proc.new{
#           sorted_title_ids(Artist.joins(:artist_music_plays).distinct, langcode: I18n.locale)}) do |value|  # Only for PostgreSQL! ; sorted_title_ids() defined in application_helper.rb
#    list = [value].flatten.map{|i| i.blank? ? nil : i}.compact
#    if list.empty?
#      self
#    else
#      # self.joins(:artist_music_plays).where("artist_music_plays.artist_id" => list).distinct  # => this would fail in ordering by title (in PostgreSQL).
#      allids = EventItem.joins(:artist_music_plays).where("artist_music_plays.artist_id" => list).distinct.ids
#      self.where(id: allids)
#    end
#  end

  filter_partial_str(:musics,  header: Proc.new{I18n.t('datagrid.form.musics_multi')})

#  filter(:collabs_only, :boolean, dummy: true, default: false,
#         header: Proc.new{I18n.t("harami_vids.table_filter_collabs_only", default: "Videos with Collab-Artists only?")}) do |value|
#    #(value ? self.joins(:artist_music_plays).where.not("artist_music_plays.artist_id" => Artist.default(:EventItem).id).distinct : self)  # => FATAL: SELECT DISTINCT, ORDER BY expressions must appear...
#    # NOTE: The first object must be EventItem and NOT self; if it was self, already "pagered" self (".limit(n)"?) would be passed.
#    value ? (allids=EventItem.joins(:artist_music_plays).where.not("artist_music_plays.artist_id" => Artist.default(:EventItem).id).distinct.ids; self.where(id: allids)) : self
#  end

  column_names_max_per_page_filters  # defined in base_grid.rb ; calling column_names_filter() and filter(:max_per_page)

  ####### Columns #######

  # ID first (already defined in the head of the filters section)

  column(:machine_title, mandatory: true, header: "machine_title")

  column(:start_time,     mandatory: true,  header: Proc.new{I18n.t('tables.start_time')})
  column(:start_time_err, mandatory: false, header: "StartTime Err[hr]") do |record|
    (err=record.start_time_err) ? sprintf("%.1f", err/3600.0) : ""
  end
  #date_column(:release_date, mandatory: true)  # => ERROR...

  column(:publish_date, mandatory: true, order: :publish_date)

  column(:duration_minute, mandatory: true, order: :duration_minute, tag_options: { class: ["align-cr"] }, header: "Duration[m]") # float in DB # , default: proc { [User.minimum(:logins_count), User.maximum(:logins_count)] }

  column(:duration_minute_err, order: :duration_minute_err, tag_options: {class: ["align-cr"]}, header: "DurationErr[m]") do |record| # float in DB # , default: proc { [User.minimum(:logins_count), User.maximum(:logins_count)] }
    sec2hms_or_ms(record.duration_minute_err, return_nil: true)  # in application_helper.rb
  end

  column(:place, html: true, mandatory: true, header: Proc.new{I18n.t('tables.place')}) do |record|
    #txt_caution = "".html_safe
    #if can?(:read, EventItem) && !record.is_place_all_consistent?(strict: true)
    #  txt_caution = '<span title="Inconsistent with EventItems and/or Events">†</span>'.html_safe
    #end
    ERB::Util.html_escape(record.place.pref_pla_country_str(langcode: I18n.locale, lang_fallback_option: :either, prefer_shorter: true)) #+ txt_caution
  end

  column(:n_amps, tag_options: {class: ["align-cr", "editor_only"]}, header: Proc.new{I18n.t('datagrid.form.n_amps')}, if: Proc.new{ApplicationGrid.qualified_as?(:editor)}) do |record|
    record.artist_music_plays.uniq.count
  end

  column(:musics,  html: true, mandatory: true, header: I18n.t(:Musics)) do |record|
    onecanread ||= (can?(:read, EventItem) ? 1 : 0)
    ### This does not work with PostgreSQL sorting error... (with Translation.sort)
    # list_linked_musics(record.musics, with_link: (onecanread==1), with_bf_for_trimmed: true) # defined in MusicsHelper
    print_list_inline(record.musics.uniq){ |tit, model|  # SELECT "dintinct" would not work well with ordering.
      titmod = definite_article_to_head(tit)
      (onecanread==1) ? link_to(titmod, music_path(model)) : titmod
    }  # defined in application_helper.rb
  end
  column(:artists, html: true, mandatory: true, header: I18n.t(:Artists)) do |record|
    onecanread ||= (can?(:read, EventItem) ? 1 : 0)
    print_list_inline(record.artists.uniq){ |tit, model|  # SELECT "dintinct" would not work well with ordering.
      titmod = definite_article_to_head(tit)
      (onecanread==1) ? link_to(titmod, artist_path(model)) : titmod
    }  # defined in application_helper.rb
  end

  column(:event, html: true, mandatory: false, header: Proc.new{I18n.t(:Event, default: "Event")}) do |record|
    ((evt=record.event) ? evt.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either) : nil)
  end

  column(:event_group, html: true, mandatory: false,  header: Proc.new{I18n.t(:EventGroup, default: "Event Group")}) do |record|
    ((evgr=record.event_group) ? link_to(evgr.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either), evgr) : nil)
  end

  column(:event_ratio, mandatory: false)
  column(:weight, mandatory: true)

  column_note             # defined in application_grid.rb
  columns_upd_created_at  # defined in application_grid.rb

  column_actions  # defined in application_grid.rb

end

