# coding: utf-8
class TranslationsGrid < ApplicationGrid

  TransModerator = Role['moderator', 'translation']
  Translator     = Role['editor',    'translation']

  scope do
    Translation.all
  end

  ####### Filters #######

  filter(:title, header: 'Title/Ruby keyword (partial match)') do |value|
    self.select_partial_str(:all, value, ignore_case: true)  # Only for PostgreSQL!
  end

  filter(:id, :integer, header: "ID", if: Proc.new{ApplicationGrid.qualified_as?(:editor)})  # displayed only for editors

  filter(:translatable_type, :enum, header: "Class", checkboxes: true, select: Proc.new{ Translation.all.pluck(:translatable_type).uniq.compact.sort.map{|c| [c, c]} })
  filter(:langcode, :enum, header: "Locale", checkboxes: true, select: Proc.new{Translation.all.pluck(:langcode).uniq.compact.sort{|a, b|
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
      else
        i
      end
    }
    ar[0] <=> ar[1]
  }.map{|c| [c, c]} }) # ja, en, cn, fr, it, kr, ...
  filter(:is_orig, :xboolean, header: 'Orig?')
  filter(:weight, :float, range: true, if: Proc.new{ApplicationGrid.qualified_as?(TransModerator)})

  filter(:create_user, header: 'Create/Update User ("SELF" for yourself)') do |value|
    #cuser = ((defined?(CURRENT_USER) && CURRENT_USER) || TranslationsGrid.CURRENT_USER)  # Former is invalid and so the latter is accepted!
    cuser = ApplicationGrid::CURRENT_USER
    value = cuser.display_name if cuser && 'SELF' == value.strip.upcase
    self.joins("JOIN users ON users.id = translations.create_user_id OR users.id = translations.update_user_id").where('users.display_name = ?', value.strip)
  end

  # :xboolean does not work expectantly for some reason... (the result would be the same regardless Yes/No (but not-selected))
  filter(:user_defined_exclusively, :boolean,  dummy: false, header: 'User-defined records only?') do |value|
    self.where("create_user_id IS NOT NULL OR update_user_id IS NOT NULL")
  end

  column_names_max_per_page_filters  # defined in base_grid.rb

  ####### Columns #######

  column(:id, class: ["align-cr", "editor_only"], header: "ID", if: Proc.new{ApplicationGrid.qualified_as?(:editor)}) do |record|
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

  column(:langcode, mandatory: true, header: "lc", class: ["text-center"])
  column(:title, mandatory: true)
  column(:ruby)
  column(:romaji)
  column(:alt_title, mandatory: true)
  column(:alt_ruby)
  column(:alt_romaji)

  column(:is_orig, mandatory: true, header: "Orig?") do |record|
    record ? 'T' : (record.nil? ? '' : 'F')
  end

  column(:weight, mandatory: true, class: ["editor_only"], if: Proc.new{ApplicationGrid.qualified_as?(TransModerator)})

  column_display_user(:create_user, class: ["editor_only"])
  column_display_user(:update_user, class: ["editor_only"])
  #column(:create_user) do |record|
  #  is_me = (CURRENT_USER && CURRENT_USER == record)
  #  is_me ? "<strong>SELF</strong>".html_safe : record.display_name
  #end
  #column(:update_user) do |record|
  #  record.display_name
  #end

  column(:note, html: true, order: false, header: Proc.new{I18n.t("tables.note", default: "Note")}){ |record|
    auto_link50(record.note)
  }

  column(:updated_at, class: ["editor_only"], header: Proc.new{I18n.t('tables.updated_at')}, if: Proc.new{ApplicationGrid.qualified_as?(:editor)})
  column(:created_at, class: ["editor_only"], header: Proc.new{I18n.t('tables.created_at')}, if: Proc.new{ApplicationGrid.qualified_as?(:editor)})
  column(:actions, class: "actions", html: true, mandatory: true, header: I18n.t("tables.actions", default: "Actions")) do |record|
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

