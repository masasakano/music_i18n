# coding: utf-8
class Harami1129sGrid < BaseGrid

  scope do
    Harami1129
  end

  #def self.filter_split_ilike(col, type=:string, **kwd)
  #  filter(col, type, **kwd) do |value|  # Only for PostgreSQL!
  #    arval = value.strip.split(/\s*,\s*/)
  #    break nil if arval.size == 0
  #    ret = self.where(col.to_s+" ILIKE ?", '%'+arval[0]+'%')
  #    if arval.size > 1
  #      arval[1..-1].each do |es|
  #        ret = ret.or(self.where(col.to_s+' ILIKE ?', '%'+es+'%'))
  #      end
  #    end
  #    ret
  #  end
  #end

  filter(:id_remote, :integer)
  filter_split_ilike(:singer,  header: 'Singer (sep: ",") ILIKE')
  filter_split_ilike(:song,  header: 'Song (sep: ",") ILIKE')
  filter_split_ilike(:title, header: 'Title (sep: ",") ILIKE')
  filter(:release_date, :date, :range => true) # , default: proc { [User.minimum(:logins_count), User.maximum(:logins_count)] }
  filter(:link_time, :integer, header: 'Link time (eg, 0 [s])')

  filter(:max_per_page, :enum, select: MAX_PER_PAGES, default: 25, multiple: false, dummy: true, header: I18n.t("datagrid.form.max_per_page", default: "Max entries per page"))

  column_names_filter(header: I18n.t("datagrid.form.extra_columns", default: "Extra Columns"), checkboxes: true)

  column("✅".html_safe, :mandatory => true) do |record|
    record.populate_status.sorted_status(return_markers: true).first
  end
  column(:id) do |record|
    to_path = Rails.application.routes.url_helpers.harami1129_url(record, {only_path: true}.merge(ApplicationController.new.default_url_options))
    ActionController::Base.helpers.link_to record.id, to_path
  end
  column(:id_remote, :mandatory => true, header: '#Row') do |record|
    to_path = Rails.application.routes.url_helpers.harami1129_url(record, {only_path: true}.merge(ApplicationController.new.default_url_options))
    ActionController::Base.helpers.link_to record.id_remote, to_path
  end
  column(:singer, :mandatory => true) do |record|
    st = record.populate_status
    st.marker(:ins_singer) + (record.singer || '') + 
    ((st.status(:ins_singer) == :org_inconsistent) ? " (⇔ "+(st.dest_current(:ins_singer) || '""')+")" : '')
  end
  column(:song, :mandatory => true) do |record|
    st = record.populate_status
    st.marker(:ins_song) + (record.song || '') +
    ((st.status(:ins_song) == :org_inconsistent) ? " (⇔ "+(st.dest_current(:ins_song) || '""')+")" : '')
  end
  column(:title, header: 'Title (⇔ Ins_Title)', :mandatory => true) do |record|
    st = record.populate_status
    st.marker(:ins_title).html_safe+link_to_youtube(record.title, record.link_root, record.link_time) +
    ((st.status(:ins_title) == :org_inconsistent) ? "<br>⇔ ".html_safe+(st.dest_current(:ins_title) || '""') : '')
  end
  date_column(:release_date, :mandatory => true) #do |record|
  #  record.populate_status.marker(:ins_release_date) + (record.release_date || '')
  #end
  column(:link_root) do |record|
    st = record.populate_status
    st.marker(:ins_link_root) + (record.link_root || '') +
    ((st.status(:ins_link_root) == :org_inconsistent) ? " (⇔ "+(st.dest_current(:ins_link_root) || '""')+")" : '')
  end
  column(:link_time) do |record|
    st = record.populate_status
    st.marker(:ins_link_time) + (record.link_time.to_s || '') +
    ((st.status(:ins_link_time) == :org_inconsistent) ? " (⇔ "+(st.dest_current(:ins_link_time) || '""')+")" : '')
  end

  column(:not_music)

  column(:ins_singer)
  column(:ins_song)
  column(:ins_title) do |record|
    link_to_youtube record.ins_title, record.ins_link_root, record.ins_link_time
  end
  date_column(:ins_release_date)
  column(:ins_link_root)
  column(:ins_link_time)
  column(:harami_vid_id, header: 'Vid') do |record|
    (record.harami_vid_id ? ActionController::Base.helpers.link_to(record.harami_vid_id, Rails.application.routes.url_helpers.harami_vid_url(record.harami_vid_id, only_path: true)) : '')
  end
  column(:engage_id) do |record|
    (record.engage_id ? ActionController::Base.helpers.link_to(record.engage_id, Rails.application.routes.url_helpers.engage_url(record.engage_id, only_path: true)) : '')
  end
  column(:note, :mandatory => true)
  column(:last_downloaded_at)
  column(:orig_modified_at)
  column(:ins_at)
  column(:checked_at)
  column(:updated_at)
  column(:created_at)
  column(:actions, :html => true, :mandatory => true) do |record|
    [link_to('Show', record, data: { turbolinks: false }),
     (record.harami_vid ? link_to('HVid', harami_vid_path(record.harami_vid), title: 'HaramiVid imported from this record (and possibly also from other records)') : nil),
     link_to('Edit', edit_harami1129_path(record)),
     link_to('Destroy', record, method: :delete, data: { confirm: t('are_you_sure') }),
     ((record.ins_at && !record.ins_title.blank? && (record.ins_song.blank? || !record.ins_song.blank?) && (record.ins_singer.blank? || !record.ins_singer.blank?) && !record.ins_link_root.blank? && !record.ins_release_date.blank?) ? nil : link_to('InsertToInsCols', harami1129_internal_insertions_path(harami1129_id: record.id), method: :patch, title: 'Perform insertion to ins_* columns within the table row.')),
     (%i(checked consistent no_insert).include?(record.populate_status.sorted_status.first) ? nil :
        button_to('Populate', harami1129_populate_url(harami1129_id: record.id), method: :patch))
   ].compact.join(' / ').html_safe

  end

end

class << Harami1129sGrid
  # Setter/getter of {Harami1129sGrid.current_user}
  attr_accessor :current_user
  attr_accessor :is_current_user_moderator
end

