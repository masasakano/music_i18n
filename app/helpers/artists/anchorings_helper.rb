module Artists::AnchoringsHelper
  include ModuleCommon  # for get_language_name

  def path_anchoring(anchoring, parent: nil, action: :show, for_url: false)
    suffix = (for_url ? "url" : "path")
    parent ||= anchoring.anchorable   # the latter assumes anchorable is significant.
      
    prm_parent_lower = parent.class.name.underscore
    path_base = prm_parent_lower + "_anchoring_"+suffix

    command =
      case action.to_sym
      when :index, :create
        path_base.sub(/(.*)(_#{suffix})/){ $1.pluralize+$2 }
      when :show, :update, :destroy
        path_base 
      when :new, :edit
        action.to_s + "_" + path_base 
      else
        raise
      end

    opts = {(prm_parent_lower+"_id").to_sym => parent.id}
    opts[:id] = anchoring.id if !anchoring.new_record?
    send(command, **opts)
  end

  def url_anchoring(anchoring, for_url: true, **kwd)
    path_anchoring(anchoring, for_url: for_url, **kwd)
  end
end
