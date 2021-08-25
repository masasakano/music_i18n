
# To output SQL statements to STDOUT during a rake task
#
# https://stackoverflow.com/a/8335695/3577922
#
# USAGE: bin/rails log db:rollback
#      : bin/rails log db:migrate
task :log => :environment do
  ActiveRecord::Base.logger = Logger.new(STDOUT)
end
