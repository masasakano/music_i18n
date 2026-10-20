class Translations::PromotesController < ApplicationController

  before_action :set_translation, only: [:update]

  # Default weight for the original Translation after promoted is: Role.superuser.weight*0.5
  # NOTE: {Role.superuser} accesses DB, so it is not used to define a constant to avoid unnecessary DB accesses.
  DEF_WEIGHT_FACTOR_PROMOTED_ORIGINAL_REFERENCE = 0.5

  # Default weight increment for the original Translation after promoted is: Role.superuser.weight*0.1 (this must be very rarely used).
  DEF_WEIGHT_FACTOR_PROMOTED_ORIGINAL_POSITIVE_INCREMENT = 0.1

  # True if promote is allowed.
  #
  # +promote+ indicates that the Translation is officially approved by a senior
  # and does not mean much else because a new weight calculation takes into
  # account flag information and the calculated will not exceed the most likely
  # best Translation among the siblings.
  #
  # Essentially, this Controller (but this class method) is only accessible 
  # by translation-moderators and admins.  They are allowed to promote
  # almost any Translations, created by whomever, unless the {#weight} is
  # already zero or smaller than superuser's weight with no other Translation-s
  # of the same langcode having a smaller weight (excepting 0).
  #
  # Note that if the Translation with the highest weight score among sibling Translations
  # is created by a senior person (admin), the promoted weight would not exceed it.
  def self.allowed?(tra)
    # return false if !can?(:update, Translations::PromotesController)  # This check should be done in UI (View). Besides, it is a bit awkward to use "can?" here.
    return true  if tra.weight.nil? || Float::INFINITY == tra.weight
    return false if tra.weight <= 0

    # return true  if tra.is_orig && (!tra.weight || tra.weight > 0)

    best_tra, best_weight = tra.best_translation_with_weight(raw_weight: true, exclude_zero_weight: true)
    return false if !best_weight  # i.e., !best_tra  (b/c the best AND ONLY weight is zero)
    return false if best_weight == tra.weight && tra.weight < Role.superuser.weight  # A sibling with weight=0 may still exist, but you anway cannot promote tra higher than that.

    ## return false if [best_weight, Float::INFINITY].include?(tra.weight)
    # return false if tra.siblings(exclude_self: true).blank?  # should be redundant.
    # return false if best_tra.is_orig && tra == tra.siblings(exclude_self: false)[1]

    return true
  end

  # If promotable, the new weight will be 0.5 (== +Role.superuser.weight/2+), or smaller if another Translation already has it.
  def update
    authorize! :update, Translations::PromotesController

    if !self.class.allowed?(@translation)
      # The UI should be designed not to reach this point.
      raise CanCanCan::AccessDenied.new("Not authorized to promote Translation=#{@translation.title_or_alt.inspect}", :update, Translations::PromotesController)
    end

    best_tra, best_weight = @translation.best_translation_with_weight(raw_weight: true)
    new_weight =
      if @translation.is_orig
        base_weight = [(superuser_weight=Role.superuser.weight), best_weight].min
        @translation.next_unique_weight(
          base_weight * DEF_WEIGHT_FACTOR_PROMOTED_ORIGINAL_REFERENCE,  # == 0.5 (nominal weight of Translation in orig_locale after promoted)
          def_increment: -([base_weight * DEF_WEIGHT_FACTOR_PROMOTED_ORIGINAL_POSITIVE_INCREMENT, superuser_weight.quo(10)].max), # max is required in case of base_weight being 0
          lower_threshold: 0,
          upper_threshold: [base_weight, superuser_weight].max,  # in case of base_weight being 0
          try_reference: true
        )
      else
        @translation.def_weight(current_user)
      end


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
      # This should never happen in general (unless DB behaves funny or some validations went wrong, which should never happen).
      opts[:alert] = @translation.errors.full_messages if !@translation.errors.empty?
      msg = (opts[:alert] || opts[:warning])
      respond_to do |format|
        format.html { redirect_to (request.referrer || @translation), **opts }
        format.json { render json: [msg], status: :unprocessable_content }
      end
    end
  end

  private
    # Use callback for setup for new
    def set_translation
      @translation = Translation.find(params[:id])
    end

end
