# -*- coding: utf-8 -*-

# Common module for the main routine of index in Controllers for auto-complete
#
# @example
#   include AutoCompleteIndex
#   def index
#     permitted = get_id
#     id_cur = (permitted.respond_to?(:divmod) ? permitted : nil)
#     index_auto_complete(!!permitted, self.class::MODEL_SYM, klass_id: id_cur, do_display_id: true)
#   end
#
module AutoCompleteIndex
  #def self.included(base)
  #  base.extend(ClassMethods)
  #end
  extend ActiveSupport::Concern  # In Rails, the 3 lines above can be replaced with this.

  #module ClassMethods
  #end # module ClassMethods

  # See the commentat for the Module at the top for detail
  #
  # @param permitted [Boolean] 
  # @param klass [ApplicationRecord, Symbol] If symbol, it is singular
  # @param klass_id: [Integer, NilClass] pID of klass, if any. If specified, the record is excluded from the returned candidates.
  # @param do_display_id: [Boolean] If true, " (en) [ID=123]" is appended (displayed) in each of the element in the returned Array
  # @param kwd: [String] Keyword to auto-complete
  # @param path: [String] Used for the errorneous return message.
  # @return [void]
  def index_auto_complete(permitted, klass, klass_id: nil, do_display_id: false, kwd: params[:keyword], path: params[:path])
    if !permitted
      return respond_to do |format|
        format.html { }
        format.json { render json: {error: "Forbidden request #{path.inspect}" }, status: :unprocessable_entity }
      end
    end

    klass = (klass.respond_to?(:where) ? klas : self.class::MODEL_SYM.to_s.classify.constantize)
    model = (klass_id ? klass.find(klass_id) : klass.new)
    candidates = model.select_titles_partial_str_except_self(:titles, kwd, display_id: do_display_id)

    respond_to do |format|
      format.html { }
      format.json { render json: candidates[0..self.class::MAX_SUGGESTIONS], status: :ok }
    end
  end
end

