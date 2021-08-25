require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module HaramiMultilingual
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    ## I18n-related settings
    #
    # rails will fallback to en, no matter what is set as config.i18n.default_locale
    # If this was simply "true", the fallback is the default locale.
    # This could be a Hash, e.g., {'es' => 'en', 'fr' => 'en', 'de' => 'fr'}
    #
    # This usually depends on the environment and so is set in /config/environments/YOUR_ENVIRONMENT.rb
    #
    #config.i18n.fallbacks = [:en, :ja]
  end
end

### i18n settings, which may be instead written in:
# config/initializers/locale.rb

# Where the I18n library should search for translation files
#I18n.load_path += Dir[Rails.root.join('lib', 'locale', '*.{rb,yml}')]

# Permitted locales available for the application
I18n.available_locales = [:ja, :en, :fr]  # ko, zh, ...

# Set default locale to something other than :en
#I18n.default_locale = :pt

## Masa added
require "multi_translation_error"
require 'role_category_node'  # load class RoleCategoryNode < Tree::TreeNode

