# == Schema Information
#
# Table name: roles
#
#  id                      :bigint           not null, primary key
#  name                    :string           not null
#  note                    :text
#  uname(Unique role name) :string
#  weight                  :float
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  role_category_id        :bigint           not null
#
# Indexes
#
#  index_roles_on_name                         (name)
#  index_roles_on_name_and_role_category_id    (name,role_category_id) UNIQUE
#  index_roles_on_role_category_id             (role_category_id)
#  index_roles_on_uname                        (uname) UNIQUE
#  index_roles_on_weight_and_role_category_id  (weight,role_category_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (role_category_id => role_categories.id) ON DELETE => cascade
#
class Role < ApplicationRecord

  belongs_to :role_category
  has_many :user_role_assocs
  has_many :users, through: :user_role_assocs
  validates(:uname, uniqueness: { case_sensitive: false }, allow_nil: true) if self.column_names.include? 'uname' # if clause for the fresh migration purpose only.
  validates(:name,  format: { with: /\A[a-z][a-z0-9_]*\z/, message: "only allows alphabets, numbers, and underscores" }) if self.column_names.include? 'name' # if clause for the fresh migration purpose only.
  validates(:uname, format: { with: /\A[a-z][a-z0-9_]*\z/, message: "only allows alphabets, numbers, and underscores" }, allow_nil: true) if self.column_names.include? 'uname'
  validates(:name,   uniqueness: { scope: :role_category_id }, allow_nil: true) if self.column_names.include? 'name' # if clause for the fresh migration purpose only.
  validates :weight, uniqueness: { scope: :role_category_id }, allow_nil: false
  validates_presence_of :weight

  include ModuleCommon

  MAIN_UNIQUE_COLS = %i(uname)
  RNAME_SYSADMIN = 'admin'                     # Default sysadmin (root) name  (unique name in each RoleCategory).
  MNAME_SYSADMIN = UNAME_SYSADMIN = 'sysadmin' # Default sysadmin (root) uname (unique name in all Roles).
  UNAME_TRANSLATOR = 'translator'  # Role uname of 'editor' in RoleCategory='translation'

  RNAME_MODERATOR = 'moderator'
  RNAME_EDITOR    = 'editor'
  RNAME_HELPER    = 'helper'
  DEF_WEIGHT = {
    RNAME_SYSADMIN  => 1,
    RNAME_MODERATOR => 100,
    RNAME_EDITOR    => 1000,
    RNAME_HELPER    => 100000,
  }

  DEF_WEIGHT_INCREMENT = 100

  ### Class methods ###

  # @return [Role] Superuser (the most privileged user)
  def self.superuser
    RoleCategory.root_category.roles.sort[0]
  end

  
  # Returns {Role} for a given (name, role_category) or uname(machine-name)
  #
  # If catname is not specified, returns the first one.
  # Duplication is not checked.
  #
  # The arguments have to be either
  #
  # (1) {Role}  (then name1 is returned as it is)
  # (2) {Role#name}.to_sym, {RoleCategory#mname}
  # (3) {Role#uname}.to_sym
  # (4) {Role#name}.to_sym  (only if the case (3) fails to find any record.)
  #
  # nil is returned if not found.
  #
  # @param name1 [String, Symbol, Role] {Role#name}.to_sym or {Role#uname}.to_sym
  # @param catname [String, Symbol] {RoleCategory#mname} (Symbol is accepted, too.)
  # @return [Role, NilClass]
  def self.[](name1, catname=nil)
    return name1 if name1.respond_to?(:an_admin?) # name1 is Role
    raise ArgumentError, "#{self.name}.#{__method__}: Inappropriate argument (#{name1})." if !name1.respond_to?(:to_sym)
    name1str = name1.to_s
    if catname
      ret = self.where(name: name1str, role_category_id: RoleCategory[catname])[0]
      return(ret || self.where(uname: name1str, role_category_id: RoleCategory[catname])[0])  # NOTE: I am not using `or()` deliberately, as it is just a fallback.
    end

    ret   = self.where(uname: name1str)[0]  # Guaranteed to be unique.
    return ret if ret
    arret = find_by_name(name1str)
    return arret[0] if arret.size <= 1
    raise "Ambiguous argument: multiple (=#{arret.size}) candidates are found in #{self.name}[#{name1.inspect}]"
  end

  # Returns an Array(-ish) of all {Role}s whose {Role#name} matches.
  #
  # @param name1 [String]
  # @return [Role::ActiveRecord_Relation]
  def self.find_by_name(name1str)
    self.where(name: name1str)
    # The first one is guaranteed to be unique.
  end

  # Constructor of a direct subordinate of the given {Role} in the same
  # {RoleCategory}
  #
  # {#weight} is automatically chosen in principle.
  # But if {#weight} is automatically given, it is assessed to see whether
  # it sastisfies to be a subordinate; if so, the {#weight} is used,
  # else is ignored and {#weight} is automatically chosen.
  #
  # Note this is not quite thread-safe.
  #
  # @param superior [Role] who will be the superior of the created {Role}
  # @return [Role] The final {Role} or intermediate keyword Hash
  def self.create_subordinate(superior, **kwd)
    self.create_subordinate_core(false, superior, **kwd)
  end

  # #see Role.create_subordinate
  def self.create_subordinate!(superior, **kwd)
    self.create_subordinate_core(true,  superior, **kwd)
  end

  # #see Role.create_subordinate
  # @param subordinate [Role] who will be the subordinate of the created {Role}
  def self.create_superior(subordinate, **kwd)
    self.create_superior_core(false, subordinate, **kwd)
  end

  # #see Role.create_superior
  def self.create_superior!(subordinate, **kwd)
    self.create_superior_core(true,  subordinate, **kwd)
  end

  # Returns true if the former roles are all higher in rank than the latter
  #
  # For example, if the former (arrc1) contains a sysadmin, whereas
  # the latter (arrc2) does not, then true.
  # Or, if arrc1 contains "leader" in Finance {RoleCategory} only,
  # whereas arrc2 contains "servant" in Finance and in Sales, this returns
  # false, because arrc1 has no role in Sales and hence is not superior
  # in Sales {RoleCategory} to arrc2.
  #
  # NOTE: The validity of the contents of the input array is not checked.
  #   If an invalid content is given, this method returns false.
  #
  # @param arrc1 [Array<Role>]
  # @param arrc2 [Array<Role>]
  def self.all_superior_to?(arrc1, arrc2)
    arrc2.all?{|rc2|
      arrc1.any?{|rc1|
        (rc2 <=> rc1) == 1
      }
    }
  end

  # Double Array of {Role.all} sorted in the order of the category hierarchy and role weights
  #
  # The order is something like
  #
  #   sysadmin(Role)/root(RoleCategory)
  #   harami  /moderator
  #   harami  /editor
  #   harami  /helper
  #   translation  /moderator
  #   translation  /editor (uname=translator)
  #   translation  /helper
  #   general_ja  /moderator
  #   general_ja  /editor
  #   general_ja  /helper
  #
  # Here, the weights between harami/editor and translation/moderator
  # are NOT comparable.
  #
  # Each {RoleCategory} contains an Array of the roles from the highest rank.
  #
  # @return [Array<Role>]
  def self.all_categorized
    arret = []
    RoleCategory.tree.each do |enode|
      arret.push enode.content.roles.sort
    end
    arret
  end

  # Common routine for {Role}.create_*
  #
  # @param refrole [Role] who will be the superior/subordinate role of the created {Role}
  # @param hkwd [Hash] Keyword Hash
  # @return [Hash]
  def self.create_related_common(refrole, hkwd)
    # check if refrole (superior or suordinate) exists in the DB
    if !refrole.id
      msg = "#{self.name}.#{__method__}: The given reference role does not exist in DB: #{refrole.inspect}"
      logger.error msg
      raise RuntimeError, "msg"
    end

    newkwd = {}.merge hkwd
    if !hkwd.key?(:role_category) || hkwd[:role_category] != refrole.role_category
      ## TODO: :role_category_id is not considered!!!
      newkwd[:role_category] = refrole.role_category
      if hkwd.key?(:role_category)
        logger.warning "#{self.name}.#{__method__}: Key (:role_category => #{newkwd[:role_category].mname} is specified but is inconsistent with that of the given reference role (#{refrole.role_category.mname})."
      end
    end
    # newkwd[:role_category] is guaranteed to exist.

    newkwd
  end
  private_class_method :create_related_common

  # Core of {#Role}.{#create_subordinate}
  #
  # @param bang [Boolean] if true run "bang" ({#create!}), else {#create}
  # @param superior [Role] who will be the superior of the created {Role}
  # @return [Role]
  def self.create_subordinate_core(bang, superior, **kwd)
    meth = (bang ? :create! : :create)

    newkwd = create_related_common(superior, kwd)

    if !superior.weight
      newkwd[:weight] = nil
      return send(meth, **newkwd)
    end

    rc_next = superior.subordinates_in_category[0]
    if rc_next.nil? || !rc_next.weight
      # No subordinates of superior with a defined weight
      newkwd[:weight] = superior.weight + DEF_WEIGHT_INCREMENT
      return send(meth, **newkwd)
    end

    if (superior.weight...rc_next.weight).cover?(newkwd[:weight]) && superior.weight < newkwd[:weight]
      logger.info "#{self.name}.#{__method__}: The given weight {#newkwd[:weight]} does not satisfy the condition and hence is ignored."
      return send(meth, **newkwd)
    end

    newkwd[:weight] = get_close_average(superior.weight, rc_next.weight)
    return send(meth, **newkwd)
  end
  private_class_method :create_subordinate_core

  # Core of {#Role}.{#create_superior}
  #
  # @param bang [Boolean] if true run "bang" ({#create!}), else {#create}
  # @param subordinate [Role] who will be the subordinate of the created {Role}
  # @return [Role]
  def self.create_superior_core(bang, subordinate, **kwd)
    meth = (bang ? :create! : :create)

    newkwd = create_related_common(subordinate, kwd)
    sups = subordinate.superiors_or_self_in_category

    if !subordinate.weight
      if sups.size == 1
        # The reference subordinate's weight is nil and it is the only Role
        # in the category.
        newkwd[:weight] = DEF_WEIGHT_INCREMENT
        return send(meth, **newkwd)
      end

      # Since the reference subordinate's weight is nil,
      # basically the new Role is a subordinate of the reference role's direct superior.
      if bang
        return create_subordinate!(sups[-2], **newkwd)
      else
        return create_subordinate( sups[-2], **newkwd)
      end
    end

    # The reference subordinate's weight is guaranteed to be significant.
    rc_prev = sups[-2]
    if rc_prev.nil? || !rc_prev.weight
      # No superiors of subordinate with a defined weight
      newkwd[:weight] =
        if subordinate.weight == 1
          0
        elsif subordinate.weight <= 0 || 100 < subordinate.weight
          subordinate.weight - DEF_WEIGHT_INCREMENT
        else
          subordinate.weight.quo(2)
        end
      return send(meth, **newkwd)
    end

    if (rc_prev.weight...subordinate.weight).cover?(newkwd[:weight]) && rc_prev.weight < newkwd[:weight]
      logger.info "#{self.name}.#{__method__}: The given weight {#newkwd[:weight]} does not satisfy the condition and hence is ignored."
      return send(meth, **newkwd)
    end

    newkwd[:weight] = get_close_average(rc_prev.weight, subordinate.weight)
    return send(meth, **newkwd)
  end
  private_class_method :create_superior_core

  # Returns the averaged value
  #
  # If the average is not an Integer, maybe an Integer close to it is returned
  # at the best-effort basis so that it would be easily human-readable.
  #
  # @param val1 [Numeric]
  # @param val2 [Numeric]
  # @return [Numeric]
  def self.get_close_average(val1, val2)
    low, high = [val1, val2].sort
    candret = (low+high).quo(2)
    dist = high - low
    return candret if (candret == candret.to_i) || (dist <= 1)

    # Calculate nearest Integer.
    cands = [candret.floor, candret.ceil]  # Low, High
    cands[0] = nil if (cands[0] - low < 0)
    cands[1] = nil if (high - cands[1] < 0)
    distances = [low, high].map.with_index{|ef, i| (ef-cands[i]).abs}
    return cands.zip(distances).sort{|a, b|
      if a[0].nil?
        1
      elsif b[0].nil?
        -1
      else
        a[1] <=> b[1]
      end
    }[0][0]
  end
  private_class_method :get_close_average


  #######################################
  # Instance methods                    #
  #######################################

  # Compare {RoleCategory} or raise ArgumentError if duck-typing fails.
  #
  # Returning (-1,0,1) (-1 if self's category is higher than other's).
  #
  # @param other [Object] to compare.
  # @param nil_if_category_differ: [Boolean] if true, return nil if the {RoleCategory}s
  #   are not in superior-subordinate relation, else raise ArgumentError (Def)
  # @return [Integer, NilClass] (-1,0,1) based on their categories (-1 means
  #   the {RoleCategory} of self comes first (has a higher priority), if comparable.
  #   If not, but if both are {Role} and if +nil_if_category_differ+ is true,
  #   returns nil, else ArgumentError
  # @raise [ArgumentError]
  def compare_categories(other, nil_if_category_differ: false)
    raise_with_msg('comparison', self.class.name, other.class.name) if !(other.respond_to?(:role_category) && other.respond_to?(:weight))
    return 0 if self == other
    category_relation = (role_category <=> other.role_category)
    if category_relation.nil?
      # Their categories are not in the superior-subordinate relation.
      return nil if nil_if_category_differ
      armsg = [self, other].map{|i| sprintf "Role[%s, %s]", i.name, i.role_category.mname}
      armsg.push ' due to unrelated role-categories'
      raise_with_msg('comparison', *armsg)  # defined in module ModuleCommon
    else
      category_relation
    end
  end

  # True if self and other belong to the related (comparable) categories.
  #
  # ArgumentError if not compared with an object of a different class.
  #
  # @param other [Object]
  # @raise [ArgumentError]
  def related_category?(other)
    !!compare_categories(other, nil_if_category_differ: true)
  end

  # True if self and other belong to the same categories.
  #
  # ArgumentError if not compared with an object of a different class.
  #
  # @param other [Object]
  # @raise [ArgumentError]
  def same_category?(other)
    compare_categories(other, nil_if_category_differ: true) == 0
  end

  # True if self's category is higher than other's.
  #
  # ArgumentError if not comparable, including being in an incomparable category.
  # The condition for Exception differs from {#same_categories?}
  #
  # @param other [Object]
  # @raise [ArgumentError]
  def higher_category_than?(other)
    compare_categories(other) < 0
  end

  # True if self's category is lower than other's.
  #
  # ArgumentError if not comparable, including being in an incomparable category.
  # The condition for Exception differs from {#same_categories?}
  #
  # @param other [Object]
  # @raise [ArgumentError]
  def lower_category_than?(other)
    compare_categories(other) > 0
  end


  # TRUE if in the same {RoleCategory} and in an equal rank {#weight}.
  #
  # In short, this returns
  #
  # (1) TRUE only when self and other are identical, i.e., if both are taken from the DB, they refer to the identical row,
  # (2) raises ArgumentError if compared with a different-class object,
  # (3) nil if they belong to unrelated {RoleCategory},
  # (4) FALSE otherwise.
  #
  # If both the {#weight} are nil, returns automatically FALSE even if they
  # belong to the same {RoleCategory}, because they are not comparable
  # in principle.  This behaviour is consistent with {#qualified_as?},
  # but contradicts {#<=>}, where they are treated as equal.
  # This specification is deliberate.  See {#<=>} for detail.
  #
  # @param other [Object]
  # @param other [Object] to compare with
  # @raise [ArgumentError] if compared with a different class of other
  def equal_rank?(other)
    cmp_cats = compare_categories(other, nil_if_category_differ: true)
    return nil if cmp_cats.nil?
    (self == other) && self.weight
    # (cmp_cats == 0) && (weight_numeric == other.weight_numeric) && weight
  end

  # Arithmatic operator
  #
  # @param other [Object]
  # @raise [ArgumentError]
  def <(other)
    compare_core?(other, :<)
  end

  # Arithmatic operator
  #
  # @param other [Object]
  # @raise [ArgumentError]
  def <=(other)
    compare_core?(other, :<, :<=)
  end

  # true if self is qualified to be authorized for the given Role
  #
  # In other words, true if my rank is the same as or higher than
  # the given role to compare with.
  # Note: higher the rank is, lower the {#weight} is.
  #
  # If the {#weight} of both self and other are nil, other is NOT
  # qualified (a conservative approach).  In other word, among all
  # that have the "same" undefined {#weight}, only self is qualified.
  #
  # Note the behaviour of "nil"-"nil" {#weight} comparison is consistent
  #  with that of #{equal_rank?} but contradicts that of {#<=>};
  #  {#<=>} returns 0 (aka the same) for it.  See {#<=>} for detail.
  #
  # If multiple candidate {Role}s to compare with are found, like 'moderator' for {Role#name},
  # returns true if self is equal to or higher than any of them in rank.
  #
  # @param other_role [Role, String, Symbol, RoleCategory] if not Role, it must be a machine name of {Role}.
  #    If {RoleCategory}, it is compared with the lowest {Role} in the category,
  #    that is, true if {Role} belongs to the {RoleCategory} or anything higher.
  # @param rcat [RoleCategory, String, Symbol, NilClass] if needed to identify {Role}, valid only if other_role is either String or Symbol.
  # @raise [ArgumentError] if other's class is invalid
  def qualified_as?(other_role, rcat=nil)
    raise ArgumentError, "nil is specified as a Role." if !other_role
    if other_role.respond_to? :lowest_role
      role_or_cat = other_role.lowest_role # Role
      role_or_cat ||= RoleCategory[RoleCategory.tree.find_by_mname(other_role.mname).parent.name] # Parent RoleCategory because no roles are defined in other_role(=RoleCategory); NOTE: Root RoleCategory MUST have at least one Role.
      return send(__method__, role_or_cat) # rcat is ignored.
    elsif other_role.respond_to? :weight_numeric
      others = [other_role]
    elsif !other_role.respond_to? :to_sym
      raise ArgumentError, "No Role for name=#{other_role.inspect} is found."
    else
      names = [other_role, rcat].compact
      begin
        other = self.class[*names] || (return false)
        others = [other]
      rescue RuntimeError
        others = self.class.find_by_name(other_role)
        return false if others.empty?
      end
    end

    others.any?{|i| qualified_as_single?(i)}
    # return true if self == other
    # cmp_cats = compare_categories(other, nil_if_category_differ: true)
    # return false if cmp_cats.nil?
    # return (cmp_cats == -1) if cmp_cats != 0

    # return false if !weight  # weight is nil. self is not identical to other.

    # [-1, 0].include?(weight_numeric <=> other.weight_numeric)
    # # Note: "<=" may still raise ArgumentError for unrelated
    # #  role-categories, hence inappropriate
  end
  alias_method :is_or_higher_than?, :qualified_as? if ! self.method_defined?(:is_or_higher_than?)

  # returns true if self is superior to other
  #
  # @param other [Role]
  # @raise [ArgumentError] if compared with an invalid type (this should be TypeError...)
  #    but re-raise would truncate traceback, and so leaves it as it is.
  def superior_to?(other)
    self.class.all_superior_to?([self], [other])
  end

  # Arithmatic operator
  #
  # @param other [Object]
  # @raise [ArgumentError]
  def >(other)
    compare_core?(other, :>)
  end

  # Arithmatic operator
  #
  # @param other [Object]
  # @raise [ArgumentError]
  def >=(other)
    compare_core?(other, :>, :>=)
  end

  # Comparison operator
  #
  # If compared with nil, returns nil.
  # If compared with a non-{Role}, raise ArgumentError.
  # If their categories are in "superior <=> subordinates" relation, returns as such, else nil.
  # If both are in the same categories, return (-1,0,1) based on their weights.
  #
  # NOTE: If both are in the same {RoleCategory} and both have {#weight} of nil,
  #  this returns 0, i.e., they are regarded as equal.
  #  They should not be comparable in principle.  However, it is slightly
  #  more useful in practice if this method returns 0 in such cases;
  #  because this method returns (1) nil for roles in unrelated categories,
  #  and (2) never 0 in any other cases (because each {#weight} in the
  #  same {RoleCategory} is unique).
  #  Also note the definition differs in {#qualified_as?}, where
  #  the original meaning of nil {#weight} is adhered, i.e., every other nil
  #  is "lower" in rank than the selected "nil {#weight}".
  #
  # NOTE: ary_roles.sort would fail with ArgumentError if ary_roles
  #   contains elements that are not in "superior <=> subordinates" relation
  #   because {#<=>} for the pair would return nil.
  #
  # @return [Integer, NilClass]
  # @raise [ArgumentError]
  def <=>(other)
    return nil if other.nil?  # Otherwise the next line raises Exception.
    cmp_cats = compare_categories(other, nil_if_category_differ: true)
    return nil if cmp_cats.nil?
    if cmp_cats < 0
      -1
    elsif 0 < cmp_cats
      1
    else
      # In the same RoleCategory
      # NOTE: if both weight are nil, it returns 0, i.e., they are regarded as equal.
      weight_numeric <=> other.weight_numeric
    end
  end

  # 'moderator' or higher in the same category (providing Role#name='moderator' exists in the category, except the roles in ROOT category)
  def moderator?
    an_admin? || qualified_as?('moderator', role_category)
  end

  # 'editor' or higher in the same category (providing Role#name='editor' exists in the category, except the roles in ROOT category)
  def editor?
    an_admin? || qualified_as?('editor', role_category)
  end

  # true if the role belong to the root {RoleCategory} ("ROOT").
  def an_admin?
    RoleCategory.root_category == role_category
  end

  # true if the role is at the highest rank in the {RoleCategory} ("ROOT").
  def sysadmin?
    self.class.superuser == self
  end
  alias_method :superuser?, :sysadmin? if ! self.method_defined?(:superuser?)

  # weight of either Integer or Float::INFINITY
  #
  # @return [Integer, Float]
  def weight_numeric
    weight || Float::INFINITY
  end

  # Returns a {RoleCategoryNode} corresponding to this Role
  #
  # @return [RoleCategoryNode]
  def category_node
    RoleCategory.tree.find_by_mname(role_category)
  end

  # All the roles in the same {RoleCategory} that have greater (or commonly undefined) {#weight}
  #
  # The resultant array is soreted in the order of {#weight}.
  #
  # If the {#weight} of self is nil, the others whose {#weight} is nil are regarded
  # as the "subordinates" (because they do not pass the {#qualified_as?} test).
  #
  # The resultant array is soreted in the order of {#weight}.
  #
  # Example use case: Suppose Managers are allowed to assign a {Role} to {User}s
  #   within the department.  For the Radio-box selection list for the interface
  #   of the {Role} assignment, the list of their subordinate {Role}s is required.
  #
  # @return [Array, ActiveRecord::AssociationRelation] it depends which is returned.
  def subordinates_in_category
    if weight
      role_category.roles.where("weight > #{weight} OR weight IS NULL").order(:weight)
    else
      role_category.roles.where("weight IS NULL AND ID <> #{id}")
    end
  end

  # All the roles in the same {RoleCategory} that have smaller {#weight}, plus self
  #
  # If the {#weight} of self is nil, none of the others whose weight is nil but self
  # are included in the result (because they do not pass the {#qualified_as?} test).
  #
  # The resultant array is soreted in the order of {#weight}. Most senior comes first.
  #
  # @return [Array, ActiveRecord::AssociationRelation] it depends which is returned.
  def superiors_or_self_in_category
    if weight
      role_category.roles.where("weight <= #{weight}").order(:weight)
    else
      role_category.roles.where("weight IS NOT NULL OR id = #{id}")
    end
  end

  # All the roles that are higher in rank than self (excluding self)
  #
  # If the {#weight} of self is nil, this retunrs all whose weight is nil but self.
  # The resultant array is soreted in the order of {#weight}. Most senior comes first.
  #
  # @return [Array, ActiveRecord::AssociationRelation] it depends which is returned.
  def superiors
    arret = superiors_or_self_in_category.where.not(id: id)
    role_category.superiors.each do |erc|
      arret = erc.roles.order(:weight) + arret
    end
    arret
  end

  alias_method :inspect_orig, :inspect if ! self.method_defined?(:inspect_orig)

  # Alternative inspect
  #
  # It is like "moderator(uname=nil) [harami < ROOT]"
  # where "<" is actually the opposite of how the operator "<" works
  # for {RoleCategory}, i.e.,
  #   (RoleCategory[:ROOT] < RoleCategory[:harami]) # => true
  #
  # @param brief: [Boolean] if true, returns a brief form, else as in the original
  # @param with_role_category: [Boolean] if true (Def), {RoleCategory} is included.
  # @return [String]
  def inspect(brief: false, with_role_category: true)
    return inspect_orig if !brief
    return sprintf("%s [%s]", self.name, uname.inspect) if !with_role_category

    rc = role_category
    sup = rc.superior
    sprintf "%s [%s] (%s)", self.name, uname.inspect, (sup ? [rc.mname, sup.mname].join(' < ') : rc.mname)
  end


  ## Backward compatibility for mname
  #def mname
  #  loc = caller_locations()[0]
  #  logger.warn "Role#mname is called from #{loc.label} in #{loc.absolute_path}"
  #  self.name
  #end

  ## Backward compatibility for mname=
  #def mname=(obj)
  #  loc = caller_locations()[0]
  #  logger.warn "Role#mname= is called from #{loc.label} in #{loc.absolute_path}"
  #  self.name = obj
  #end

  #################

  private

    # Arithmatic operator
    #
    # @param other [Object] to compare with
    # @param oper1 [Symbol]
    # @param oper2 [Symbol, NilClass] if nil, set as the same as oper1
    # @raise [ArgumentError]
    # @example self is less than or equal to other
    #   compare_core?(other, :<, :<=)
    def compare_core?(other, oper1, oper2=nil)
      oper2 ||= oper1
      cmp_cats = compare_categories(other)
      if cmp_cats.send(oper1, 0)
        true
      elsif 0.send(oper1, cmp_cats)
        false
      else
        weight_numeric.send(oper2, other.weight_numeric)
      end
    end

    # Core routine for {Role#qualifed_as?}
    #
    # Comparison with a single {Role}
    #
    # @param other [Role]
    def qualified_as_single?(other)
      return true if self == other
      cmp_cats = compare_categories(other, nil_if_category_differ: true)
      return false if cmp_cats.nil?
      return (cmp_cats == -1) if cmp_cats != 0

      return false if !weight  # weight is nil. self is not identical to other.

      [-1, 0].include?(weight_numeric <=> other.weight_numeric)
      # Note: "<=" may still raise ArgumentError for unrelated
      #  role-categories, hence inappropriate
    end

end
