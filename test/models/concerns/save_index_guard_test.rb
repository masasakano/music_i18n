require "test_helper"
require "securerandom"
require_relative "../../support/save_index_guard_test_helper"

class SaveIndexGuardTest < ActiveSupport::TestCase
  setup do
    # The temporary table must be created dynamically (otherwise, it may be dropped during multiple concurrent tests)
    create_dummy_indexed_records_table_if_needed  # defined in save_index_guard_test_helper

    # Generates incompressible string payloads that comfortably exceed 2704 and 8192 bytes, respectively
    @nbytes = [3500, 9000]
    @massive_payloads = @nbytes.map{SecureRandom.alphanumeric(_1)}
    @safe_payload    = "Valid Title"
  end

  def self.after_run
    super if defined?(super)
    drop_dummy_indexed_records_table_if_exists  # defined in save_index_guard_test_helper
  end

  teardown do
    Rails.cache.clear
  end
  # add to here
  # ---------------------------------------------

  test "should save successfully under normal conditions" do
    record = DummyIndexedRecord.new(single_title: @safe_payload)

    assert record.save, "Record should save when under index thresholds"
    assert_empty record.errors
  end

  test "should catch index violation on creation and identify single column culprit" do
    @massive_payloads.each_with_index do |payload, i|
      record = DummyIndexedRecord.new(single_title: payload)

      refute record.save, "Should return false gracefully instead of raising PG::ProgramLimitExceeded"

      # Assert specific error message attributes and assignments
      assert_includes record.errors.attribute_names, :single_title
      error = record.errors.first

      assert_equal :single_title, error.attribute
      assert_equal :index_limit_exceeded, error.type
      assert_match(/#{@nbytes[i]} bytes.+exceeds the DB limit/, error.message)

      refute record.save(validate: true), "Should return false gracefully instead of raising PG::ProgramLimitExceeded"
      assert_equal 1, record.errors.where(:single_title, SaveIndexGuard::ERROR_TYPE).size, [SaveIndexGuard::ERROR_TYPE, record.errors.first.inspect]
    end
  end

  test "should catch index violation during an update operation" do
    record = DummyIndexedRecord.create!(single_title: @safe_payload)

    @massive_payloads.each do |payload|
      refute record.update(single_title: payload), "Update should gracefully fail on overflow"
      assert_equal :index_limit_exceeded, record.errors.first.type
    end
  end

  test "should set the single largest column in a multi-column compound index" do
    @massive_payloads.each_with_index do |payload, i|
      record = DummyIndexedRecord.new(
        compound_one: "Small text",
        compound_two: payload,   # This field is the culprit breaking the index
        compound_three: "Medium length text data"
      )

      refute record.save, "Compound overflow should be intercepted"

      # The suite must isolate ONLY the largest column out of the 3 fields
      assert_equal 1, record.errors.size, "Only the primary culprit column should receive an error flag"

      error = record.errors.first
      assert_equal :compound_two, error.attribute, "Failed to isolate the largest column in the index group"
      assert_equal :index_limit_exceeded, error.type
      assert_match(/currently #{@nbytes[i]} bytes/, error.message)
    end
  end

  test "should continue raising unrelated database standard execution errors" do
    # Verify that we aren't accidentally swallowing other real DB exceptions (e.g., bad SQL syntax)
    assert_raises(ActiveRecord::StatementInvalid) do
      DummyIndexedRecord.connection.execute("SELECT breaking_database_intentionally FROM non_existent_table;")
    end
  end
end
