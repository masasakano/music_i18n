require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing.
  config.server_timing = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = { "Cache-Control" => "public, max-age=#{2.days.to_i}" }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  # Disable caching for Action Mailer templates even if Action Controller
  # caching is enabled.
  config.action_mailer.perform_caching = false

  # Added by User for Devise
  # In production, the host (and port) has to be the actual web server one like 'my-app-XYZ.herokuapp.com',
  # regardless of action_mailer.smtp_settings[:address] (or :domain).
  config.action_mailer.default_url_options = { host: "localhost", port: 3000 }
  ## up to here

  # Print deprecation notices to the Rails logger.  (NOTE: put :raise to definitely detect it.)
  config.active_support.deprecation = :log

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Highlight code that enqueued background job in logs.
  config.active_job.verbose_enqueue_logs = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Raises error for missing translations.
  config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  config.action_view.annotate_rendered_view_with_filenames = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true

  # Added by Masa
  # Daily logging rotation
  #config.logger = Logger.new('development' + Time.now.strftime(".%Y%d%m.log"), 'daily')
  config.logger = Logger.new('log/' + Rails.env + Time.now.strftime(".%Y%m%d.log"), 'daily')

  # cf. https://altalogy.com/blog/rails-6-user-accounts-with-3-types-of-roles/
  config.action_mailer.perform_deliveries = true
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.default_options = {from: 'no-reply@example.com'}
  ## NOTE:
  # Gmail accepts any email addresses, but the From address of the sent emails
  # is that of the login account, whereas Reply-To is set to the provided From address.

  ## In Rails 7, if you use  sassc-rails  (to handle Sass), i.e., defined in in Gemfile,
  ## activate this line (although it seems to work even without this line...).
  ## cf. <https://github.com/sass/sassc-rails>
  config.sass.inline_source_maps = true

  # For google Gmail, you may get "Net::SMTPAuthenticationError (534-5.7.14)" or similar.
  # Chaning a password(!) may do the trick.
  # cf. https://stackoverflow.com/a/63141980/3577922
  config.action_mailer.smtp_settings = {
    user_name:      (ENV["RAILS_USER_NAME"]       || Rails.application.credentials.mail_username),
    password:       (ENV["RAILS_MAILER_PASSWORD"] || Rails.application.credentials.mail_password),
    domain:         (ENV["RAILS_MAILER_DOMAIN"]   || 'gmail.com'),
    address:        (ENV["RAILS_MAILER_ADDRESS"]  || 'smtp.gmail.com'),
    port:           (ENV["RAILS_MAILER_PORT"]     || '587'),
    authentication: :plain,
    enable_starttls_auto: true
  }
end
