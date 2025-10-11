# coding: utf-8
require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module HaramiMusicI18n
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    #config.load_defaults 6.1
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    #config.autoload_lib(ignore: %w[assets tasks])  # commented out b/c lib is not eager loaded.

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    config.eager_load_paths << Rails.root.join("app/models/value_objects")

    ## I18n-related settings
    #
    # rails will fallback to en, no matter what is set as config.i18n.default_locale
    # If this was simply "true", the fallback is the default locale.
    # This could be a Hash, e.g., {'es' => 'en', 'fr' => 'en', 'de' => 'fr'}
    #
    # This usually depends on the environment and so is set in /config/environments/YOUR_ENVIRONMENT.rb
    #
    #config.i18n.fallbacks = [:en, :ja]

    # Without this, test/controllers/static_pages_controller_test.rb
    # might occasionally (though not always?) fail with
    #   Psych::DisallowedClass: Tried to load unspecified class: ActiveSupport::TimeWithZone
    # As of version 16 with Rails 8.0, tests fail unless specifyibg 3 classes in the Array below
    # (it is three likely becaseu this app does not use other data types monitored by PaperTrail?).
    # @see https://github.com/paper-trail-gem/paper_trail/blob/master/doc/pt_13_yaml_safe_load.md
    # @see https://stackoverflow.com/questions/72970170/upgrading-to-rails-6-1-6-1-causes-psychdisallowedclass-tried-to-load-unspecif
    config.active_record.yaml_column_permitted_classes = [
      ActiveSupport::TimeWithZone, ActiveSupport::TimeZone, Time #,
      # ActiveRecord::Type::Time::Value, BigDecimal, Date, Symbol
    ]
    #config.active_record.use_yaml_unsafe_load = true  # The last resort

    # default list for sanitizing (scrubbing) HTML. Used in sanitized_html_fragment in application_helper.rb
    config.default_html_sanitize_permit_list = %w(a sup sub em strong b i u del s ins ruby rt rp rb small wbr var kbd code samp def cite)

    # Year of the first (potential) Event. This is used as the lower threshold (plus 1)
    # for the year to be provided for the form in default and also as the default first year of 
    # EventGroup.
    yea = ((ye=ENV["MUSIC_I18N_DEF_FIRST_EVENT_YEAR"]).present? ? ye.to_i : 2019)
    config.music_i18n_def_first_event_year = ((yea > 0) ? yea : 2019)

    ## application-specific parameters
    #
    # Default Time Zone in setting a Date or Time.
    # Note that all Time values are recorded WITHOUT TIME ZONE in UT.
    # You should retrieve a time-like value in a model in either of:
    #   Time.at(MyModel.first.my_time, in: Rails.configuration.music_i18n_def_timezone_str)
    #   Time.at(MyModel.first.created_at.to_r, in: Rails.configuration.music_i18n_def_timezone_str)
    # which converts it into the application-specific time zone
    #  (The former may fail with:  can't convert ActiveSupport::TimeWithZone into an exact number (TypeError).)
    # If you want (though you should rarely need) to change just the time zone
    # without touching the other values in Time, consult
    #   https://stackoverflow.com/a/78053461/3577922
    config.music_i18n_def_timezone_str = (ENV["MUSIC_I18N_DEF_TIMEZONE_STR"] || "+09:00")

    # default country code
    config.primary_country = (ENV['MUSIC_I18N_DEFAULT_COUNTRY'] || "JPN")

    # default maximum number of rows for Table (to prevent a potential server crush)
    config.def_view_max_nrows = (ENV['DEF_VIEW_MAX_NROWS'].present? ? ENV['DEF_VIEW_MAX_NROWS'].to_i : 150)

    # default maximum number of Event rows per EventGroup for Table for Public
    config.max_events_per_group_public = 100

    # default maximum number of HaramiVid rows per Event for Table for Editors (to prevent a potential server crush)
    config.max_harami_vids_per_event_editor = 15

    # default maximum number of HaramiVid rows per Event for Table for Public (to prevent a potential server crush)
    config.max_harami_vids_per_event_public =  5

    # Do not change this (unless you search and change all of then consistently)
    config.primary_artist_titles = {
      ja: {
        title: 'ハラミちゃん',
        ruby:  'ハラミチャン',
        romaji: 'Haramichan',
        weight: 0,
        is_orig: true,
        langcode: "ja",
      }.with_indifferent_access,
      en: {
        title: 'HARAMIchan',
        alt_title: 'Harami-chan',
        weight: 10,
        is_orig: false,
        langcode: "en",
      }.with_indifferent_access,
    }.with_indifferent_access
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
require 'role_category_node'  # load class RoleCategoryNode < Tree::TreeNode
require 'local/tree/tree_node'  # modifies Tree::TreeNode#<=>
require "checked_disabled"    # A general class used for Form
#require "reverse_sql_order"   # A monkey patch to modify reverse_sql_order() in ActiveRecord::QueryMethods::WhereChain
require "time_with_error"  # TimeWithError: a subclass of Time
require "time_aux"  # Time-related auxiliary module TimeAux

