# coding: utf-8

include ModuleCommon  # for seed_fname2print

puts "DEBUG: start "+seed_fname2print(__FILE__) if $DEBUG
if !Rails.env.development?
  puts "  NOTE(#{seed_fname2print(__FILE__)}): skipped because it is not in Development environment."
  return 
elsif !User.exists?  # Administrator must exist for this script to be run.
  puts "  NOTE(#{seed_fname2print(__FILE__)}): skipped because no users exist. Once the sysadmin is created, run this (i.e., bin/rails db:seed) again."
  return 
end

# Models: User and UserRoleAssoc
#
# Creates (if not exists) 13 users (3 {RoleCategory} x (1 all-mighty + 3 roles x single-role)) + NoRole
#
# Created users' email addresses are like
#
# * no_role@example.com
# * moderator_all@example.com
# * editor_translation@example.com
# * helper_general_ja@example.com
#
# with {User#display_name} of "NoRole", "ModeratorAll", "EditorTranslation", "HelperGeneralJa", etc.
# Here, "*All" has the {Role} in all 3 {RoleCategory}, whereas other users have
# only a single {Role} each.
#
# When a {User} exists, the user information is not updated, but {Role}s are
# still added, unless {User} has a {Role#superior?} role.
#
# If $DEBUG is set, more information is printed.
#
module SeedsUsers
  # Everything is a function
  module_function

  # @param key [String] maybe "ModeratorAll", "ModeratorTranslation", "EditorGeneralJa", "NoRole", etc
  def get_hash4user(key)
    {
      email: key.underscore+'@example.com',
      password: '123456',
      #encrypted_password: User.new.send(:password_digest, '123456')
      display_name: key,
      accept_terms: '1',
    }
  end

  # @return [String] "ModeratorAll", "EditorAll" etc.
  def get_key4all(rname)
    rname.to_s.camelize+"All"
  end

  # @param role [Role]
  # @return [NilClass, User] nil if user is already has the {Role} (or an upper {Role}}, else {User}
  def add_a_role(user, role)
    return if user.qualified_as?(role)
    puts "Role #{role.uname} is added to #{user.display_name}." if $DEBUG
    user.roles << role
    user
  end

  # Returns the number of DB entries before/after
  #
  # @return [Hash] entries[:init|:fini] = {user: User.count, assoc: UserRoleAssoc.count}
  def users_main
    hs_role_category = {
      harami:      RoleCategory[RoleCategory::MNAME_HARAMI],
      translation: RoleCategory[RoleCategory::MNAME_TRANSLATION],
      general_ja:  RoleCategory[RoleCategory::MNAME_GENERAL_JA],
    }

    rnames = {
      moderator: Role::RNAME_MODERATOR,
      editor:    Role::RNAME_EDITOR,
      helper:    Role::RNAME_HELPER,
    }

    entries = {}
    entries[:init] = {user: User.count, assoc: UserRoleAssoc.count}

    # Each element has, e.g., ("ModeratorAll" => {hs: Hash.new, user: User.new})
    # where keys are: "ModeratorAll", "ModeratorTranslation", "EditorGeneralJa", "NoRole", etc
    hs_multi_role_user = {}
    hs_single_role_user = {}
    hs_no_role_user = {}

    rnames.each_pair do |rname, role|
      key = get_key4all(rname)
      hs_multi_role_user[key] = {hs: get_hash4user(key)}

      hs_role_category.each_key do |rc_mname|
        key = [rname, rc_mname].map{|i| i.to_s.camelize}.join("")
        hs_single_role_user[key] = {hs: get_hash4user(key)}
      end
    end


    key = 'NoRole'
    hs_no_role_user[key] = {hs: get_hash4user(key)}  # created_at will be later than the other users

    ## Create users
    [hs_multi_role_user, hs_single_role_user, hs_no_role_user].each do |eh_user|
      eh_user.each_pair do |ek, ehs|
        ehs[:user] = User.find_by(email: ehs[:hs][:email])
        next if ehs[:user]  # User already exists. Still, Roles may be added.
        next if User.find_by(display_name: ehs[:hs][:display_name])  # User with the same display_name is counted as a duplication in seeding.
        ehs[:user] = user = User.create!(**(ehs[:hs]))
        user.skip_confirmation_notification!
        user.skip_confirmation!
        user.skip_reconfirmation!
        user.confirm
        user.save!
        puts "user created: #{ehs[:user].display_name}"  if $DEBUG
      end
    end

    ## Add roles
    rnames.each_pair do |rname, role|
      hs_role_category.each_pair do |rc_mname, role_category|
        role = Role[rname, role_category]

        user = hs_multi_role_user[get_key4all(rname)][:user]
        add_a_role(user, role) if user

        user = hs_single_role_user.find{|i| i[0].include?(rname.to_s.camelize) && i[0].include?(rc_mname.to_s.camelize)}[1][:user]
        add_a_role(user, role) if user
      end
    end

    entries[:fini] = {user: User.count, assoc: UserRoleAssoc.count}
    entries
  end  # def users_main
end    # module SeedsUsers

entries = SeedsUsers.users_main

diff_entries = %i(user assoc).map{|i| entries[:fini][i] - entries[:init][i]}
if diff_entries.any?{|i| i > 0} || $DEBUG
  printf("  %s: %s Users and %s UserRoleAssocs are created.\n", seed_fname2print(__FILE__), *diff_entries)
end

