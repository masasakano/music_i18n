class Translations::PromotesController < ApplicationController

  before_action :set_translation, only: [:update]

  # True if promote is allowed.
  #
  # Essentially, this Controller (but this class method) is only accessible 
  # by translation-moderators and admins.  They are allowed to promote
  # almost any Translations, created by whomever, unless the {#weight} is
  # already zero.
  #
  # Note that if the Translation with the highest weight score among sibling Translations
  # is created by a senior person (admin), the promoted weight would not exceed it.
  # Mind you, most of admin-created translations should have a weight of either
  # 0 (i.e., {#is_orig}==true or definitive translation) or Infinity
  # and nothing in between, although admin's default Translation weight is 1.
  def self.allowed?(tra)
    # return false if !can?(:update, Translations::PromotesController)  # This check should be done in UI (View). Besides, it is a bit awkward to use "can?" here.
    return false if tra.weight  && tra.weight <= 0
    return true  if tra.is_orig && (!tra.weight || tra.weight > 0)

    # If the sibling of the same langcode has is_orig==true
    # and if this translation has the second highest weight,
    # there is no point to promote it.
    best_tra, best_weight = tra.best_translation_with_weight
    return false if [best_weight, Float::INFINITY].include?(tra.weight)
    return false if 1 == tra.siblings.count
    return false if best_tra.is_orig && tra == tra.siblings[1]

    return true
  end

  def update
    authorize! :update, Translations::PromotesController

    if !self.class.allowed?(@translation)
      # The UI should be designed not to reach this point.
      raise CanCanCan::AccessDenied.new("Not authorized to promote Translation=#{@translation.title_or_alt.inspect}", :update, Translations::PromotesController)
    end

    best_tra, best_weight = @translation.best_translation_with_weight
    new_weight = (@translation.is_orig ? 0 : @translation.def_weight(current_user))

    opts = {}
    if @translation.weight && new_weight >= @translation.weight
      msg = "The weight (=#{@translation.weight}) of the Translation is already as best (low) as it can be."
      opts[:warning] = msg
    end

    if opts.empty? && @translation.update(weight: new_weight)
      msg1 = "Successfully promoted the Translation (title_or_alt=#{@translation.title_or_alt.inspect}) with a new weight of #{new_weight}."
      opts[:success] = msg1
      msg2 = nil
      if best_weight < new_weight
        msg2 = "Note this is not the best weight among siblings; the best weight for lang=#{@translation.langcode} is #{best_weight} (title_or_alt=#{best_tra.title_or_alt.inspect})."
        opts[:warning] = msg2  # success and warning messages will be displayed
      end
      respond_to do |format|
        format.html { redirect_to (request.referrer || @translation), **opts }
        format.json { render json: [msg1, msg2].compact, status: :ok, location: (request.referrer || @translation) }
      end
    else
      # This should not happen in general (unless DB behaves funny.)
      opts[:alert] = @translation.errors.full_messages if !@translation.errors.empty?
      msg = (opts[:alert] || opts[:warning])
      respond_to do |format|
        format.html { redirect_to (request.referrer || @translation), **opts }
        format.json { render json: [msg], status: :unprocessable_entity }
      end
    end
  end

  private
    # Use callback for setup for new
    def set_translation
      @translation = Translation.find(params[:id])
    end

end
