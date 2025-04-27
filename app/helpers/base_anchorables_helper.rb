module BaseAnchorablesHelper
  include ModuleCommon  # for get_language_name

  # Path helper for Anchoring
  #
  # @param anchoring [Anchoring, BaseWithTranslation, NilClass] Either Anchoring or its anchorable record. For actions of :index or :create or :new, you can leave this blank and instead specify +parent+ (obsolete)
  # @param for_url [Boolean] if true, URL instead of Path is returned
  def path_anchoring(anchoring=nil, action: :show, for_url: false)
    is_anchorable = anchoring.respond_to?(:anchorable) 
    if !is_anchorable && !anchoring.respond_to?(:anchorings)
      raise ArgumentError, "(#{File.basename __FILE__}:#{__method__}): First argument must be either an Anchoring record or its anchorable target record, but it is not (maybe a class is given?): #{anchoring.inspect}"
    end

    suffix = (for_url ? "url" : "path")
    parent = (anchoring.respond_to?(:anchorable) ? anchoring.anchorable : anchoring)  # the latter assumes anchorable is significant.
      
    prm_parent_lower = parent.class.name.underscore
    path_base = prm_parent_lower + "_anchoring_"+suffix

    is_index_or_create = [:index, :new, :create].include?(action.to_sym)

    command =
      case action.to_sym
      when :index, :create
        is_index_or_create = true
        path_base.sub(/(.*)(_#{suffix})/){ $1.pluralize+$2 }
      when :show, :update, :destroy
        path_base 
      when :new, :edit
        action.to_s + "_" + path_base 
      else
        raise
      end

    opts = {(prm_parent_lower+"_id").to_sym => parent.id}
    opts[:id] = anchoring.id if !is_index_or_create
    send(command, **opts)
  end

  def url_anchoring(anchoring, for_url: true, **kwd)
    path_anchoring(anchoring, for_url: for_url, **kwd)
  end

  # @return [Symbol] like :artist_id
  def path_id_symbol(record)
    ((record.respond_to?(:anchorable) ? record.anchorable.class : record.class).name.underscore + "_id").to_sym
  end

  #
  # @param record [Anchoring]
  # @return [String] The title header for each link in the embedded Anchoring-Show
  def link_show_header(record)
    anchorable = record.anchorable
    sctit = record.site_category.title_or_alt(    langcode: I18n.locale, prefer_shorter: true, lang_fallback_option: :either, str_fallback: "")
    tdtit = (dt=record.domain_title).title_or_alt(langcode: I18n.locale, prefer_shorter: true, lang_fallback_option: :either, str_fallback: (can?(:edit, Artist) ? "(UNDEFINED)" : nil))
    tdtit = nil if dt.domains.pluck(:domain).map{|es| es.sub(/^www\./, "")}.uniq.include?(tdtit)  # If the title is just a URL, it is not displayed.
    tdtit &&= nil if sctit.downcase.strip.gsub(/[[:space:]]+/, "") == tdtit.downcase.strip.gsub(/[[:space:]]+/, "")

    sprintf("(%s)", [sctit, tdtit].compact.join(": "))
  end
end
