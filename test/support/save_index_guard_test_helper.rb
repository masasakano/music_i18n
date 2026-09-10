# Creates a table used in SaveIndexGuardTest in /test/models/concerns/save_index_guard_test.rb
#
# The temporary table must be created dynamically (otherwise, it may be dropped during multiple concurrent tests)
def create_dummy_indexed_records_table_if_needed
  # Guard clause: If the table is already established on the connection, skip recreation
  return if ActiveRecord::Base.connection.table_exists?(:dummy_indexed_records)

  # Creates a temporary table inside the test database namespace
  ActiveRecord::Schema.define do
    suppress_messages do
      create_table :dummy_indexed_records, force: true do |t|
        t.string :single_title
        t.string :compound_one
        t.string :compound_two
        t.string :compound_three
      end

      # Sets up our target structural indices
      add_index :dummy_indexed_records, :single_title
      add_index :dummy_indexed_records, [:compound_one, :compound_two, :compound_three], name: 'idx_dummy_compound'
    end
  end
end

# Drop the temporary table at the end of each test sets (otherwise this would interfere with test/models/fixture_test.rb )
def drop_dummy_indexed_records_table_if_exists
  return unless ActiveRecord::Base.connection.table_exists?(:dummy_indexed_records)

  ActiveRecord::Schema.define do
    suppress_messages do
      drop_table :dummy_indexed_records, if_exists: true
    end
  end

  # Clears ActiveRecord's schema cache so that subsequent tests 
  # don't consider that the model definition is still linked to a physical table.
  ActiveRecord::Base.connection.schema_cache.clear!
end

# Define a pure dummy class incorporating the mixin
class DummyIndexedRecord < ActiveRecord::Base
  include SaveIndexGuard
end
