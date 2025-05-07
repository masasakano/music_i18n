module BaseMergesHelper

  # Provides a block for <td> for a column for a record to be merged
  def base_merges_to_merge_column_td
    ret = []
    ret << sprintf('<td title="%s">'+"\n", t('merges.edit.merge_always')).html_safe
    ret << capture{ yield }
    ret << "</td>".html_safe
    ret.join("").html_safe
  end

  # Provides a block for <td> for a merged column
  def base_merges_merged_column_td(to_model)
    to_model_underscore = (to_model.respond_to?(:name) ? to_model.name : to_model).underscore
    td_id = h("merged_to_"+to_model_underscore)
    ret = []
    ret << sprintf('<td class="merged_column" id="%s">'+"\n", td_id).html_safe
    ret << capture{ yield }
    ret << "</td>".html_safe
    ret.join("").html_safe
  end

  # @param record [ActiveRecord] a record to merge
  # @return [String] html_safe
  def base_merges_hvma_to_merge_content(record)
    record.harami_vid_music_assocs.pluck(:id, :harami_vid_id, :timing, :note).sort_by(&:first).map{|id_note|
      (sprintf('%d[%s][t=%s]', id_note[0], link_to(id_note[1], harami_vid_path(id_note[1])), id_note[2].inspect).html_safe +
       ((txt=id_note[3]).present? ? sprintf('(<span title="HaramiVidMusicAssoc(%d)#note">%s</span>)', id_note[0], h(txt)) : "").html_safe)
    }.join(", ").html_safe
  end

  # @param record [ActiveRecord] a record to merge
  # @return [String] html_safe
  def base_merges_anchoring_to_merge_content(record)
    record.anchorings.joins(:url).pluck(:id, :url_id, "urls.url", :note).sort_by(&:first).map{|id_note|
      (sprintf('%d[%s]', id_note[0], link_to(Addressable::URI.unencode(id_note[2]).sub(%r@https?://(www\.)?@, ""), url_path(id_note[1]), title: "Internal link to Url")).html_safe +
       ((txt=id_note[3]).present? ? sprintf('(<span title="Anchoring(%d)#note">%s</span>)', id_note[0], h(txt)) : "").html_safe)
    }.join(", ").html_safe
  end

  # @param merged [ActiveRecord] merged record 
  # @return [String] html_safe
  def base_merges_hvma_merged_content(merged)
    ary = merged.hsmerged[:harami_vid_music_assocs][:remained].map{|em|
      sprintf('%d[t=%s]', em.id.to_s, em.timing.inspect) + h(em.note.present? ? sprintf("(%s)", em.note) : "")
    }.join(", ").html_safe
  end

  # @param merged [ActiveRecord] merged record 
  # @return [String] html_safe
  def base_merges_anchoring_merged_content(merged)
    ary = merged.hsmerged[:anchorings][:remained].map{|em|
      sprintf('%d', em.id.to_s) + h(em.note.present? ? sprintf("(%s)", em.note) : "")
    }.join(", ").html_safe
  end
  
end
