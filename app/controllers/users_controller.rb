class UsersController < ApplicationController

  load_and_authorize_resource

  # Class used to pass the data to the View forms
  class FormOpts
    attr_accessor :role
    attr_writer :disabled, :checked
    def disabled?
      @disabled
    end
    def checked?
      @checked
    end
  end

  def index
    @users = User.all
  end

  # == Note (Algorithm to show the roles)
  #
  # (1) @roles_d is a Double Array categorized according to RoleCategory in the order of the rank (highest first)
  #     This contains only the {Role}-s that the user is {User#qualified_as?} and in the rank order.
  # (2) Loop over the category. At the beginning of each iteration, get its {RoleCategoryNode}.
  #     (1) If the depth_node is higher than the previous one, print <dl><dt>{RoleCategory.mname} for all {RoleCategory} between (inclusively) the current and previous+1.
  #     (2) If the depth_node is lower (or equal) than the previous one, print </dl> for the depth difference times.
  # (3) Print all the roles (plus 'None' to cancel the selection) as a set of Radio buttons.  Judge whether it is checked.
  #
  # == Note (Algorithm to show the roles)
  #
  # @roletree is {RoleCategoryNode} (like Tree) with
  #
  # (1) "name" is machine-name of {RoleCategory}
  # (2) "content" is Hash with keys of
  #    (1) :role_category for {RoleCategory} objcet
  #    (2) :id_name for "method" option to the form used for the HTML id+name attribute
  #    (3) :delete_disabled for Boolean; if true, "delete"(=None) option in the form
  #        to delete the Role in the RoleCategory is disabled (aka, not provided
  #        to the user)
  #    (4) :forms for UsersController::FormOpts object for {Role} and disabled & checked info
  #
  # == Policy
  #
  # * Any registered user can view other people's exact {Role}s.
  # * Any user with a {Role} can demote himself, i.e. he can view the {Role} structure of the {Role}
  #     of himself or lower, including deleting it (aka None).
  # * A non-moderator cannot view the {Role} structures that are irrelevan to either him
  #   or the other_user.  For example, if a harami_editor views a translator's role,
  #   he can see the translator have a {Role} as a Translator but nothing is displayed
  #   about harami_editing roles or any other Translation-related roles.
  # * A moderator (in any {RoleCategory}) can view all the {RoleCategory} and {Role} structure.
  #   * If he is not qualified, that is, he is either not qualified for the {Role} or
  #     not superior to "other_user" in the {RoleCategory},
  #     the corresponding form will be disabled (content[:forms][nnn].disabled? is true).
  #
  def show
    #@user = User.find_by_username(params[:id])
    @user = User.find(params[:id])

    #allroles = Role.all_categorized
    #@roles_d = (current_user.moderator? ? allroles.map{|ea| a = ea.find_all{|er| current_user.qualified_as?(er)}; a.empty? ? nil : a}.compact : []) # ROLES_Double

    @roletree = self.class.get_roletree(current_user, @user)
  end

  # Returns Tree with contents being [{RoleCategory}, ({User::FormOpts}, [{User::FormOpts}, ...])]
  #
  # Note that {RoleCategory.tree} object, which is cached, is destructively modified.
  #
  # @param force_update: [Boolean] if true (Default(!)), cache is disabled.
  #    The default is the opposite of {RoleCategory.tree}; else it could cause more trouble.
  # @return [RoleCategoryNode, NilClass] nil if of_user has no {Roles} (which by_user can view)
  def self.get_roletree(by_user, of_user, force_update: true)
    roletree = RoleCategory.tree_roles force_update: force_update  # RoleCategoryNode
    roletree.each do |etree|
      hs_content = {}
      hs_content[:role_category] = etree.content[0]  # the 1st element: RoleCategory
      hs_content[:id_name] = User::ROLE_FORM_RADIO_PREFIX + etree.name

      disabled_def = !by_user.qualified_as?(hs_content[:role_category]) || !(by_user.moderator? || by_user == of_user)
        # User-NOT-qualifed_as => disable=true; Neither-moderator-nor-himself => disable=true
      is_qualified_with_other_user = (by_user == of_user || by_user.superior_to?(of_user, hs_content[:role_category]))
      hs_content[:delete_disabled] = (disabled_def || !(by_user.qualified_as?(hs_content[:role_category]) && is_qualified_with_other_user))  # "delete"(=None) option to delete the Role in the RoleCategory is disabled (aka, not provided to the user) if true.

      artmp = etree.content[1..-1].map{|er|
        disabled = (disabled_def || !(by_user.qualified_as?(er) && is_qualified_with_other_user))
        checked = of_user.roles.include?(er)
        if !by_user.moderator? && (by_user != of_user) && !checked
          # Anyone who is not qualified as a Moderator cannot see unoccupied Roles of_user, except for those to demote himself.
          nil
        elsif by_user.moderator? || !disabled || checked
          obj = FormOpts.new
          obj.role = er
          obj.disabled = disabled
          obj.checked  = checked
          obj  # UsersController::FormOpts
        else
          nil
        end
      }
      hs_content[:forms] = artmp.compact

      # if !etree.is_leaf? || by_user.moderator? || (!hs_content[:delete_disabled] || (hs_content[:forms][0] && hs_content[:forms][0].checked?))
      if by_user.moderator? || (!hs_content[:delete_disabled] || (hs_content[:forms][0] && hs_content[:forms][0].checked?))
        etree.content = hs_content
      else
        etree.content = nil  # This node will be "compact!"-ed, i.e., removed (unless it is ROOT or it has, though unlikely, a significant child Node, aka RoleCategory with a Role meaningful for by_user).
      end
    end

    roletree.compact! # defined in RoleCategoryNode in /lib/role_category_node.rb

    (roletree.is_leaf? && !roletree.content) ? nil : roletree
  end
end

