# coding: utf-8
class ChannelsGrid < ApplicationGrid

  scope do
    Channel.all
  end

  ####### Filters #######

  filter_n_column_id(:channel_url)  # defined in application_grid.rb

  filter_ilike_title(:ja)  # defined in application_grid.rb
  filter_ilike_title(:en)  # defined in application_grid.rb

  filter(:channel_owner, :enum, dummy: true, multiple: false, include_blank: true, select: Proc.new{
           sorted_title_ids(ChannelOwner.joins(channels: :harami_vids).distinct, langcode: I18n.locale)},  # filtering out those none of HaramiVid belong to; sorted_title_ids() defined in application_helper.rb
         header: Proc.new{I18n.t("harami_vids.table_head_ChannelOwner", default: "Channel owner")}) do |value|  # Only for PostgreSQL!
    list = [value].flatten.map{|i| i.blank? ? nil : i}.compact
    self.where("channel_owner_id" => list)
  end

  filter(:channel_platform, :enum, dummy: true, multiple: false, include_blank: true, select: Proc.new{
           sorted_title_ids(ChannelPlatform.joins(channels: :harami_vids).distinct, langcode: I18n.locale)},  # filtering out those none of HaramiVid belong to; sorted_title_ids() defined in application_helper.rb
         header: Proc.new{I18n.t("harami_vids.table_head_ChannelPlatform", default: "Channel platform")}) do |value|  # Only for PostgreSQL!
    list = [value].flatten.map{|i| i.blank? ? nil : i}.compact
    self.where("channel_platform_id" => list)
  end

  filter(:channel_type, :enum, dummy: true, multiple: false, include_blank: true, select: Proc.new{
           sorted_title_ids(ChannelType.joins(channels: :harami_vids).distinct, langcode: I18n.locale)},  # filtering out those none of HaramiVid belong to; sorted_title_ids() defined in application_helper.rb
         header: Proc.new{I18n.t("harami_vids.table_head_ChannelType", default: "Channel type")}) do |value|  # Only for PostgreSQL!
    list = [value].flatten.map{|i| i.blank? ? nil : i}.compact
    self.where("channel_type_id" => list)
  end

  column_names_max_per_page_filters  # defined in base_grid.rb ; calling column_names_filter() and filter(:max_per_page)

  ####### Columns #######

  # ID first (already defined in the head of the filters section)

  column(:id_at_platform)
  column(:id_human_at_platform, header: "@Id")

  # Following is defined in application_grid.rb, not displaying multiple candidate Translations.
  column_title_ja  
  column_title_en(Channel, mandatory: true)

  column_model_trans_belongs_to(:channel_owner, mandatory: true, header: Proc.new{I18n.t("harami_vids.table_head_ChannelOwner")}, with_link: :class)  # defined in application_grid.rb
  column_model_trans_belongs_to(:channel_platform, mandatory: true, header: Proc.new{I18n.t("harami_vids.table_head_ChannelPlatform")}, with_link: false)  # defined in application_grid.rb
  column_model_trans_belongs_to(:channel_type, mandatory: true, header: Proc.new{I18n.t("harami_vids.table_head_ChannelType")}, with_link: false)  # defined in application_grid.rb

  column_n_harami_vids    # defined in application_grid.rb
  #column(:n_harami_vids, tag_options: {class: ["align-cr", "align-r-padding3"]}, header: Proc.new{I18n.t('tables.n_harami_vids')}) do |record|
  #  record.harami_vids.count.to_s
  #end

  [:update_user, :create_user].each do |colname|
    header = colname.to_s.sub(/_user$/, "").capitalize+"d"
    column(colname, html: true, header: header, tag_options: {class: ["moderator_only"]}, if: Proc.new{ApplicationGrid.qualified_as?(:moderator)}) do |record| 
      safe_content =
        if can? :update, Users::EditRolesController
          ur = record.create_user
          ur ? link_to(ur.display_name, ur) : "".html_safe
        else
          "".html_safe
        end

      safe_html_in_tagpair(safe_content, tag_class: "moderator_only")  # defined in application_helper.rb
    end
  end
  
  column_note             # defined in application_grid.rb
  columns_upd_created_at  # defined in application_grid.rb

  column_actions(with_destroy: true)  # defined in application_grid.rb

end

