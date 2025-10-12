This directory `/lib/ext/` is not the Rails standard directory.

However, this directory is meant to store (perhaps *monkey-patch*) libraries to modify the existing modules/classes that have been defined in external libraries.  The top directory (under `/lib/ext/`) should be the library (aka Gem) name.

There are two requirements to `require` Ruby library files under this directory.

1. If the Rails app is configured so that the the list of auto-loading directories include `lib` as in the default in Rails 8.0, you should exclude the directory `ext` from it, typically defined in `/config/initializers/application.rb`, e.g.,

   ```ruby
   config.autoload_lib(ignore: %w[assets tasks templates ext modified_active_record])
   ```
   * If `lib` is not in the auto-loading directories, there is nothing to do.
2. Require manually each file when needed, or write this in `/config/initializers/ext.rb` (which is **not** the standard Rails file):

   ```ruby
   Dir.glob(Rails.root.join('lib/ext/**/*.rb')).sort.each do |filename|
     require filename
   end
   ```

Be careful about the order of requiring if there are any mutual dependencies.

## Warning

Monkey-patch files for `ActiveRecord` perhaps should not be placed here, but in `lib/modified_active_record/`, and should be explicitly require-d at the end of `app/models/application_record.rb`, because it seems the settings of `ActiveRecord` are not finalized until ApplicationRecord has been defined.

