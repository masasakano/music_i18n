# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    # Define abilities for the passed in user here. For example:
    #
    #   user ||= User.new # guest user (not logged in)
    #   if user.admin?
    #     can :manage, :all
    #   else
    #     can :read, :all
    #   end
    #
    # The first argument to `can` is the action you are giving the user
    # permission to do.
    # If you pass :manage it will apply to every action. Other common actions
    # here are :read, :create, :update and :destroy.
    #
    # The second argument is the resource the user can perform the action on.
    # If you pass :all it will apply to every resource. Otherwise pass a Ruby
    # class of the resource.
    #
    # The third argument is an optional hash of conditions to further filter the
    # objects.
    # For example, here the user can only update published articles.
    #
    #   can :update, Article, :published => true
    #
    # See the wiki for details:
    # https://github.com/CanCanCommunity/cancancan/blob/develop/docs/Defining-Abilities.md

    alias_action :create, :read, :update, :destroy, to: :crud # including :edit
    alias_action :create, :read, :update,           to: :cru  # including :edit
    alias_action :create, :read,                    to: :cr
    alias_action :update, :destroy,                 to: :ud   # including :edit

    # user ||= User.new # Providing an unlogged-in user is created with User.new
    return if !user   # to prohibit everything needing authorization (but :read) from not-logged in users.

    can :manage, :session
    can :read, [HaramiVid, Music, Artist]
    #can :read, :all   # permissions for every user, even if not logged in
    #can :read, [Artist, Music, Country, Prefecture, Place, Genre]
    cannot :read, Harami1129
    cannot :manage, Harami1129

    return if !user.present?  # additional permissions for logged in users (they can manage their posts)

    if user.sysadmin?  # sysadmin is almighty.
      can :manage, :all
      ## The following is redundant.
      #can :access, :rails_admin       # only allow admin users to access Rails Admin
      #can :manage, :dashboard         # allow access to dashboard
      ## including User, Role, RoleCategory
      return
    end

    can :show,   User  # can view any user's profile.
    can :update, User, id: user.id

    ## Middle-rank role.
    if user.editor?  # Harami manager OR HIGHER (but sysadmin)
      can :destroy, Users::DeactivateUser, id: user.id
      can :update, UserRoleAssoc, user: user
      can :manage, Place
      can :crud, [Artist, Music, Engage]
      can :create, Musics::UploadMusicCsvsController
      can :cru,  [Prefecture]
      can :read, [Country, EngageHow, Genre]
      can :show,  Translation
      can [:new, :create], Translation # only for 'ja' and if they can edit translatable; judged in other places
      can :ud,     Translation, create_user_id: user.id #, update_user_id: user.id
      can :ud,     Translation, is_orig: true # can update/delete the original_language one.
      can :ud,     Translation, langcode: 'ja' # can update/delete if JA
      cannot(:ud,  Translation){|trans| !trans.translatable || Ability.new(user).cannot?(:update, trans.translatable)}  # "can?" statement works?
      #cannot(:ud,  Translation){|trans| !trans.translatable || %w(Sex Country).include?(trans.translatable_type)}  # I think "can?" statement does not work.
      #cannot(:ud,  Translation){|trans| true}
#    cannot :show, Users::DeactivateUser, id: user.id
#canedit, Users::DeactivateUser, id: user.id
    end

    ## General-JA editor only
    rc_general_ja = RoleCategory[RoleCategory::MNAME_GENERAL_JA]
    if user.qualified_as?(:editor, rc_general_ja)
    end

    ## HaramiVid editor
    rc_harami = RoleCategory[RoleCategory::MNAME_HARAMI]
    if user.qualified_as?(:editor, rc_harami)
      can :read,  Harami1129
      can :cru,   HaramiVid
    end

    ## Translation editor only
    rc_trans = RoleCategory[RoleCategory::MNAME_TRANSLATION]
    if user.qualified_as?(:editor, rc_trans)
      can [:read, :create], Translation
      cannot(:create, Translation){|trans| !trans.translatable_type || !trans.translatable_type.constantize || Ability.new(user).cannot?(:create, trans.translatable_type.constantize) }
      can(:new, Translation){|trans| !trans.translatable_type || !trans.translatable_type.constantize || Ability.new(user).can?(:create, trans.translatable_type.constantize) }
      #cannot(:ud,  Translation){|trans| !trans.translatable || Ability.new(user).cannot?(:update, trans.translatable)}  # I think "can?" statement does not work.
    end

    ## Higher rank
    if user.moderator?  # Harami manager OR HIGHER (but sysadmin)
      can :read,   Sex
      can :manage, Prefecture          # can :destroy in addition to Editors
      can :manage, [Genre, EngageHow]  # can :update :destroy in addition to Editors
      can [:read, :update], User
      can :update, Users::EditRolesController
      can :update, Users::Confirm  # Moderators can "confirm" users.
      #can(:edit,   Users::DeactivateUser){ |i| user.abs_superior_to?(i) }  # => NoMethodError: undefined method `roles' for #<Users::DeactivateUser
      can(:edit,   Users::DeactivateUser){ |i| user.abs_superior_to?(User.find_by(email: i.email)) } # moderator cannot even access the page for an editor unless absolutely superior
      can :update, UserRoleAssoc
      cannot(:update, UserRoleAssoc){|i| hrc = RoleCategory.root_category;
        uhrc = user.highest_role_in(hrc);
#           print "DEBUG:abi01: ";p(i)
#           print "DEBUG:abi03: ";p(i.user.an_admin? && (!uhrc || uhrc && i.user.highest_role_in(hrc) < uhrc))
        i.user.an_admin? && (uhrc = user.highest_role_in(hrc); !uhrc || uhrc && i.user.highest_role_in(hrc) < uhrc)}
    end

    ## General-JA moderator only
    if user.qualified_as?(:moderator,rc_general_ja)
      can :read, CountryMaster
    end

    ## HaramiVid moderator only
    if user.qualified_as?(:moderator, rc_harami)
      can :crud, [HaramiVid, Harami1129]
    end

    ## Translation moderator only
    if user.qualified_as?(:moderator, rc_trans)
      can :crud,   Translation  # except when they cannot update translatable
    end

    ## Highest rank (but sysadmin)
    if user.qualified_as? RoleCategory[RoleCategory::MNAME_ROOT]
      can :manage, StaticPage
      can :manage, CountryMaster
    end
  end
end
