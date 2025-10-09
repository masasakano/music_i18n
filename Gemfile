source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.4.6'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails', branch: "main"
#gem 'rails', '~>6.1'
#gem 'rails', '~> 7.0', '>= 7.0.4'
gem 'rails', '~> 7.2.2'

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"

# Use pg as the database for Active Record
gem 'pg', '>= 1.5', '< 2.0'
# Use the Puma web server [https://github.com/puma/puma]
#gem 'puma', '~> 4.1'  # Rails 6
#gem 'puma', '~> 6.4'   # >=5.0 for Rails 7.0 default
gem 'puma', '~> 7.0'
## Use SCSS for stylesheets (obsolete as of 2019)
#  https://sass-lang.com/ruby-sass
#  https://github.com/rails/sass-rails
#  https://rubygems.org/gems/sass-rails
#gem 'sass-rails', '>= 6'
## Transpile app-like JavaScript. Read more: https://github.com/rails/webpacker
#gem 'webpacker', '~> 5.0'  # Rails 6.1 default (was 4.0 in Rails 6.0)
## Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
#gem 'turbolinks', '~> 5'  # Rails 6
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder' #, '~> 2.7'
# Use Redis adapter to run Action Cable in production
gem 'redis', '~> 5.0'

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ jruby windows ]  # %i[mingw mswin x64_mingw] deprecated in at least Ruby 3.4

# Reduces boot times through caching; required in config/boot.rb
#gem 'bootsnap', '>= 1.4.2', require: false
gem 'bootsnap', require: false  # NOTE: This was necessary to avoid: realpath_cache.rb:17:in `dirname': no implicit conversion of nil into String (TypeError)

gem 'listen', '~> 3' #, '~> 3.2'  # This seems necessary from bootsnap (for booting, i.e., ./bin/dev) despite the fact it is not included in Rails 7 default Gemfile...

######### Rails 7 default with --css=bootstrap
# Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]
gem "jsbundling-rails"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

# Bundle and process CSS [https://github.com/rails/cssbundling-rails]
gem "cssbundling-rails"

# Use Sass to process CSS
# This is commented out in Rails-7+bootstrap default.
# However, in this environment, this seems essential.  Without this, Sever returns an Error, demanding `sassc` .
# If you use this, the develope says: make sure to include in /config/environments/development.rb
# the line:  config.sass.inline_source_maps = true
# although in reality it seems to work even without the line in development.rb
# When something goes wrong, you may encounter errors in "./bin/dev" like:  `method_missing': undefined method `sass'
# Or it may prompt you to install Gem sass (but don't, because it became obsolete in 2019).
# NOTE: sass is defined in package.json (in the same way as in Rails-7+bootstrap default)
gem "sassc-rails"

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ]  # %i[mingw x64_mingw] (and :mswin though not used here) deprecated in at least Ruby 3.4

  #### Rails 6: see https://blog.saeloun.com/2021/09/29/rails-7-ruby-debug-replaces-byebug.html
  ## Call 'byebug' anywhere in the code to stop execution and get a debugger console
  #gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]  # Add :windows while %i[mingw x64_mingw] deprecated in at least Ruby 3.4 (Note that this Gem is deprecated anyway)
end

### Personal addition

gem 'dotenv-rails', groups: [:development, :test]  # User-added; this may need to come before some Gems

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  #gem 'web-console', '>= 3.3.0'
  gem 'web-console' #, '~> 4.2'

  #gem 'listen', '~> 3' #, '~> 3.2'

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  #gem 'spring', '~> 4.0'  # >= 3.0 for Rails-7 (or you can remove it)
  #gem 'spring-watcher-listen', '~> 2.0' # This depends on spring (>= 1.2, < 3.0), whereas Rails-7 requires spring >= 3
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara' #, '>= 2.15'
  gem 'selenium-webdriver'
end

### User-added
gem 'rails-i18n', '~> 7.0.0' # For Rails 7.0 and 7.1
gem 'i18n-timezones'
gem 'devise', '~> 4.9'
gem 'devise-i18n'
gem 'jquery-rails'  # required for toastr
gem 'toastr-rails'
gem 'rails_admin', '~> 3.0'  # For Rails-7; need run:  DISABLE_SPRING=1 bin/rails g rails_admin:install  cf. https://stackoverflow.com/a/72674116
gem 'cancancan'
# gem 'active_record-postgres-constraints' # Valid up to Rails 6.0 but obsolete (not work) at 6.1.
gem 'datagrid', '~> 2.0'  # merged from its branch: 'version-2'
gem 'rubytree', '~> 2', '>= 2.0.0'
gem 'slim_string', '~> 1', '>= 1.0.1'
gem 'simple_form', '~> 5', '>= 5.1.0'
gem 'paper_trail', '~> 15', '>= 15.0.0'  # used to use 12.0 up to Rails 6.0 (which causes error in Rails 6.1); recommended to update to 13.0 with the condition to switch the column type: @see my comment about "yaml" in config/application.rb; at least 16 for Rails 8
# gem 'high_voltage', '~> 3.1', '>= 3.1.2'
gem 'http_accept_language'
# gem 'routing-filter', '~> 0', '>= 0.6.3' # Only git HEAD works with Rails 6.1.
# gem 'routing-filter', '~> 0', '>= 0.6.3', git: 'https://github.com/svenfuchs/routing-filter'
gem 'routing-filter', '~> 0', '>= 0.7.0'  # necessary for Locale/I18n to add the locale prefix like /en/abc/5 in routes
gem 'redirector', '~> 1.1', '>= 1.1.2'
gem 'redcarpet', '~> 3', '>= 3.3.4'
gem 'kaminari-i18n'  # https://github.com/tigrish/kaminari-i18n
gem 'plain_text'     # used in /lib/reverse_sql_order.rb
gem 'rails-html-sanitizer'  # https://github.com/rails/rails-html-sanitizer
gem 'i18n_data'  # for language names (and country names)
gem 'diff-lcs', '~> 1.5', '>= 1.5.1'
gem 'unicode-emoji', '~> 4', '>= 4.1'
gem 'google-apis-youtube_v3', '~> 0.57'
gem 'rails_autolink', '~> 1.1', '>= 1.1.8'

### Ruby 3 requirement
gem 'rexml', '~> 3.2', '>= 3.2.5'

# Necessary in Ruby 3.1
gem 'net-smtp', require: false #, '~> 0.3', '>= 0.3.1'
gem 'net-imap', require: false #
gem 'net-pop', require: false  # needs in production in Rails-6.1 Ruby-3.1: https://stackoverflow.com/a/72474475/3577922
gem 'matrix'  # This may not be necessary in other than test, but is included anyway.

# Necessary in upgrading Ruby from 3.1 to 3.4.6
gem "nkf"
# gem "benchmark"
gem "open-uri"

group :development do
  gem 'annotate'
  gem 'kramdown', require: false
end

group :development, :test do
  gem 'minitest-reporters', '~> 1', '>= 1.4.3'  # depending on rubocop
  gem 'w3c_validators', '~> 1', '>= 1.3.6'
end
