# coding: utf-8
class TranslationsGrid < BaseGrid

  TransModerator = Role['moderator', 'translation']
  Translator     = Role['editor',    'translation']

  scope do
    Translation.all
  end

  ####### Filters #######

  filter(:title, header: 'Title/Ruby keyword (partial match)') do |value|
    self.select_partial_str(:all, value, ignore_case: true)  # Only for PostgreSQL!
  end

  filter(:id, :integer, header: "ID", if: Proc.new{current_user && current_user.editor?})  # displayed only for editors

  filter(:translatable_type, :enum, header: "Class", checkboxes: true, select: Proc.new{ Translation.all.map{|c| [c.translatable_type, c.translatable_type]}.uniq })
  filter(:langcode, :enum, header: "Locale", checkboxes: true, select: Proc.new{ I18n.available_locales.map{|c| [c, c.to_s]} })

  filter(:is_orig, :xboolean, header: 'Orig?')
  filter(:weight, range: true, if: Proc.new{current_user && current_user.qualified_as?(TransModerator)})

  filter(:create_user, header: 'Create/Update User ("SELF" for yourself)') do |value|
    cuser = ((defined?(current_user) && current_user) || TranslationsGrid.current_user)  # Former is invalid and so the latter is accepted!
    value = cuser.display_name if cuser && 'SELF' == value.strip.upcase
    self.joins("JOIN users ON users.id = translations.create_user_id OR users.id = translations.update_user_id").where('users.display_name = ?', value.strip)
  end

  # :xboolean does not work expectantly for some reason... (the result would be the same regardless Yes/No (but not-selected))
  filter(:user_defined_exclusively, :boolean,  dummy: false, header: 'User-defined records only?') do |value|
    self.where("create_user_id IS NOT NULL OR update_user_id IS NOT NULL")
  end

  filter(:max_per_page, :enum, select: MAX_PER_PAGES, default: 25, multiple: false, dummy: true, header: I18n.t("datagrid.form.max_per_page", default: "Max entries per page"))

  column_names_filter(header: I18n.t("datagrid.form.extra_columns", default: "Extra Columns"), checkboxes: true)

  ####### Columns #######

  column(:id, header: "ID", if: Proc.new{current_user && current_user.editor?}) do |record|
    to_path = Rails.application.routes.url_helpers.harami1129_url(record, {only_path: true}.merge(ApplicationController.new.default_url_options))
    ActionController::Base.helpers.link_to record.id, to_path
  end

  column(:translatable, mandatory: true) do |record|
    sprintf(
      "%s (%s)",
      record.translatable_type,
      ActionController::Base.helpers.link_to(record.translatable_id, Rails.application.routes.url_helpers.polymorphic_path(record))
    ).html_safe
  end

  column(:title, mandatory: true)
  column(:ruby)
  column(:romaji)
  column(:alt_title, mandatory: true)
  column(:alt_ruby)
  column(:alt_romaji)

  column(:is_orig, mandatory: true, header: "Orig?") do |record|
    record ? 'T' : (record.nil? ? '' : 'F')
  end

  column(:weight, mandatory: true, if: Proc.new{current_user && current_user.qualified_as?(TransModerator)})

  column_display_user(:create_user)
  column_display_user(:update_user)
  #column(:create_user) do |record|
  #  is_me = (current_user && current_user == record)
  #  is_me ? "<strong>SELF</strong>".html_safe : record.display_name
  #end
  #column(:update_user) do |record|
  #  record.display_name
  #end

  column(:note, mandatory: true, header: I18n.t('tables.note'))

  column(:updated_at, header: I18n.t('tables.updated_at'), if: Proc.new{current_user && current_user.editor?})
  column(:created_at, header: I18n.t('tables.created_at'), if: Proc.new{current_user && current_user.editor?})
  column(:actions, html: true, mandatory: true, header: I18n.t("tables.actions", default: "Actions")) do |record|
    #ar = [ActionController::Base.helpers.link_to('Show', record, data: { turbolinks: false })]
    ar = [link_to('Show', translation_path(record), data: { turbolinks: false })]
    if can? :update, record
      ar.push link_to('Edit', edit_translation_path(record))
      if can? :destroy, record
        ar.push link_to('Destroy', translation_path(record), method: :delete, data: { confirm: t('are_you_sure').html_safe })
      end
    end
    ar.compact.join(' / ').html_safe
  end
end

class << TranslationsGrid
  # Setter/getter of {TranslationsGrid.current_user}
  attr_accessor :current_user  # This is used above!
  attr_accessor :is_current_user_moderator
end

