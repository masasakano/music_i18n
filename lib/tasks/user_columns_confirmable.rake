# Check/Update the null columns for Rails/Devise-confirmable-related columns in Table users
#
# In Devise for Ruby on Rails, if there are users before you activate confirmable,
# and if the allowance time before confirmation is zero (Default(!)),
# then the existing users cannot log in any more (as of October 2020).
# It is because the confirmable-related columns for those users are nil
# (though I think it should be regarded as a bug of Devise-confirmable).
#
# This Rake task deals with such situation; it checks or updates
# the relevant columns of the table "users" in the DB for those who cannot
# log in any more, assuming the Rails REST scheme (i.e., the model class is "User").
#
# Usage: bin/rails user_columns_confirmable
#      : bin/rails user_columns_confirmable[check]
#      : bin/rails user_columns_confirmable[update]
#
# The last one rewrites the DB, whereas the former 2 are identical and
# just prints out the users who have null "confirmable-related" columns.
#
# (C) Masa Sakano, 2020
#

COLUMNS = %i(confirmation_token confirmed_at confirmation_sent_at)

# Returns an Array of unique tokens for the specified column.
#
# @param model [ActiveRecord] Model to check
# @param colname [Symbol, String] column name whose values are unique.
# @param size: [Integer] Size of the rerurned Array, or required number of new tokens.
# @param root_str: [String] Root name of the token (followed by 3 digits of number).
# @return [Array] of a user-defined token, like "root_str012".
def find_unique_strings(model, colname, size: 1, root_str: 'UserToken')
  # Gets an array of significant existing values for the column
  template = model.where.not(colname => nil).pluck(colname).select{|i| /\A#{Regexp.quote root_str}/ =~ i}

  arret = []
  i = 0
  while arret.size < size
    i += 1
    token = root_str + sprintf('%03d', i)  
    next if template.include? token
    arret.push token
  end
  arret
end

# @param ea_r [Model] of a user
# @return [String] to print out
def get_string_user_confirmation_cols(ea_r)
  msg = sprintf '<User: id=%d email="%s" %s=%s ', ea_r.id, ea_r.email, COLUMNS[0], ea_r.send(COLUMNS[0]).inspect
  msg += COLUMNS[1..-1].map{ |ea_c| sprintf "%s=(%s)", ea_c, ea_r.send(ea_c).inspect }.join " "
  msg + '>'
end

# Task: user_columns_confirmable
#
# Usage: bin/rails user_columns_confirmable
#      : bin/rails user_columns_confirmable[check]
#      : bin/rails user_columns_confirmable[update]
#
# Null rows of the Columns %i(confirmation_token confirmed_at confirmation_sent_at)
# are filled with an artibitrary token and the current time.
task :user_columns_confirmable => :environment do
  rela = User.where(COLUMNS[0] => nil)
  COLUMNS[1..-1].each do |ea_c|
    rela = rela.or(User.where(ea_c => nil))
  end if COLUMNS.size > 1

  rela_size = rela.size
  if rela_size == 0
    puts "NOTE: No Users have nil confirmation-related columns."
    exit
  end

  m = /\A[^\[]+\[(.+)\]/.match ARGV[0]
  argv = (m ? m[1].split(/\s*,\s*/) : [])
  if argv.size == 0 || argv[0].downcase == 'check'
    puts "NOTE: Users with nil confirmation-related columns:"
    rela.each do |ea_r|
      puts ' '+get_string_user_confirmation_cols(ea_r)
    end
    puts "NOTE: You may now run:  bin/rails 'user_columns_confirmable[update]'"
    exit
  end

  if !(argv.size == 1 || argv[1].downcase == 'update')
    warn "USAGE: bin/rails 'user_columns_confirmable[check|update]'"
    exit 1
  end

  tnow = Time.now
  if rela_size > 0
    tokens = find_unique_strings(User, COLUMNS[0], size: rela_size) # confirmation_token
    rela.each_with_index do |ea_r, i|
      ea_r.send(COLUMNS[0].to_s+'=', tokens[i]) if !ea_r.send(COLUMNS[0])
      COLUMNS[1..-1].each do |ea_c|
        ea_r.send(ea_c.to_s+'=', tnow) if !ea_r.send(ea_c)
      end
      ea_r.save!
      puts 'NOTE: DB-updated: '+get_string_user_confirmation_cols(ea_r)
    end
  end
end

