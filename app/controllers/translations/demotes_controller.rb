class Translations::DemotesController < ApplicationController

  before_action :set_translation, only: [:update]

  # True if demote is allowed.
  #
  # Essentially, this Controller (but this class method) is only accessible 
  # by translation-moderators and admins.  They are allowed to demote
  # almost any Translations, created by whomever, unless the {#weight} is
  # already zero.
  #
  # Note that if the Translation with the highest weight score among sibling Translations
  # is created by a senior person (admin), the demoted weight would not exceed it.
  # Mind you, most of admin-created translations should have a weight of either
  # 0 (i.e., {#is_orig}==true or definitive translation) or Infinity
  # and nothing in between, although admin's default Translation weight is 1.
  #
  # @param tra [Translation]
  # @param user [User]
  def self.allowed?(tra, user=Translation.whodunnit)
    # return false if !can?(:update, Translations::DemotesController)  # This check should be done in UI (View). Besides, it is a bit awkward to use "can?" here.
    return false if tra.weight && tra.weight == Float::INFINITY
    return false if tra.is_orig  # Original one cannot be demoted. Moderator may modify is_orig
    return false if tra.siblings.last == tra

    role = user.highest_role_in(RoleCategory[RoleCategory::MNAME_TRANSLATION])
    return false if !tra.create_user
    return true  if  tra.create_user == user
    other_user = tra.create_user
    return false if !other_user  # If create_user is undefined weight should be either 0 or Float::INFINITY anyway
    other_role = other_user.highest_role_in(RoleCategory[RoleCategory::MNAME_TRANSLATION])
    return false if !role.superior_to?(other_role)  # If you're at the same rank, you cannot demote it.
    return true
  end

  def update
    authorize! :update, Translations::DemotesController

    if !self.class.allowed?(@translation, current_user)
      # The UI should be designed not to reach this point.
      raise CanCanCan::AccessDenied.new("Not authorized to demote Translation=#{@translation.title_or_alt.inspect}", :update, Translations::DemotesController)
    end

    new_weight, hsbest = @translation.weight_after_next
    opts = {}

    if new_weight && @translation.update(weight: new_weight)
      is_qualified = current_user.qualified_as?('moderator', RoleCategory[RoleCategory::MNAME_TRANSLATION])
      msgweight = (is_qualified ? " with a new weight of #{new_weight}." : "")
      msg1 = "Successfully demoted the Translation (title_or_alt=#{@translation.title_or_alt.inspect})"+msgweight
      msgweight = (is_qualified ? sprintf(" (ID=%d, weight=%s).", hsbest[:id], hsbest[:weight]) : ".")
      msg2 = "The highest-priority [#{@translation.langcode}] Translation is now #{hsbest[:title].inspect}"+msgweight
      opts[:success] = [msg1, msg2].join(" ")

      respond_to do |format|
        format.html { redirect_to (request.referrer || @translation), **opts }
        format.json { render json: [opts[:success]], status: :ok, location: (request.referrer || @translation) }
      end
    else
      if new_weight
        # This should not happen in general (unless DB behaves funny.)
        opts[:alert] = @translation.errors.full_messages if !@translation.errors.empty?
      else
        # The weight of the next one is Float::INFINITY (or possibly nil, though nil is banned; see callback set_create_user)
        opts[:alert] = "The next one has the worst weight (quality) and hence you cannot demote this Translation."
      end
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
