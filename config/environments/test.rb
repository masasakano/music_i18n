require "active_support/core_ext/integer/time"

# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # (Rails 7) Turn false under Spring and add config.action_view.cache_template_loading = true.
  config.cache_classes = true
  ## Rails 6 default (I think)
  #config.cache_classes = false
  #config.action_view.cache_template_loading = true

  # Do not eager load code on boot. This avoids loading your whole application
  # just for the purpose of running a single test. If you are using a tool that
  # preloads Rails for running tests, you may have to set it to true.
  config.eager_load = false

  # Configure public file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    'Cache-Control' => "public, max-age=#{1.hour.to_i}"
  }

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Store uploaded files on the local file system in a temporary directory.
  config.active_storage.service = :test

  config.action_mailer.perform_caching = false

  # Added by User for Devise
  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
  ## up to here

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  config.action_mailer.smtp_settings ||= {}
  config.action_mailer.smtp_settings[:domain] = "localhost"

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  ############ Custom settings ############

  # PaperTrail disabled for Test environment (for the sake of efficiency)
  config.after_initialize do
    PaperTrail.enabled = false

    #RoutingFilter.active = false  # Manual says put it in test_helper.rb
  end

  # Read in {#w3c_validate} in /test/test_helper.rb
  # If true (Def: false), the test ignores an error of
  # > An input element with a type attribute whose value is hidden must not have an autocomplete attribute whose value is on or off.
  # which is raised with the HTML generated by Rails 7 default `button_to`.
  # The error started on 2022-10-26 because of a change in the W3C validator
  #   https://github.com/validator/validator/pull/1458
  # where the change is valid in terms of the spec of the HTML form:
  #   https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#autofilling-form-controls:-the-autocomplete-attribute:autofill-anchor-mantle-2
  # See for the background:
  #  https://stackoverflow.com/questions/74256523/rails-button-to-fails-with-w3c-validator
  config.ignore_w3c_validate_hidden_autocomplete = true
end
