# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :inet
#  display_name           :string           default(""), not null
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  ext_account_name       :string
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :inet
#  provider               :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  sign_in_count          :integer          default(0), not null
#  uid                    :string
#  unconfirmed_email      :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
class User < ApplicationRecord
  include ApplicationHelper

  after_commit :promote_first_user_to_root, on: :create
  # First-ever user is automatically promoted to sysadmin (superuser in ROOT) and confirmed.
  # WARNING: Make sure the email address is correct.

  has_many :user_role_assocs, dependent: :destroy
  has_many :roles, through: :user_role_assocs
  has_many :created_translations, class_name: "Translation", foreign_key: "create_user_id", dependent: :nullify
  has_many :updated_translations, class_name: "Translation", foreign_key: "update_user_id", dependent: :nullify

  validates_uniqueness_of :email, case_sensitive: false  # As in Default, allow_nil: false (nb empty string is allowed)

  attr_accessor :accept_terms
  validates_acceptance_of :accept_terms, on: :create
  validates_presence_of   :accept_terms, on: :create

  # Include default devise modules. Others available are:
  # :lockable, :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :timeoutable, :trackable

  MAIN_UNIQUE_COLS = %i(display_name email encrypted_password)
  EXUSERROOT = 'exuser-'  # display_name becomes "exuser-29" when user.id=29 is deactivated.
  DEACTIVATE_METHOD_FORM_NAME = 'deactivate_method'
  DEACTIVATE_METHOD = {
    rename:  'Display_name renamed.',
    destroy: 'User completely destroyed.'
  }
  ROLE_FORM_RADIO_PREFIX = 'role_'

  # Returns an array of sysadmin (root)
  #
  # @return [Array<User>]
  def self.roots
    RoleCategory.root_category.roles.sort[0].users
  end

  # Get the exuser name when the user is deactivated.
  def get_exuser_name
    EXUSERROOT+id.to_s
  end

  # Get the exuser email-address (which cannot be blank) when the user is deactivated.
  def get_exuser_email
    get_exuser_name+'@example.com'
  end

  # true if self is qualified to be authorized for the given Role
  #
  # In other words, true if one of my rank is the same as or higher than
  # the given role to compare with.
  #
  # Note that {#qualified_as?}('editor') returns true if the user is qualified
  # as an editor in at least one of the {Role}s s/he has.
  #
  # @param role [Role, String, Symbol, RoleCategory] if not Role or {RoleCategory},
  #    this must be a machine name of {Role}.
  #    If {RoleCategory}, it is compared with the lowest {Role} in the category,
  #    that is, true if {User} has a role that belongs to the {RoleCategory} or anything higher.
  # @param rcat  [RoleCategory, String, Symbol, NilClass] if needed
  # @raise [ArgumentError] if other's class is not {Role} or inappropriate as {Role#name}
  def qualified_as?(role, rcat=nil)
    roles.any?{|i| i.send(__method__, role, rcat) }
  end
  alias_method :role_is_or_higher_than?, :qualified_as? if ! self.method_defined?(:role_is_or_higher_than?)
  alias_method :has_role?,               :qualified_as? if ! self.method_defined?(:has_role?)

  def moderator?
    qualified_as?('moderator')
  end

  def editor?
    qualified_as?('editor')
  end

  def an_admin?
    roles.any?{|i| i.send(__method__) }
  end

  def sysadmin?
    roles.any?{|i| i.send(__method__) }
  end
  alias_method :superuser?, :sysadmin? if ! self.method_defined?(:superuser?)

  ## Role-related change ##

  # Helper method to add {Role}(s), often immediately following (or even before) initialization
  #
  # This method does not affect the existing {Role}s attached to the {User}
  # if there is any.
  #
  # @example new
  #   u1 = User.new.with_roles(Role['editor', 'translation'], Role['helper', 'general_ja'])
  #   u1 = User.create!(email: em, password: pw).with_roles(2)  # 2 as in primary ID of a Role
  #
  # @param roles [Array<Role>, Role, Integer] Can be a primary ID or Role(s)
  # @param *rest [Array<Role>] If the first one is {Role}, others can be specified.
  # @return [User]
  def with_roles(roles, *rest)
    if roles.respond_to? :numerator
      # Primary ID of a Role
      self.roles << Role.find(roles)
      return self
    end

    myroles = self.roles
    ([roles]+rest).flatten.uniq.select{|i| !myroles.include? i}.each do |ea_r|
      self.roles << ea_r
    end
    self
  end

  # Returns true only if other is a subordinate of self in all his roles.
  #
  # i.e., true if "abs(olutely) superior to" other.
  #
  # For example, if self has a role of sysadmin, whereas
  # other does not, then true.
  # Or, if self is a "leader" in Finance {RoleCategory} only,
  # whereas other is a "servant" in Finance and in Sales, this returns
  # false, because self has no role in Sales and hence is not superior
  # in Sales {RoleCategory} to other.
  #
  # This is identical to {#superior_to?}(other_user, nil)
  #
  # @param other [User]
  def abs_superior_to?(other)
    Role.all_superior_to?(roles, other.roles)
  end

  # Returns true if other is a subordinate of self in the role_category
  #
  # other can be a {Role} or {User}.
  # If other is {Role}, role_category is ignored.
  # If other is {User} and role_category is not given, it is the same as {#abs_superior_to?}
  #
  # For example, if self has a role of sysadmin, whereas
  # other (User) does not, then true.
  # Or, if self is a "leader" in Finance {RoleCategory} and "helper" in Sales
  # whereas other is a "manager" in Sales, {#superior_to?}(other, RC['Sales'])
  # returns false, because self is a subordinate in RC['Sales'], whereas
  # {#superior_to?}(other, RC['Finance']) returns true.
  # Note {#superior_to?}(other) returns false, because the former returns false.
  #
  # In this case, if self has no role in (or superior to) the specified {RoleCategory},
  # this reutrns false. If self has one, whereas other doesn't, this returns true.
  #
  # @param other [User, Role]
  # @param role_category [RoleCategory, NilClass]
  def superior_to?(other, role_category=nil)
    if other.respond_to? :higher_category_than?
      # Role
      return roles.any?{|i| i.send __method__, other}
    end

    return abs_superior_to?(other) if !role_category  # can be processed within this method, actually...

    # other is User and RoleCategory is specified.
    other_related_roles = other.roles.select{|i| i.role_category.related?(role_category)}
    if other_related_roles.empty?
      roles.any?{|i| i.role_category.related?(role_category)}
    else
      roles.any?{|i| i.role_category.related?(role_category) && other.roles.any?{|j| i.send(__method__, j)}}
    end
  end

  # User's highest role in the specified {RoleCategory} or higher
  #
  # For example, if the user is sysadmin, this always returns Role[:admin]
  #
  # If the user has no role in the specified {RoleCategory} or higher, nil is returned.
  #
  # @param category [RoleCategory]
  # @return [Role, NilClass]
  def highest_role_in(category)
    roles.find_all{|ea_r|
      ea_r.qualified_as? category.lowest_role
    }.sort[0]
  end

  # {Role} of self (user) in the specified {RoleCategory}s.
  #
  # @param category [RoleCategory]
  # @return [Relation]
  def roles_in(category)
    category.roles.joins(:user_role_assocs).where(user_role_assocs: {user: self})
  end

  # {Role} of self (user) in the specified {RoleCategory}s.
  #
  # In terms of the DB, a user may have multiple Roles that belong to
  # the same {RoleCategory}. In practice, that should never happen.
  # This method simply returns the first one that is found.
  #
  # @param category [RoleCategory]
  # @return [Role, NilClass] nil if not found.
  def role_in(category)
    roles_in(category).first
  end

  ######## Translation related ########

  def touched_translations
    Translation.where("create_user_id = ? OR update_user_id = ?", self.id, self.id)
  end

  # Anonymize all translations that belong to the user
  #
  # This is usually called before a user is completely removed
  # from the "users" table.
  #
  # Hash of the numbers of anonymized translations are returned.
  # The keys are symbols and :n_unique is the number of the words
  # for which either or both of the created and updated users are
  # this user.
  #
  # See {#touched_translations}
  #
  # @return [Hash<Integer>] n_created, n_updated, n_unique
  def anonymize_all_my_trans!
    hsid = {
      created: created_translations.map{|i| i.id},
      updated: updated_translations.map{|i| i.id},
    }
      
    logger.info "(#{__method__}) Translations by User (ID=#{self.id}) are anonymized: Translation-IDs: created=#{hsid[:created].inspect}, updated=#{hsid[:created].inspect}."

    created_translations.each do |et|
      et.create_user_id = nil
      et.save!
    end

    updated_translations.each do |et|
      et.update_user_id = nil
      et.save!
    end

    {
      n_created: hsid[:created].count,
      n_updated: hsid[:updated].count,
      n_unique: (hsid[:created]+hsid[:updated]).uniq.size,
    }
  end

  ############ For displaying/printing ############

  # Returns an Array of Role[Category]-s to print.
  #
  # @example
  #   user.roles_inspect.map{|i| h(i).html_safe}.join('<br />')
  #   # => ["moderator [finance < ROOT]", "subadmin [ROOT]"]
  def roles_inspect
    roles.map{|i|
      i.inspect brief: true
    }
  end

  private

    # First-ever user is automatically promoted to sysadmin (superuser in ROOT) and confirmed.
    # 
    # This is fired *after* the confirmation email is sent to the user.
    def promote_first_user_to_root
      return if User.count != 1
      logger.info "The first user is promoted to a superuser/root/sysadmin and confirmed."
      UserRoleAssoc.create! user: self, role: Role.superuser
      confirm
      save!
    end
end
