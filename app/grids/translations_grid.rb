# coding: utf-8
class TranslationsGrid < ApplicationGrid

  TransModerator = Role['moderator', 'translation']
  Translator     = Role['editor',    'translation']

  scope do
    Translation.all
  end

  ####### Filters #######

  filter_n_column_id(:translation_url)  # defined in application_grid.rb

  filter(:title, header: 'Title/Ruby keyword (partial match)', input_options: {"data-1p-ignore" => true}) do |value|
    self.select_partial_str(:all, value, ignore_case: true)  # Only for PostgreSQL!
  end

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
  filter(:user_defined_exclusively, :boolean,  dummy: false, header: 'User-defined records only?', input_options: {"data-1p-ignore" => true}) do |value|
    self.where("create_user_id IS NOT NULL OR update_user_id IS NOT NULL")
  end

  column_names_max_per_page_filters  # defined in base_grid.rb

  ####### Columns #######

  column(:translatable, mandatory: true) do |record|
    sprintf(
      "%s (%s)",
      record.translatable_type,
      ActionController::Base.helpers.link_to(record.translatable_id, Rails.application.routes.url_helpers.polymorphic_path(record))
    ).html_safe
  end

  column(:langcode, mandatory: true, header: "lc", tag_options: {class: ["text-center"]})
  column(:title, mandatory: true)
  column(:ruby)
  column(:romaji)
  column(:alt_title, mandatory: true)
  column(:alt_ruby)
  column(:alt_romaji)

  column(:is_orig, mandatory: true, header: "Orig?") do |record|
    record ? 'T' : (record.nil? ? '' : 'F')
  end

  column(:weight, mandatory: true, tag_options: {class: ["editor_only"]}, if: Proc.new{ApplicationGrid.qualified_as?(TransModerator)})

  column_display_user(:update_user, tag_options: {class: ["editor_only"]})  # defined in application_grid.rb
  column_display_user(:create_user, tag_options: {class: ["editor_only"]})  # defined in application_grid.rb

  column_note             # defined in application_grid.rb
  columns_upd_created_at  # defined in application_grid.rb

  column_actions(with_destroy: true) #do |record| # defined in application_grid.rb
end

