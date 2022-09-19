source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.1.2'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
#gem 'rails', '~> 6.1.4', '>= 6.1.4'
gem 'rails', '~> 6.1.7', '>= 6.1.7'

# Use pg as the database for Active Record
gem 'pg', '>= 0.18', '< 2.0'
# Use Puma as the app server
gem 'puma', '~> 4.1'
# Use SCSS for stylesheets
gem 'sass-rails', '>= 6'
# Transpile app-like JavaScript. Read more: https://github.com/rails/webpacker
gem 'webpacker', '~> 5.0'  # Rails 6.1 default (was 4.0 in Rails 6.0)
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.7'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Active Storage variant
# gem 'image_processing', '~> 1.2'

# Reduces boot times through caching; required in config/boot.rb
#gem 'bootsnap', '>= 1.4.2', require: false
gem 'bootsnap', '~> 1.8', require: false  # This was necessary to avoid: realpath_cache.rb:17:in `dirname': no implicit conversion of nil into String (TypeError)

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
end
gem 'dotenv-rails', groups: [:development, :test]  # User-added; this may need to come before some Gems

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '~> 3.2'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
end

group :test do
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara', '>= 2.15'
  gem 'selenium-webdriver'
  # Easy installation and use of web drivers to run system tests with browsers
  gem 'webdrivers'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

### Ruby 3 requirement
gem 'rexml', '~> 3.2', '>= 3.2.5'

### User-added
gem 'rails-i18n', '~> 6.0' # For 6.0 or higher
gem 'i18n-timezones'
gem 'devise'
gem 'devise-i18n'
gem 'jquery-rails'  # required for toastr
gem 'toastr-rails'
gem 'rails_admin', '~> 2.0'
gem 'cancancan'
# gem 'active_record-postgres-constraints' # Valid up to Rails 6.0 but obsolete (not work) at 6.1.
gem 'datagrid', '~> 1.4', '>= 1.4.4'
gem 'rubytree', '~> 2', '>= 2.0.0'
gem 'slim_string', '~> 1', '>= 1.0.1'
gem 'simple_form', '~> 5', '>= 5.1.0'
gem 'paper_trail', '~> 12.3', '>= 12.3'  # used to use 12.0 up to Rails 6.0 (which causes error in Rails 6.1); recommended to update to 13.0 with the condition to switch the column type: @see my comment about "yaml" in config/application.rb
# gem 'high_voltage', '~> 3.1', '>= 3.1.2'
# gem 'routing-filter', '~> 0', '>= 0.6.3' # Only git HEAD works with Rails 6.1.
gem 'routing-filter', '~> 0', '>= 0.6.3', git: 'https://github.com/svenfuchs/routing-filter'
gem 'redirector', '~> 1.1', '>= 1.1.2'
gem 'redcarpet', '~> 3', '>= 3.3.4'

# Necessary in Ruby 3.1
gem 'net-smtp', '~> 0.3', '>= 0.3.1'
gem 'matrix', '~> 0.4'  # This may not be necessary in other than test, but is included anyway.
group :test do
  # Necessary in Ruby 3.1
  #gem 'matrix', '~> 0.4'
end

group :development do
  gem 'annotate'
  gem 'kramdown', require: false
end

group :development, :test do
  gem 'minitest-reporters', '~> 1', '>= 1.4.3'  # depending on rubocop
  gem 'w3c_validators', '~> 1', '>= 1.3.6'
end

