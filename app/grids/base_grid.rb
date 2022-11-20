# coding: utf-8
class BaseGrid

  include Datagrid

  # User-added! To make path-helpers available across Datagrid classes
  # However, in some context, you still have to write like (for some reason):
  #   Rails.application.routes.url_helpers.places_path
  # It seems this is irrelevant after all...
  #include Rails.application.routes.url_helpers

  extend ApplicationHelper  # I suppose this is a key (to include path/url helpers and url_for helpers)?
  extend ModuleCommon  # My module

  # Datagrid enum for the max entries per page for pegination
  MAX_PER_PAGES = {
    10 => 10,
    25 => 25,
    50 => 50,
    100 => 100,
    400 => 400,
    "ALL" => -1,  # -1 is passed to params
  }

  # Absolute maximum limit for pagination.
  HARD_MAX_PER_PAGE = 10000

  # Kaminari default.  I do not know how to get it and so I define it here.
  # @see https://github.com/kaminari/kaminari
  DEF_MAX_PER_PAGE = 25

  # Get the max value
  #
  # @note Only a loose check with the allowed values of {MAX_PER_PAGES} is in place.
  #    After all, "ALL" is allowed at the moment, and so more strict checks
  #    are unnecessary.
  #
  # @param nmax [String, NilClass] usually +grid_params[:max_per_page]+ (to permit), where +grid_params+ should be defined in the caller (controller).
  #   nil is allowed — it would be the case when the page is first loaded.
  # @return [Integer] max entries to show per page.
  def self.get_max_per_page(nmax)
    nmax = ((("all" == nmax.downcase) ? HARD_MAX_PER_PAGE : nmax.to_i) rescue DEF_MAX_PER_PAGE)  # if nmax is nil, rescue is called.
    nmax = DEF_MAX_PER_PAGE  if nmax > MAX_PER_PAGES.values.max  # An artificially large value is not allowed for the security reason.
    nmax = DEF_MAX_PER_PAGE  if nmax < 1  # if smaller than 1 (maybe 0 because of String?), something goes wrong.
    nmax = HARD_MAX_PER_PAGE if nmax < 0 || nmax > HARD_MAX_PER_PAGE
    nmax
  end

  self.default_column_options = {
    # Uncomment to disable the default order
    # order: false,
    # Uncomment to make all columns HTML by default
    # html: true,
  }
  # Enable forbidden attributes protection
  # self.forbidden_attributes_protection = true

  def self.date_column(name, *args)
    column(name, *args) do |model|
      format(block_given? ? yield : model.send(name)) do |date|
        date ? date.strftime("%Y-%m-%d") : ''
      end
    end
  end

  # Used in Harami1129
  def self.filter_split_ilike(col, type=:string, **kwd)
    filter(col, type, **kwd) do |value|  # Only for PostgreSQL!
      arval = value.strip.split(/\s*,\s*/)
      break nil if arval.size == 0
      ret = self.where(col.to_s+" ILIKE ?", '%'+arval[0]+'%')
      if arval.size > 1
        arval[1..-1].each do |es|
          ret = ret.or(self.where(col.to_s+' ILIKE ?', '%'+es+'%'))
        end
      end
      ret
    end
  end

  # Used in Artist, Music etc
  def self.filter_include_ilike(col, type=:string, langcode: nil, **kwd)
    filter(col, type, **kwd) do |value|  # Only for PostgreSQL!
      str = preprocess_space_zenkaku(value, article_to_tail=true)
      trans_opts = {accept_match_methods: [:include_ilike]}
      trans_opts[:langcode] = langcode if langcode
      ids = self.find_all_by_a_title(:titles, str, uniq: true, **trans_opts).map(&:id)
      self.where id: ids
    end
  end

  # Used in HaramiVid
  def self.filter_partial_str(col, type=:string, titles: :titles, **kwd)
    filter(col, type, **kwd) do |value|  # Only for PostgreSQL!
      ids = col.to_s.singularize.classify.constantize.select_partial_str(:titles, value, ignore_case: true).map{|eobj| eobj.harami_vids}.flatten.map(&:id)
      self.where(id: ids)
    end
  end

  # Common filters at the tail: column_names_filter() and filter(:max_per_page)
  # 
  # @param with_i_page [Boolean] If true (Def: false), i_page filter is activated.
  def self.column_names_max_per_page_filters(with_i_page: false)
    column_names_filter(header: Proc.new{I18n.t("datagrid.form.extra_columns", default: "Extra Columns")}, checkboxes: true)
    filter(:max_per_page, :enum, select: Proc.new{
            if current_user && current_user.moderator? || Rails.env.development?  ####### User-condition not working...
              {"1(Dev)" => 1, "4(Dev)" => 4}.merge(MAX_PER_PAGES)
            else
              MAX_PER_PAGES
            end
           }, default: 25, multiple: false, include_blank: false, dummy: true, header: Proc.new{I18n.t("datagrid.form.max_per_page", default: "Max entries per page")})
    filter(:i_page, :integer, dummy: true, default: 1, class: "input_year", header: Proc.new{I18n.t("datagrid.form.i_page", default: "i-th page")}) if with_i_page
       # NOT: Option "class" not working.
  end

  # column displaying either SELF or user-name
  #
  # @example
  #    column_display_user(:create_user, header: Proc.new{I18n.t("datagrid.some_name", default: "Lover's Name")})
  #
  # @param col [Symbol] e.g., :create_user
  def self.column_display_user(col, **kwd)
    column(col, **kwd) do |record|
      user = record.send(col)
      next nil if !user
      (current_user && current_user == user) ? "<strong>SELF</strong>".html_safe : user.display_name
    end
  end

  # Returns a scope so that entries are sorted according to {Translation} of English title&alt_title.
  #
  # Sorted according to title+alt_title or alt_title for those without a title and then {Translation#weight}.
  #
  # In fact, this is still insufficient... For example, suppose an Artist has two Translations of
  # "+Zombies, The+" and "TheZombies" and the former has a better score. Ideally, the name shoulc
  # have a very low priority because it begins with +Z+. However, in this algorithm, "The Zombies"
  # has a higher priority!
  #
  # == Algorithm
  #
  # Basic sorting is done by PostgreSQL.  The record is a joined table of
  # {BaseWithTranslation} and {Translation}, where the number of rows are
  # larger than the original {BaseWithTranslation} because of multiple
  # translations.  For each {BaseWithTranslation}, the best (=lowest) weight
  # translation only should be adopted.
  #
  # This Ruby routine does the process. Basically, "pluck" only {BaseWithTranslation}-ID
  # and {Translation} weight. And this selects the best Translation only.
  # For example, if an Artist has two names of "ZZZ" and "AAA" and if the former has
  # the lower weight than the latter, the Artist must come after any other Artists.
  #
  # @param scope [Relation] 
  # @param klass [Class<ActiveRecord>] like Artist
  # @param langcode [String] like "en"
  def self.scope_with_trans_order(scope, klass, langcode=nil)
    model_plural = klass.name.underscore.pluralize
    sql = "LEFT OUTER JOIN translations ON translations.translatable_type = '#{klass.name}' AND translations.translatable_id = #{model_plural}.id" + (langcode ? " AND translations.langcode = '#{langcode.to_s}'" : "")
    #ids = scope.joins(sql).order(Arel.sql("CONCAT(title, alt_title)")).pluck("#{model_plural}.id", :weight).sort{|a,b| ((cmp=a[0]<=>b[0]) != 0) ? cmp : a[1]<=>b[1]}.map(&:first).uniq  # title or alt_title !
#puts "DEBUG: scope-sql="+scope.joins(sql).order(Arel.sql("CONCAT(title, alt_title)")).to_sql
    ids = scope.joins(sql).order(Arel.sql("CONCAT(title, alt_title)")).pluck("#{model_plural}.id", :weight) #, "translations.id")
#print "DEBUG:ids=";p ids.map{|i| [i, Artist.find(i[0]).title, Translation.find(i[2]).title]}

    hs_weight = {}  # weights[id] = {id: i, weight: w}  # to temporarily record the sorted-positional-index i and weight for BestWithTranslation.
    ids.each_with_index do |eaiw, i|
      id, we = *eaiw
      if !we  # weight is nil
        ids[i][1] = we = Float::INFINITY
      end

      if !hs_weight[id]  # This BestWithTranslation appears for the first time in the title-sorted-Array.
        hs_weight[id] = {i: i, weight: we}
        next
      end

      # Now, either the current one is higher in weight and should disappear or vice versa.
      if hs_weight[id][:weight] <= we
        # Current one should be discarded.
        ids[i] = nil
      else
        # The one that has already appeared should be discarded.
        ids[hs_weight[id][:i]] = nil
      end
    end
    uniqqed_ids = ids.compact.map(&:first)
#print "DEBUG:rev=";p uniqqed_ids+uniqqed_ids.map{|i| Artist.find(i).title}
    
    ids.empty? ? scope : scope.order(Arel.sql("array_position(array#{uniqqed_ids}, id)")) #.order(:id)  # The last one should be redundant b/c LEFT OUTER JOIN was used!
  end

  # Returns the multi-HTML-line text to list (maybe all) Englisht translations of title and alt_title
  #
  # @param record [BaseWithTranslation]
  # @param col [Symbol, String] Column name in {Translation} DB (usually :title or :alt_title)
  # @param langcode [String, Symbol, NilClass] Def: "en". if nil, the same as the entry of is_orig==TRUE
  # @return [String] html_safe-ed
  def self.html_titles(record, col: :title, langcode: "en")
    artit = record.translations_with_lang(langcode.to_s).pluck(col).flatten
    artit.map{|tit| ERB::Util.html_escape(tit)}.join("<br>").html_safe
  end

  # Returns the multi-HTML-line text to list (maybe all) Englisht translations of title and alt_title
  #
  # @param record [BaseWithTranslation]
  # @param langcode [String, Symbol, NilClass] if nil, the same as the entry of is_orig==TRUE
  # @return [String] html_safe-ed
  def self.html_title_alts(record, langcode: "en")
    artit2 = record.translations_with_lang(langcode.to_s).pluck(:title, :alt_title)
    artit2.map{|earow|
      s = sprintf('%s [%s]', *(earow.map{|i| i ? i : ''}))
      s.sub!(%r@ +\[\]\z@, '')   # If NULL, nothing is displayed.
      ERB::Util.html_escape(s)
    }.join("<br>").html_safe
  end
end

#### Does not work: 
## ActionView::Template::Error (no implicit conversion of Regexp into String):
##  Likely here: <%= f.datagrid_label filter %>
#
# # Overwrite separator
# class Datagrid::Filters::BaseFilter
#   def separator
#     options[:multiple].respond_to?('=~') ? options[:multiple] : default_separator
#     # options[:multiple].is_a?(String) ? options[:multiple] : default_separator  # Original
#   end
# end

# @see https://github.com/bogdan/datagrid/wiki/Configuration
Datagrid.configure do |config|

  # Defines date formats that can be used to parse date.
  # Note that multiple formats can be specified but only first format used to format date as string. 
  # Other formats are just used for parsing date from string in case your App uses multiple.
  config.date_formats = ["%Y-%m-%d", "%d/%m/%Y"]

  # Defines timestamp formats that can be used to parse timestamp.
  # Note that multiple formats can be specified but only first format used to format timestamp as string. 
  # Other formats are just used for parsing timestamp from string in case your App uses multiple.
  config.datetime_formats = ["%Y-%m-%d %h:%M:%s", "%d/%m/%Y %h:%M"]
end

