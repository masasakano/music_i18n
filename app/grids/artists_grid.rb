# coding: utf-8
class ArtistsGrid < BaseGrid

  extend ApplicationHelper
  extend ModuleCommon

  scope do
    Artist
  end

  def self.filter_include_ilike(col, type=:string, langcode: nil, **kwd)
    filter(col, type, **kwd) do |value|  # Only for PostgreSQL!
      str = preprocess_space_zenkaku(value, article_to_tail=true)
      trans_opts = {accept_match_methods: [:include_ilike]}
      trans_opts[:langcode] = langcode if langcode
      ids = self.find_all_by_a_title(:titles, str, uniq: true, **trans_opts).map(&:id)
      self.where id: ids
    end
  end

  ####### Filters #######

  #if ArtistsGrid.is_current_user_moderator  # This does now work because the method is not defined when this line is executed (even if it did, the value would not be set at this stage!).
    filter(:id, :integer)
  #end

  filter_include_ilike(:title_ja, header: 'Title (ja+en) (partial)')
  filter_include_ilike(:title_en, langcode: 'en', header: 'Title (en) (partial)')

  filter(:year, :integer, :range => true) # , default: proc { [User.minimum(:logins_count), User.maximum(:logins_count)] }

  sex_titles = Sex::ISO5218S.map{|i| word = Sex[i].title(langcode: I18n.locale)}
  filter(:sex, :enum, checkboxes: true, select: sex_titles) # , default: sex_titles) # allow_blank: false (Default; so if nothing is checked, this filter is ignored)
  # <https://github.com/bogdan/datagrid/wiki/Filters>
  #  (In Dynamic select option)
  #  IMPORTANT: Always wrap dynamic :select option with proc, so that datagrid fetch it from database each time when it renders the form.
  # NOTE: However, in this case, the contetns of Sex should not change, so it is not wrapped with Proc.

  column_names_filter(:header => "Extra Columns", checkboxes: true)

  ####### Columns #######

  #if ArtistsGrid.is_current_user_moderator  # This does not work; see above
    column(:id)
  #end

  column(:title_ja, :mandatory => true, :order => proc { |scope|
    #order_str = Arel.sql("convert_to(title, 'UTF8')")
    order_str = Arel.sql('title COLLATE "ja-x-icu"')
    scope.joins(:translations).where("langcode = 'ja'").order(order_str) #.order("title")
  }) do |record|
    record.title langcode: 'ja'
  end
  column(:ruby_romaji_ja, :order => proc { |scope|
    order_str = Arel.sql('ruby COLLATE "ja-x-icu", romaji COLLATE "ja-x-icu"')
    scope.joins(:translations).where("langcode = 'ja'").order(order_str) #order("ruby").order("romaji")
  }) do |record|
    s = sprintf '[%s/%s]', *(%i(ruby romaji).map{|i| record.send(i, langcode: 'ja') || ''})
    s.sub(%r@/\]\z@, ']').sub(/\A\[\]\z/, '')  # If NULL, nothing is displayed.
  end
  column(:alt_title_ja, :mandatory => true, :order => proc { |scope|
    order_str = Arel.sql('alt_title COLLATE "ja-x-icu"')
    scope.joins(:translations).where("langcode = 'ja'").order(order_str)
  }) do |record|
    s = sprintf '%s [%s/%s]', *(%i(alt_title alt_ruby alt_romaji).map{|i| record.send(i, langcode: 'ja') || ''})
    s.sub(%r@ +\[/\]\z@, '')  # If NULL, nothing is displayed.
  end
  column(:title_en, :mandatory => true, :order => proc { |scope|
    scope.joins(:translations).where("langcode = 'en'").order("title")
  }) do |record|
    s = sprintf '%s [%s]', *(%i(title alt_title).map{|i| record.send(i, langcode: 'en') || ''})
    s.sub(%r@ +\[\]\z@, '')   # If NULL, nothing is displayed.
  end

  column(:sex, :mandatory => true) do |record|
    record.sex.title(langcode: I18n.locale)
  end

  column(:year, :mandatory => false) do |record|
    sprintf '%s???%s???%s???', *(%i(birth_year birth_month birth_day).map{|m|
                                i = record.send m
                                (i.blank? ? '??????' : i.to_s)
                              })
  end

  column(:place) do |record|
    ar = record.place.title_or_alt_ascendants(langcode: I18n.locale, prefer_alt: true);
    sprintf '%s %s(%s)', ar[1], ((ar[1] == Prefecture::UnknownPrefecture[I18n.locale] || ar[0].blank?) ? '' : '??? '+ar[0]+' '), ar[2]
  end

  %w(ja en).each do |elc|
    column('wiki_'+elc, :mandatory => false) do |record|
      uri = record.wiki_uri(elc)
      uri.blank? ? '??????' : ActionController::Base.helpers.link_to(((elc == 'ja') ? '?????????' : '??????'), uri).html_safe
    end
  end

  column(:n_musics) do |record|
    record.musics.uniq.count
  end

  column(:n_harami_vids) do |record|
    record.harami_vids.uniq.count.to_s+'???'
  end

  column(:note)

  column(:updated_at)
  column(:created_at)
  column(:actions, :html => true, :mandatory => true) do |record|
    #ar = [ActionController::Base.helpers.link_to('Show', record, data: { turbolinks: false })]
    ar = [ActionController::Base.helpers.link_to('Show', Rails.application.routes.url_helpers.artist_path(record), data: { turbolinks: false })]
    if can? :update, record
      ar.push ActionController::Base.helpers.link_to('Edit', Rails.application.routes.url_helpers.edit_artist_path(record))
      if can? :destroy, record
        #ar.push ActionController::Base.helpers.link_to('Destroy', record, method: :delete, data: { confirm: 'Are you sure?' })
        ar.push ActionController::Base.helpers.link_to('Destroy', Rails.application.routes.url_helpers.artist_path(record), method: :delete, data: { confirm: 'Are you sure?' })
        if record == Artist.unknown && ArtistsGrid.is_current_user_moderator
          ar.push '(Moderator only)'
        end
      end
      ar.compact.join(' / ').html_safe
    end
  end

end

class << ArtistsGrid
  # Setter/getter of {ArtistsGrid.current_user}
  attr_accessor :current_user
  attr_accessor :is_current_user_moderator
end

