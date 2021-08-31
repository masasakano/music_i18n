# coding: utf-8
class MusicsGrid < BaseGrid

  extend ApplicationHelper
  extend ModuleCommon

  #alias_method :initialize_orig, :initialize if ! self.method_defined?(:initialize_old)
  #def initialize(params = {}, user: nil)
  #  @current_user = user
  #  initialize_orig(params)
  #end

  scope do
    Music
  end

  ### Taken from harami1129s_grid.rb
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

  #if MusicsGrid.is_current_user_moderator  # This does now work because the method is not defined when this line is executed (even if it did, the value would not be set at this stage!).
    filter(:id, :integer)
  #end

  filter_include_ilike(:title_ja, header: 'Title (ja+en) (partial)')
  filter_include_ilike(:title_en, langcode: 'en', header: 'Title (en) (partial)')

  filter(:year, :integer, :range => true) # , default: proc { [User.minimum(:logins_count), User.maximum(:logins_count)] }

  filter(:artists, :string, header: 'Artist (partial)') do |value|  # Only for PostgreSQL!
    str = preprocess_space_zenkaku(value, article_to_tail=true)
    trans_opts = {accept_match_methods: [:include_ilike], translatable_type: 'Artist'}
    arts = Artist.find Translation.find_all_by_a_title(:titles, value, **trans_opts).uniq.map(&:translatable_id)
    # self.joins(:engages).where('engages.artist_id IN (?)', arts.map(&:id)).distinct  # This would break down when combined with order()
    ids = Music.joins(:engages).where('engages.artist_id IN (?)', arts.map(&:id)).distinct.pluck(:id)
    self.where id: ids
  end

  column_names_filter(:header => "Extra Columns", checkboxes: true)

  ####### Columns #######

  #if MusicsGrid.is_current_user_moderator  # This does not work; see above
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

  column(:year, :mandatory => true)

  column(:genre) do |record|
    record.genre.title_or_alt(langcode: I18n.locale)
  end
  column(:place) do |record|
    ar = record.place.title_or_alt_ascendants(langcode: 'ja', prefer_alt: true);
    sprintf '%s %s(%s)', ar[1], ((ar[1] == Prefecture::UnknownPrefecture['ja'] || ar[0].blank?) ? '' : '— '+ar[0]+' '), ar[2]
  end

  # Valid only for PostgreSQL
  # To make it applicable for other DBs, see  https://stackoverflow.com/a/68998474/3577922)
  column(:artists, :mandatory => true, :order => proc { |scope|
    #order_str = Arel.sql("convert_to(title, 'UTF8'), convert_to(alt_title, 'UTF8')")
    #order_str = Arel.sql('title COLLATE "ja_JP", alt_title COLLATE "ja_JP"')
    #order_str = Arel.sql('title COLLATE "C", alt_title COLLATE "C"')
    order_str = Arel.sql('title COLLATE "ja-x-icu", alt_title COLLATE "ja-x-icu"')
#Rails.logger.debug sprintf("DEBUG:SCOPE=: #{scope.inspect}")
    ids = Music.joins(:artists).joins("INNER JOIN translations ON translations.translatable_id = artists.id AND translations.translatable_type = 'Artist'").order(order_str).map(&:id).uniq  # if scope is used instead of Music, it seems to be heavily affected by cache
#Rails.logger.debug sprintf("DEBUG:ids: #{ids.inspect}")
    #scope.joins("INNER JOIN unnest('{#{ids.join(',')}}'::int[]) WITH ORDINALITY t_ord(id, ord) USING (id)").order("t_ord.ord")  # This should work, too, unless there is another JOIN.
    scope.joins("INNER JOIN unnest('{#{ids.join(',')}}'::int[]) WITH ORDINALITY t_ord(id, ord) ON musics.id = t_ord.id").order("t_ord.ord")
  }) do |record|
    #record.engages.joins(:engage_how).order('engage_hows.weight').pluck(:artist_id).uniq.map{|i| art = Artist.find(i); sprintf '%s [%s]', ActionController::Base.helpers.link_to(art.title_or_alt, art), h(art.engage_how_titles(record).join(', '))}.join(', ').html_safe
    record.engages.joins(:engage_how).order('engage_hows.weight').pluck(:artist_id).uniq.map{|i| art = Artist.find(i); sprintf '%s [%s]', ActionController::Base.helpers.link_to(art.title_or_alt, Rails.application.routes.url_helpers.artist_path(art)), ERB::Util.html_escape(art.engage_how_titles(record).join(', '))}.join(', ').html_safe
  end
  column(:n_harami_vids) do |record|
    record.harami_vids.count.to_s+'回'
  end

  column(:note)

  column(:updated_at)
  column(:created_at)
  column(:actions, :html => true, :mandatory => true) do |record|
    #ar = [ActionController::Base.helpers.link_to('Show', record, data: { turbolinks: false })]
    ar = [ActionController::Base.helpers.link_to('Show', Rails.application.routes.url_helpers.music_path(record), data: { turbolinks: false })]
    if can? :update, record
      ar.push ActionController::Base.helpers.link_to('Edit', Rails.application.routes.url_helpers.edit_music_path(record))
      if can? :destroy, record
        #ar.push ActionController::Base.helpers.link_to('Destroy', record, method: :delete, data: { confirm: 'Are you sure?' })
        ar.push ActionController::Base.helpers.link_to('Destroy', Rails.application.routes.url_helpers.music_path(record), method: :delete, data: { confirm: 'Are you sure?' })
        if record == Music.unknown && MusicsGrid.is_current_user_moderator
          ar.push '(Moderator only)'
        end
      end
      ar.compact.join(' / ').html_safe
    end
  end

end

class << MusicsGrid
  # Setter/getter of {MusicsGrid.current_user}
  attr_accessor :current_user
  attr_accessor :is_current_user_moderator
end

