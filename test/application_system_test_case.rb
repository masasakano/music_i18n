# coding: utf-8
require "test_helper"

Dir[Rails.root.join("test", "support", "**", "*.rb")].each do |file|
  require file
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include SnapshotHelper

  Capybara.configure do |config|
    # see https://rubydoc.info/github/jnicklas/capybara/master/Capybara#configure-class_method
    config.save_path = Rails.root.to_s + "/tmp/screenshots"  # Default is Dir.pwd - the directory where you run rails test
  end

  if false
    # Default settings(?)
    driven_by :selenium, using: :chrome, screen_size: [1400, 1400]

  else
    ## Sets up a custom Chrome.
    driven_by :selenium_chrome_headless_no_prompts #, screen_size: [1920, 2800]  # screen-size defined below

    Capybara.register_driver :selenium_chrome_headless_no_prompts do |app|
      chrome_args = [
        "--no-sandbox",
        "--disable-gpu",
        "--window-size=1920,2800",
        "--force-device-scale-factor=0.5",  # Comment out this to display the Chrome screen
        "--headless",  # Comment out this to display the Chrome screen, together with commenting out force-device-scale-factor
        "--guest",  # Key to suppress the warning pop-up by Google Password Manager
      ]
      #chrome_args = %w[
      #  --guest
      #  --no-sandbox
      #  --disable-gpu
      #  --window-size=1920,1400
      #  --disable-features=TranslateUI
      #  --disable-save-password-bubble
      #  --disable-features=PasswordGeneration,AutofillServerCommunication
      #  --disable-features=TranslateUI
      #  --disable-features=OmniboxPasswordSuggestions
      #  --disable-features=PreloadMediaEngagementData
      #  --no-default-browser-check
      #]

      ## Define Preferences to set the default font size
      ## The value is specified in pixels (e.g., 10 for 10px)
      #prefs = {
      #  'webkit.webprefs.default_font_size' => 6,       # Regular text font size
      #  'webkit.webprefs.default_fixed_font_size' => 6,  # Monospace text font size
      #  'profile.default_content_settings.font_settings.minimum_font_size' => 6,
      #  'profile.default_content_settings.font_settings.default_font_size' => 6,
      #  'credentials_enable_service' => false,
      #  'profile.password_manager_enabled' => false,
      #  'safebrowsing.enabled' => false,
      #  'security.password_manager.enabled' => false,
      #  'safebrowsing.disable_auto_update' => true # Prevents checks from updating during the test
      #}

      options = Selenium::WebDriver::Chrome::Options.new

      # Apply all arguments
      chrome_args.each { |arg| options.add_argument(arg) }

      ## Apply all preferences
      #prefs.each { |key, value| options.add_preference(key, value) }
      #options.add_preference('profile.managed_popups_blocker_enabled', true)  # last resort to suppress security pop-ups (though it did not work)

      ## Optional: Force a temporary/clean user data directory
      #options.add_argument("--user-data-dir=#{Dir.mktmpdir}")

      Capybara::Selenium::Driver.new(
        app,
        browser: :chrome,
        options: options
      )
    end # Capybara.register_driver :selenium_chrome_headless_no_prompts do |app|
  end   # if false

  setup do
    # Capybara.default_max_wait_time = 5  # The default is 2 seconds
                                          # https://github.com/teamcapybara/capybara/blob/master/README.md
  end
end
