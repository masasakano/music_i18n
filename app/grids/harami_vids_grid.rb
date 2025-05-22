# coding: utf-8
class HaramiVidsGrid < ApplicationGrid

  scope do
    HaramiVid.all
  end

  ####### Filters #######

  filter_n_column_id(:harami_vid_url)  # defined in application_grid.rb

  filter_ilike_title(:ja)  # defined in application_grid.rb
  filter_ilike_title(:en)  # defined in application_grid.rb

  filter(:duration, :integer, range: true, header: Proc.new{I18n.t('tables.duration')}) # float in DB # , default: proc { [User.minimum(:logins_count), User.maximum(:logins_count)] }
  filter(:release_date, :date, range: true, header: Proc.new{I18n.t('tables.release_date')+" (< #{Date.current.to_s})"}) # , default: proc { [User.minimum(:logins_count), User.maximum(:logins_count)] }

  filter(:channel_owner, :enum, dummy: true, multiple: false, include_blank: true, select: Proc.new{
           sorted_title_ids(ChannelOwner.joins(channels: :harami_vids).distinct, langcode: I18n.locale)},  # filtering out those none of HaramiVid belong to; sorted_title_ids() defined in application_helper.rb
         header: Proc.new{I18n.t("harami_vids.table_head_ChannelOwner", default: "Channel owner")}) do |value|  # Only for PostgreSQL!
    list = [value].flatten.map{|i| i.blank? ? nil : i}.compact
    self.joins(channel: :channel_owner).where("channel_owner.id" => list)
  end
  filter(:channel_type, :enum, dummy: true, select: Proc.new{
           ChannelType.joins(channels: :harami_vids).distinct.order(:weight).map{|i| [s=i.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either), i.id]}},  # filtering out those none of HaramiVid belong to
         header: Proc.new{I18n.t("harami_vids.table_head_ChannelType", default: "Channel type")}) do |value|  # Only for PostgreSQL!
    self.joins(channel: :channel_type).where("channel_type.id" => [value].flatten)
  end

  filter_partial_str(:artists, header: Proc.new{I18n.t('datagrid.form.artists_multi')})
  filter(:artist_collabs, :enum, multiple: true, include_blank: true, dummy: true, header: Proc.new{I18n.t('datagrid.form.artist_collabs_multi', default: "Collab Artists")}, select: Proc.new{
           sorted_title_ids(Artist.joins(:artist_music_plays).distinct, langcode: I18n.locale)}) do |value|  # Only for PostgreSQL! ; sorted_title_ids() defined in application_helper.rb
    list = [value].flatten.map{|i| i.blank? ? nil : i}.compact
    if list.empty?
      self
    else
      # self.joins(:artist_music_plays).where("artist_music_plays.artist_id" => list).distinct  # => this would fail in ordering by title (in PostgreSQL).
      allids = HaramiVid.joins(:artist_music_plays).where("artist_music_plays.artist_id" => list).distinct.ids
      self.where(id: allids)
    end
  end

  filter_partial_str(:musics,  header: Proc.new{I18n.t('datagrid.form.musics_multi')})

  filter(:collabs_only, :boolean, dummy: true, default: false,
         header: Proc.new{I18n.t("harami_vids.table_filter_collabs_only", default: "Videos with Collab-Artists only?")}) do |value|
    #(value ? self.joins(:artist_music_plays).where.not("artist_music_plays.artist_id" => Artist.default(:HaramiVid).id).distinct : self)  # => FATAL: SELECT DISTINCT, ORDER BY expressions must appear...
    # NOTE: The first object must be HaramiVid and NOT self; if it was self, already "pagered" self (".limit(n)"?) would be passed.
    value ? (allids=HaramiVid.joins(:artist_music_plays).where.not("artist_music_plays.artist_id" => Artist.default(:HaramiVid).id).distinct.ids; self.where(id: allids)) : self
  end

  ###### this works only in limited occasions for some unknown reason...
  #
  # filter(:n_inconsistent, :integer, dummy: true, default: false,, range: true, header: "#Inconsistency", tag_options: {class: ["editor_only"]}, if: Proc.new{ApplicationGrid.qualified_as?(:editor)}) do |range|  # displayed only for editors
  #   allids = self.all.find_all{ |record|
  #     range.include? record.n_inconsistent_musics
  #   }.map(&:id)
  #   self.where(id: allids)
  # end

  column_names_max_per_page_filters  # defined in base_grid.rb ; calling column_names_filter() and filter(:max_per_page)

  ####### Columns #######

  # ID first (already defined in the head of the filters section)

  column_title_ja{|record, tit|  # defined in application_grid.rb
    link_to_youtube tit, record.uri  # not displaying other candidate Translations.
  }
  column_title_en(HaramiVid){|record, tit|  # defined in application_grid.rb
    link_to_youtube tit, record.uri  # not displaying other candidate Translations.
  }

  column(:release_date, mandatory: true, header: Proc.new{I18n.t('tables.release_date')})
  #date_column(:release_date, mandatory: true)  # => ERROR...

  column(:duration, order: :duration, tag_options: {class: ["align-cr"]}, header: Proc.new{I18n.t('tables.duration_nounit')}) do |record| # float in DB # , default: proc { [User.minimum(:logins_count), User.maximum(:logins_count)] }
    sec2hms_or_ms(record.duration, return_nil: true)  # in application_helper.rb
  end

  column_n_models_belongs_to(:n_musics, :musics, distinct: false, header: Proc.new{I18n.t('tables.n_musics')})
  column_n_models_belongs_to(:n_amps, :artist_music_plays, distinct: false, editor_only: true, header: Proc.new{I18n.t('datagrid.form.n_amps')})

  column(:musics,  html: true, mandatory: true, header: Proc.new{I18n.t(:Musics)}) do |record|
    onecanread ||= (can?(:read, EventItem) ? 1 : 0)
    list_linked_musics(record.musics, with_link: (onecanread==1), with_bf_for_trimmed: true) # defined in MusicsHelper
    #print_list_inline(record.musics.uniq){ |tit, model|  # SELECT "dintinct" would not work well with ordering.
    #  can?(:read, EventItem) ? link_to(tit, music_path(model)) : tit
    #}  # defined in application_helper.rb
  end
  column(:artists, html: true, mandatory: true, header: Proc.new{I18n.t(:Artists)}) do |record|
    onecanread ||= (can?(:read, EventItem) ? 1 : 0)
    list_linked_artists(record.artists, with_link: (onecanread==1), with_bf_for_trimmed: true) # defined in ArtistsHelper
  end

  # column_place  # defined in application_grid.rb
  column(:place, html: true, header: Proc.new{I18n.t('tables.place')}) do |record|
    txt_caution = "".html_safe
    if can?(:read, HaramiVid) && !record.is_place_all_consistent?(strict: true)
      txt_caution = '<span title="Inconsistent with EventItems and/or Events">†</span>'.html_safe
    end
    ERB::Util.html_escape(record.place.pref_pla_country_str(langcode: I18n.locale, lang_fallback_option: :either, prefer_shorter: true)) + txt_caution
  end

  column(:uri, order: false) do |record|
    link_to_youtube record.uri, record.uri
  end

  label_proc = Proc.new{sprintf "%s [%s]", I18n.t(:Channel, default: "Channel"), I18n.t("harami_vids.table_head_ChannelType", default: "Type")}
  ### This simple call is not used because the method below prints ChannelType as well.
  # column_model_trans_belongs_to(:channel, header: label_proc, with_link: :class)  # defined in application_grid.rb
  column(:channel, html: true, header: label_proc) do |record|
    tit = ((cha=record.channel) ? cha.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either) : nil)
    kind = ((cha && typ=cha.channel_type) ? typ.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either) : "").sub(/の?チャンネル|\s*channel/i, "")
    next "" if !tit
    tit = h(definite_article_to_head(tit))
    sprintf("%s [%s]", (can?(:read, cha) ? link_to(tit, channel_path(cha)) : tit), kind).html_safe
  end

  # ChannelOwner/Platform are shown to public, too. ChannelOwner's link is shown only for editors.
  column_model_trans_belongs_to(:channel_owner, header: Proc.new{I18n.t("harami_vids.table_head_ChannelOwner", default: "Owner")}, with_link: :class)  # defined in application_grid.rb
  column_model_trans_belongs_to(:channel_platform, header: Proc.new{I18n.t("harami_vids.table_head_ChannelPlatform", default: "Platform")}, with_link: false)  # defined in application_grid.rb

  column(:events, html: true, header: Proc.new{I18n.t(:Events)}) do |record|
    can_read_event_item = can?(:read, EventItem) if can_read_event_item.nil?
    events_and_groups_html(record, with_link: can_read_event_item, with_group_link: false)  # defined in harami_vids_helper.rb
    #print_list_inline(record.events.distinct, skip_title: true){ |_, model|
    #  can_read_event_item ? link_to(tit, event_path(model)) : tit
    #}  # defined in application_helper.rb
  end

  column(:collabs, html: true, header: Proc.new{I18n.t("harami_vids.table_head_collabs", default: "featuring Artists")}) do |record|
    def_artist = Artist.default(:HaramiVid)
    print_list_inline(record.artist_collabs.where.not(id: def_artist.id).distinct){ |tit, model|
      can?(:read, Artist) ? link_to(tit, artist_path(model)) : tit
    }  # defined in application_helper.rb
  end

  column(:collab_hows, html: true, header: Proc.new{I18n.t("harami_vids.table_head_collab_hows", default: "collaboration types")}) do |record|
    collab_hows_text(record)
    #def_artist = Artist.default(:HaramiVid)
    #record.artist_collabs.where.not(id: def_artist.id).distinct.ids
    ##print_list_inline(record.artist_collabs.where.not(id: def_artist.id).distinct){ |tit, model|
    ##  tit = definite_article_to_head(tit)
    ##  can?(:read, Artist) ? link_to(tit, artist_path(model)) : tit
    ##}  # defined in application_helper.rb
  end


##### NOTE: for some reason, this seems to work only in limited occassions and does not sort the entire table records...
#  column(:n_inconsistent, dummy: true, html: true, header: "#Inconsistent", tag_options: {class: "editor_only text-end"} # , order: proc {|scope|
#     #  # WARNING: Rails takes all records of the model on memory and calculates the result.  Very inefficient.
#     #  allids = scope.all.sort_by{ |record|
#     #    [record.missing_musics_from_amps.count + record.missing_musics_from_hvmas.count, (record.release_date || Date.today), record.id]
#     #  }.map(&:id)
#     #  join_sql = "INNER JOIN unnest('{#{allids.join(',')}}'::int[]) WITH ORDINALITY t(id, ord) USING (id)"  # PostgreSQL specific.
#     #  scope.where(id: allids).joins(join_sql).order("t.ord")
#     #      }
#  ) do |record|
#    nret = record.missing_musics_from_amps.count + record.missing_musics_from_hvmas.count
#    (nret == 0) ? "" : nret.to_s
#  end

  column_note             # defined in application_grid.rb
  columns_upd_created_at(HaramiVid)  # defined in application_grid.rb

  column_actions  # defined in application_grid.rb

end

