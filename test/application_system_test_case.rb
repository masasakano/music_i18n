require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :chrome, screen_size: [1400, 1400]

  Capybara.configure do |config|
    # see https://rubydoc.info/github/jnicklas/capybara/master/Capybara#configure-class_method
    config.save_path = Rails.root.to_s + "/tmp/screenshots"  # Default is Dir.pwd - the directory where you run rails test
  end

  setup do
    # Capybara.default_max_wait_time = 5  # The default is 2 seconds
                                          # https://github.com/teamcapybara/capybara/blob/master/README.md
  end
end
