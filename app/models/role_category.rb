# coding: utf-8

# require 'role_category_node'  # load class RoleCategoryNode < Tree::TreeNode
## For some reason, this does not work...  It is put instead in /config/application.rb

# = Class RoleCategory to repsent the categories for Role
#
# == Cencept
#
# === Overview of User, Role, and RoleCategory
#
# Rail's authorizations are always boolean, i.e., the {User} is either
# permitted or forbidden to do a certain thing.  The context used to
# authorize a certain thing can consist of multiple layers. In this framework,
# any context is a {RoleCategory} except for the most fine-tuned one and
# direct one, which is a {Role}.
#
# Also, in this model, there is one more tier, that is, logged in or not.
#
# In an analogy of the real life, a {Role} is a job title and a {RoleCategory}
# is an organisation, like a company, faculty, department, etc.
# Suppose a person ({User}) is the manager ({Role}) in department A ({RoleCategory})
# under a company-board ({RoleCategory}). Suppose the manager ({Role}) is permitted
# to authorize any matters within the department. But s/he may be forbidden
# to authorize any matters in department B. However, the same person may work
# as a consultant (another {Role}) in department C ({RoleCategory})
# and may be permitted to authorize some of the matters within the department.
#
# This framework tries to mimic the real world in this sense.
# In short, a {User} ((%has_many%)) multiple {Roles}, each of which ((%belongs_to%))
# a {RoleCategory}, a set of which constitute a tree-like ranking structure.
#
# Aurhorization is made based on a {Role} and a context, that is, {RoleCategory}.
# If a {User} ((%belongs_to%)) one of the {Role}s that ((%belongs_to%)) the
# {RoleCategory} or its direct or indirect {#superior}, the {User} is
# authorized to take the action.
#
# As an example with the above-mentioned real-life one,
# if the {User} has a {Role} of the manager of {RoleCategory} department A or
# has one (or more) higher-ranked {Role}, such as a {Role} board-member
# of the {RoleCategory} company-board, the {User} is authorized to do the thing
# of attention related to {RoleCategory} department A under the {RoleCategory}
# company-board. If not, for example, any of the {User}'s {Role}s with regard to
# {RoleCategory} department A or higher hierachry is lower in rank than
# the departmental manager ({Role}), the {User} is forbiden (not authorized)
# to do it.
#
# ==== Relations
#
# * Each {User} can belong to multiple {Role}s or no {Role} (i.e., ((%has_many%))).
# * Each {Role} can ((%has_many%)) multiple {User}s or no {User}.
# * They are mutually associted ((%through%)) {UserRoleAssoc} (i.e., ((%has_many%)) - ((%through%))).
# * Each {Role} (must) ((%belongs_to%)) a {RoleCategory}, which ((%has_many%)) {Role}s.
# * A {RoleCategory} may not have no {Role}s.
#
# ==== Ranks (weight)
#
# In our framework, in practice, the context of authorization is given as a {Role}
# only (because its {RoleCategory} is singly determined).
#
# * {RoleCategory} has a tree-like structure, and each {RoleCategory} must
#   have its one {#superior} except for the single top-rank one in the entire model.
#   * For example, both {RoleCategory} departments A and B have a single {#superior}
#     {RoleCategory} companny-board.
# * A {RoleCategory} may have multiple {#subordinates}
# * When two {RoleCategory}s are in a {#superior}-{#subordinates} relation
#   whether it is direct or indirect, they are called *related* or in
#   {Role#related_category}. The one that is {#superior}, be it direct or
#   indirect, is classed as being in a higher rank.
#   * For example, the {RoleCategory} companny-board is higher in rank than
#     both {RoleCategory} departments A and B.
# * A {Role} ((%belongs_to%)) a {RoleCategory}.
# * Any {Role} that ((%belongs_to%)) a higher {RoleCategory} than the {Roles}
#   that ((%belongs_to%)) to a *related* but lower {RoleCategory} is higher
#   in rank than the latter.
# * If the {RoleCategory} a {Role} of ((%belongs_to%)) is not *related* to
#   the {RoleCategory} of the given context, a {User} of the {Role} is
#   not authorized.
#   * For example, if a {User}'s only {Role} is the head of the {RoleCategory}
#     department B, the {User} is not authorized to do a thing that requires
#     the {Role} manager in the same {RoleCategory} department A.
# * Each {Role} has a {Role#weight}; lower the {Role#weight} is, higher the rank,
#   ((*if*)) both of them ((%belongs_to%)) the same {RoleCategory}.
#   * For example, suppose the {Role} manager in the {RoleCategory} department A
#     has a lower {Role#weight} than the {Role} coordinater in the same department A.
#     Then, if the authorization requires the {Role} manager of the department,
#     any coordinaters in the department are not authorized.
# * No {Role} roles within a {RoleCategory} are permitted to have the same {Role#weight}.
#
# As for the last condition, you may ask a question of what you should do
# if two {Roles} in the same {RoleCategory} have an equal priviledge
# to do a certain thing. For example, think of the case {Role} female is
# authorized to give birth, whereas other {Role}s are not, but
# regardless of it, {Users} are authorized to vote for the UK-parliament.
# In this case, simply create a different a {RoleCategory} and {Role}(s),
# such as {RoleCategory} UK-citizen and {Role}s adult and child,
# which both ((%belongs_to%)) {RoleCategory} British-citizen-age but have
# different {Role#weight}s. Each user has one (or neither) of the {Role}s
# adult and child, whether they have the female {Role} or not.
# Then, test them with the authorization threshold of {Role} adult
# which ((%belongs_to%)) {RoleCategory} British-citizen-age.
#
# Finally, this framework offers one or two more levels of authorization, namely,
#
# (1) Whether the {User} is authenticated (logged in) or not,
# (2) Whether the {User} has a {Role} or not (ie. ((%nil%))).
#
# The first one should be useful; if a user logs in, s/he can view certain things
# like their account settings or even the major contents.  The use cases for
# the second one are probably more limited,
# but may be useful in certain cases, such as, prompting a new user to register
# to a role (by filling out a form, etc) or regular user to stand for a committee.
#
# === RoleCategory
#
# Here is a more detailed description of this class {RoleCategory},
# using a more realistic example for websites.
#
# The {RoleCategory} has a tree-like structure.  The highest-rank one or
# {RoleCategory.root_category} with the default machine-name "ROOT"
# (which can be modified) is reserved for the superuser of the system,
# and potentially other system administrators. The {RoleCategory.root_category}
# can have one or more {#subordinates}, for which {RoleCategory.root_category}
# is their common {#superior}. The ranking difference between those
# {#subordinates} of {RoleCategory.root_category} are not defined.
# Each of {#subordinates} can have multiple {#subordinates}
# and then descendant {#subordinates} .
#
# Arithmatic operators {RoleCategory#<} and {RoleCategory#>} are defined;
# for example, when {RoleCategory} has more than one members, and one of
# them has a machine name of "finance_hq",
#
#     RoleCategory.root_category <  RoleCategory["finance_hq"]
#
# namely, {RoleCategory.root_category} is at a higher rank.  Similarly,
#
#     RoleCategory.root_category == RoleCategory["finance_hq"].superior
#     RoleCategory.root_category.subordinates.include?(
#         RoleCategory["finance_hq"])  # => true
#
# Each {Role} has a {Role#weight}, that is, a rank; smaller it is,
# higher their rank is. However, the {RoleCategory} precedes the weight.
# For example, the {User} sysadmin, or even her/his assistant_admin who
# ((%belongs_to%)) the {RoleCategory.root_category}, is, regardless of
# their {Role#weight}s, ranked higher than any {Role}s that ((%belongs_to%))
# a different {RoleCategory}.
#
# Here is an example tree-structure of {RoleCategory}s and {Role}s.
# {RoleCategory.root_category} "ROOT" has two {#subordinates} of "finance_hq" and
# "sales_hq", and "sales_hq" has "domestic" and "abroad" as {#subordinates}.
# The {Role}s that belong to the {RoleCategory}s have the following relations.
#
# (1) Category(ROOT): sysadmin < assistant_admin
#     (1) Category(sales_hq): manager < general_coordinator
#         (1) Category(domestic): domestic_coordinator < staff_ja
#         (2) Category(abroad): abroad_coordinator < staff_en
#     (2) Category(finance_hq): director < staff_finance
#     (3) Category(company): staff
#
# where the arimatic comparison operators indicate a smaller one is
# higher in rank.
#
# As an analogy of the real life, {User}s who belong to the {Role}s
# (aka "manager" and "general_coordinator") in the {RoleCategory}
# "sales_hq" are high-ranked seniors of the headquarter of the sales
# department.
#
# In authorization, the threshold {Role} to be qualified to be authorized
# is given. For example, suppose it requires the {Role} "general_coordinator"
# (of Category=sales_hq); then any one who has a role of one or more of
# "manager" (of Category=sales_hq), "assistant_admin", and "sysadmin"
# is qualified. None of the {User}s who have only {Role}s that belong to
# Category(finance_hq) or the {#subordinates} of Category(sales_hq)
# (namely Category(domestic) and Category(abroad)) are qualified.
#
# To relate this to a realistic situation, let us think of
# an integrated web-system in a company in the above-mentioned setting.
# Here, "punching a clock" in any {Role}s under the {RoleCategory}
# "abroad" is allowed (and a duty?!) for any one in {RoleCategory}
# "sales_hq" and its {#subordinates}, but it should not be allowed
# for any one outside of the deparment, even for (high-salary?)
# "director"(s) of "finance_hq".
#
# Note that a {User} can have multiple or no {Role}s. For example,
# the company website may have staff-only pages and its front-page should
# be able to be browsed by any of its staff members.  To authorize it,
# set up another independent {RoleCategory} "company" as one of the direct
# {#subordinates} of "ROOT" with a {Role} "staff" under it, and
# give the {Role} to everyone in the company.
#
# Finally, it may be also possible to authorize with the basic Rails way
# for this type of authorization, that is, whether a {User} is logged
# in or not (the actual way depends on how you implement the User model;
# e.g., if Devise, ((%if user_signed_in?%)) or ((%if current_user%))
# would do). It can be used as a {Role}-independent but logged-in
# dependent authorization. In the example above, if all the users in
# the website are the company's staff members only (like Intranet),
# this type of symple authorization would be suffice.
#
# == Schema Information
#
# Table name: role_categories
#
#  id          :bigint           not null, primary key
#  mname       :string           not null
#  note        :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  superior_id :bigint
#
# Indexes
#
#  index_role_categories_on_mname        (mname) UNIQUE
#  index_role_categories_on_superior_id  (superior_id)
#
class RoleCategory < ApplicationRecord

  extend RoleCategoriesHelper  # for trees()

  after_commit :update_tree

  # Class instance of RoleCategoryNode to avoid duplicated DB accesses. See {#RoleCategory.tree}
  @tree_root = nil

  # {#roles} is modified so it returns the ordered list with {Role#weight}
  has_many :roles, -> { order(:weight) }, dependent: :destroy

  # reference within the model
  has_many :subordinates, class_name: "RoleCategory", foreign_key: "superior_id"  # "dependent: :destroy" would be tricky
  belongs_to :superior,   class_name: "RoleCategory", optional: true

  validates :mname, uniqueness: { case_sensitive: false }
  validates :mname, format: { with: /\A([a-z][a-z0-9_]*|ROOT)\z/, message: "only allows lower-case alphabets, numbers, and underscores" }  # "ROOT" is the sole exception.

  include ModuleCommon

  MAIN_UNIQUE_COLS = %i(mname)
  MNAME_ROOT   = 'ROOT'  # Default root category machine-name.
  MNAME_HARAMI = 'harami'
  MNAME_TRANSLATION = 'translation'
  MNAME_GENERAL_JA  = 'general_ja'

  RNAME_MODERATOR = 'moderator'
  RNAME_EDITOR    = 'editor'
  RNAME_HELPER    = 'helper'

  # Returns the {RoleCategory} for the given mname (machine-name)
  #
  # It is the *first* one, but mname is unique, so should be fine.
  #
  # @param mname [String, Symbol, RoleCategory]
  # @return [RoleCategory]
  def self.[](mname)
    return mname if mname.respond_to?(:root_category?) && mname.respond_to?(:lowest_role)
    self.where(mname: mname)[0]
  end

  # Class method to return the root {RoleCategory} ('ROOT')
  # 
  # @return [RoleCategory, NilClass] nil only if no row is defined (unlikely).
  def self.root_category
    begin
      self.first.send(__method__)
    rescue NoMethodError  # equivalent to  if !self.exists?
      nil
    end
  end

  # Convert an Array of {#RoleCategory} to Symbol to help visualization in inspect
  #
  # @param ary [Array<RoleCategory>]
  # @return [Array<Symbol>]
  def self.inspect_ary(ary)
    ary.map{|i| i.respond_to?(:map) ? send(__method__, i) : (i.respond_to?(:mname) ? i.mname.to_sym : i)}
  end

  # Returns a single RubyTree for all records of {RoleCategory}.
  #
  # Each Tree Node: (name, content) == ({RoleCategory#mname}, {RoleCategory})
  #
  # There should be only a single node for {RoleCategory}.
  # Therefore this should be suffice.
  #
  # == Caching mechanism ==
  #
  # Once this has been called a class instance {RoleCategory.tree_root} is set and
  # in any subsequent calls, the (practically cached) class instance is returned,
  # unless force_update is given true in calling.
  #
  # Note that the after_commit hook {#update_tree} is defined
  # so the class instance is automatically updated if it has been
  # already set.
  #
  # @param force_update: [Boolean] if true and if this has never been called before
  # @return [RoleCategoryNode]
  def self.tree(force_update: false)
    return @tree_root if @tree_root && !force_update
    ret = trees(klass: RoleCategoryNode)
    logger.error "(#{__FILE__}.{__method__}) RoleCategory Tree has more than one root node: #{ret}." if ret.size != 1
    @tree_root = ret[0]
  end

  # Returns a single RubyTree for all {RoleCategory} and {Role}.
  #
  # In the {RoleCategory.tree}, {RubyTree#content} is replaced from
  # the original {RoleCategory#mname} to Array of {Role},
  # which is sorted in the order of the weight (smallest weight,
  # i.e. most senior, comes first).
  # If unshift_rc==true (Default), the {RoleCategory} of the node
  # is "unshift"-ed to the {RubyTree#content}, i.e., the first element
  # of the Array is {RoleCategory} (n.b., it is inefficient in terms of
  # DB if {RoleCategory} is not going to be used).
  # Note {RubyTree#name} remains as {RoleCategory#mname}
  #
  # WARING: {RoleCategory.tree}, which is cached as @tree_root of {RoleCategory} class,
  #  is destructively modified once this method has been called!
  #
  # @param force_update: [Boolean] if true (Default(!)), cache is disabled.
  #   The default is the opposite of {RoleCategory.tree}; else it could cause more trouble
  #   because this method destructively modifies the cached {RoleCategory.tree}.
  # @param unshift_rc: [Boolean] see above
  # @return [RoleCategoryNode]
  #
  # @todo Returns a separate object from {RoleCategory.tree} instead of destructively modifying it.
  def self.tree_roles(force_update: true, unshift_rc: true)
    ret = tree(force_update: force_update)
    ret.each do |et|
      rela = et.content.roles.order(Arel.sql('CASE WHEN roles.weight IS NULL THEN 1 ELSE 0 END, roles.weight'))
      et.content = (unshift_rc ? [et.content]+rela : rela)
    end
    ret
  end

  #######################################
  # Instance methods                    #
  #######################################

  # Returns the node_depth of self in {RoleCategory.tree} (0 for Root-node)
  #
  # @return [Integer]
  def node_depth
    self.class.tree.find_by_mname(self).node_depth
  end

  # Arithmatic operator
  #
  # self is "greater", meaning non-equal or not superior (less) in rank (less privileged).
  #
  # @param other [Object] to compare with
  # @raise [ArgumentError]
  def >(other)
    compare_core?(other, other_is_higher_rank: true,  equal_is_true: false)
    #raise_with_msg('comparison', self.class.name, obj.class.name) if !(obj.respond_to?(:roles) && obj.respond_to?(:superior))
    #return false if self == obj
    #return true if superiors.include? obj
    #return false if obj.superiors.include?(self)
    #return nil  # Basically, they are not in "superior <=> subordinates" relation
  end

  # Arithmatic operator
  #
  # self is "greater/equal", meaning not superior (less) in rank (less privileged or equal).
  # "equal" simply means identical in practice (self == self).
  #
  # @param other [Object] to compare with
  # @raise [ArgumentError]
  def >=(other)
    compare_core?(other, other_is_higher_rank: true,  equal_is_true: true)
  end

  # Arithmatic operator
  #
  # self is superior (higher) in rank (more privileged).
  #
  # @param other [Object] to compare with
  # @raise [ArgumentError]
  def <(other)
    compare_core?(other, other_is_higher_rank: false, equal_is_true: false)
    #return false if self == obj
    #ret = (self > obj)
    #return nil if ret.nil?
    #!ret
  end

  # Arithmatic operator
  #
  # self is not superior (less) in rank (equally or less privileged).
  # "equal" simply means identical in practice (self == self).
  #
  # @param other [Object] to compare with
  # @raise [ArgumentError]
  def <=(other)
    compare_core?(other, other_is_higher_rank: false, equal_is_true: true)
  end


  # Comparison operator
  #
  # If compared with nil, returns nil.
  # If compared with a non-{RoleCategory}, raise ArgumentError.
  # If they are not in "superior <=> subordinates" relation, returns nil.
  # If both are equal (identical), return 0.
  # Otherwise, returns -1 or 1, as usual (-1 means self is superior).
  #
  # @return [Integer, NilClass]
  # @raise [ArgumentError]
  def <=>(obj)
    return nil if obj.nil?
    raise_with_msg('comparison', self.class.name, obj.class.name) if !(obj.respond_to?(:roles) && obj.respond_to?(:superior))
    if self == obj
      0
    else
      ret = (self > obj)
      if ret.nil?
        nil
      else
        ret ? 1 : -1
      end
    end
  end

  # True if they are in "superior <=> subordinates" relation
  def related?(other)
    !compare_core?(other).nil?
  end

  # return true if self is *ROOT* (for sysadmin etc)
  def root_category?
    !superior
  end

  # return the root {RoleCategory} ('ROOT')
  # 
  # @return [RoleCategory]
  def root_category
    root_category? ? self : superiors[0]
  end

  # Array of superiors with the first one at the highest rank ("ROOT")
  #
  # For the root category ('ROOT'), an empty Array is returned.
  #
  # @return [Array] 
  def superiors
    arret = [self]
    while nex = arret[0].superior
      arret.unshift nex
    end
    arret.pop
    arret
  end

  # @return [Role, NilClass] the lowest role that belongs to self. nil if none.
  def lowest_role
    roles.sort[-1]
  end

  #################

  private

    def update_tree
      self.class.tree(force_update: true) if self.class.tree_root
    end

    # raise ArgumentError if duck-typing fails or {RoleCategory} differ
    #
    # @param obj [Object] to compare.
    # @param nil_if_category_differ: [Boolean] return nil if the {RoleCategory}s
    #   differ, else raise ArgumentError]
    # @return [TrueClass, NilClass] true if it is comparable. If not, but
    #   the same class, and if +nil_if_category_differ+ is true, returns nil,
    #   else ArgumentError
    # @raise [ArgumentError]
    def raise_if_incomparable(obj, nil_if_category_differ: false)
      raise_with_msg('comparison', self.class.name, obj.class.name) if !(obj.respond_to?(:roles) && obj.respond_to?(:superior))
      return true if obj.role_category == role_category
      return nil if nil_if_category_differ
      raise_comparison_err(obj)  # defined in module ModuleCommon
    end

    # Arithmatic operator
    #
    # @param other [Object] to compare with
    # @param oper1 [Symbol]
    # @param oper2 [Symbol, NilClass] if nil, set as the same as oper1
    # @raise [ArgumentError]
    # @example self is less than or equal to other
    #   compare_core?(other, :<, :<=)
    def compare_core?(other, other_is_higher_rank: true, equal_is_true: false)
      raise_with_msg('comparison', self.class.name, other.class.name) if !(other.respond_to?(:roles) && other.respond_to?(:superior))
      return  equal_is_true if self == other
      return  other_is_higher_rank if superiors.include? other
      return !other_is_higher_rank if other.superiors.include?(self)
      return nil  # Basically, they are NOT in "superior <=> subordinates" relation
    end
end

class << RoleCategory
  attr_reader :tree_root
end

