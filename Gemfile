source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "4.0.6"

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails', branch: "main"
gem "rails", "~> 8.1.3", ">= 8.1.3.1"

# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"  # Rails-8.0 default

# Use pg as the database for Active Record
gem 'pg', '>= 1.5', '< 2.0'
# Use the Puma web server [https://github.com/puma/puma]
#gem 'puma', '~> 4.1'  # Rails 6
#gem 'puma', '~> 6.4'   # >=5.0 for Rails 7.0 default
gem 'puma', '~> 7.0'

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
#gem "importmap-rails"  # Included (i.e., ON) in Rails-8.0 default
# Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]
gem "jsbundling-rails"  # Rails 7 default with --css=bootstrap

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Bundle and process CSS [https://github.com/rails/cssbundling-rails]
gem "cssbundling-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder" #, "~> 2.7"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]  # %i[mingw mswin x64_mingw] deprecated in at least Ruby 3.4

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"  # Included (i.e., ON) in Rails-8.0 default
gem "solid_queue"  # Included (i.e., ON) in Rails-8.0 default
gem "solid_cable"  # Included (i.e., ON) in Rails-8.0 default

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false  # NOTE: This was necessary to avoid: realpath_cache.rb:17:in `dirname": no implicit conversion of nil into String (TypeError)

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false  # Rails-8.0 default

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false  # Rails-8.0 default

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

# Use Redis adapter to run Action Cable in production
gem 'redis', '~> 5.0'  ######## NOTE: redis 6.0 was released on 2026-07-31; you may eventually upgrade it.  Or, you may delete it as this is not listed in Rails-8.1 default

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

gem 'listen', '~> 3' #, '~> 3.2'  # This seems necessary from bootsnap (for booting, i.e., ./bin/dev) despite the fact it is not included in Rails 7 default Gemfile...

group :development, :test do
  gem 'dotenv-rails' #, groups: [:development, :test]  # User-added; this may need to come before some Gems

  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"  # %i[mingw x64_mingw] (and :mswin though not used here) deprecated in at least Ruby 3.4

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console" #, '~> 4.2'
  ## Access an interactive console on exception pages or by calling 'console' anywhere in the code.

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
  gem "capybara" #, ">= 2.15"
  gem "selenium-webdriver"
  gem "minitest"
end

### User-added
gem 'rails-i18n', '~> 8.1.0' # For Rails 8
gem 'i18n-timezones'
gem 'devise', '~> 5.0'
gem 'devise-i18n'
gem 'jquery-rails'  # required for toastr
gem 'toastr-rails'
# gem 'rails_admin', '~> 3.0'  # For Rails-7; need run:  DISABLE_SPRING=1 bin/rails g rails_admin:install  cf. https://stackoverflow.com/a/72674116
# gem 'rails_admin', github: 'railsadminteam/rails_admin', branch: 'master'  ## WARNING: (temporary) To avoid loads of deprecation warnings about frozen String issued in Ruby-4.0 (once the patch to fix the issues is merged in the master branch) # This still does not work with Propshaft as of July 2026
gem 'motor-admin'

gem 'cancancan'
# gem 'active_record-postgres-constraints' # Valid up to Rails 6.0 but obsolete (not work) at 6.1.
gem 'datagrid', '~> 2.0'  # merged from its branch: 'version-2'
gem 'kaminari', '>= 1.2.2'
gem 'rubytree', '~> 2', '>= 2.0.0'
gem 'slim_string', '~> 1', '>= 1.0.1'
gem 'simple_form', '~> 5', '>= 5.1.0'
gem 'paper_trail', '~> 17', '>= 17.0'  # used to use 12.0 up to Rails 6.0 (which causes error in Rails 6.1); recommended to update to 13.0 with the condition to switch the column type: @see my comment about "yaml" in config/application.rb; at least 16 for Rails 8.0, and at least 17 for Rails 8.1
# gem 'high_voltage', '~> 3.1', '>= 3.1.2'
gem 'http_accept_language'
gem 'redirector', '~> 1.1', '>= 1.1.2'
gem 'redcarpet', '~> 3', '>= 3.3.4'
gem 'kaminari-i18n'  # https://github.com/tigrish/kaminari-i18n
gem 'plain_text'     # used in /lib/reverse_sql_order.rb
gem 'rails-html-sanitizer'  # https://github.com/rails/rails-html-sanitizer
gem 'i18n_data'  # for language names (and country names)
gem 'diff-lcs', '~> 2.0' #, '>= 2.0.0'
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
  gem 'annotaterb', '~> 4.13'  # migrated from 'annotate' in Rails 8
  gem 'kramdown', require: false
  gem 'yard-activerecord'
  gem "rubocop-erb", require: false
  # gem "herb", require: false  # It seems "rubocop-erb" depends on this, so this is installed anyway.
  gem "erb_lint", require: false
  gem 'letter_opener', '>= 1.10'
end

group :development, :test do
  gem 'minitest-reporters', '~> 1', '>= 1.4.3'  # depending on rubocop
  gem 'w3c_validators', '~> 1', '>= 1.3.6'
end
