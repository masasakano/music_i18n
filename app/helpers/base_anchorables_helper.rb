module BaseAnchorablesHelper
  include ModuleCommon  # for get_language_name

  # @param anchoring [Anchoring, NilClass] mandatory except for actions of :index or :create or :new
  # @param parent [BaseWithTranslation, NilClass] mandatory for actions of :index or :create or :new, else optional.
  def path_anchoring(anchoring=nil, parent: nil, action: :show, for_url: false)
    suffix = (for_url ? "url" : "path")
    parent ||= anchoring.anchorable   # the latter assumes anchorable is significant.
      
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

    sprintf("(%s)", [sctit, tdtit].compact.join(": "))
  end
end
