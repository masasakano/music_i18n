Monkey-patch files for `ActiveRecord` are placed here.  All the files under here should not be read by the initializer but should be explicitly require-d at the end of `app/models/application_record.rb`, because it seems the settings of `ActiveRecord` are not finalized until ApplicationRecord has been defined.

This directory should be included in (**unless** `config.autoload_lib` is NOT set) the config setting, typically defined in `/config/initializers/application.rb`, as:

```ruby
config.autoload_lib(ignore: %w[assets tasks templates ext modified_active_record])
```

