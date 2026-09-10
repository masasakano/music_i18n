# Module to make saving a too-long String indexed column gracefully fail
#
# In PostgreSQL, the hard limit for B-tree-indexed column is 8191 bytes,
# and the upper limit is usually 2704 bytes (though it dependds on the server configuration).
# The latter, the more strict limit, matters for users of this module (whereas the former
# also matters for the developers of THIS MODULE itself because the issued errors slightly differ).
#
# When Rails tries to save a record with an indexed (String) column with a size
# larger than this, PG::ProgramLimitExceeded is raised,
#
#    ActiveRecord::StatementInvalid (PG::ProgramLimitExceeded: ERROR: index row size 3008 exceeds btree version 4 maximum 2704 for index "index_translations_on_9_cols"
#
# and saving will fail abruptly, unlike graceful failing with failures in validation.
# The user wouldn't be able to tell what happens, let alone what actually caused the failure.
#
# This module provides a measure for it.  Include this module in your ActiveRecord model,
# which has one or more indexed columns, and then meeting +PG::ProgramLimitExceeded+ in any saving attempt
# (but +update_all+) of an ActiveRecord is caught and processed in the same way as the standard failure
# in saving, i.e., +record.errors+ is set with the error type +:index_limit_exceeded+ (defined as {SaveIndexGuard::ERROR_TYPE})
# and the most likely attribute name (e.g., :title), unless the saving method is with a bang(!)
# at the tail like +save!+, +create!+, +update!+, in which case an Exception (ActiveRecord::StatementInvalid)
# is raised.
#
# == Example
#
#    class User < ApplicationRecord
#      # To gracefully fail in saving a too-large String column
#      include SaveIndexGuard
#    end
#
#    user = User.new(bio: "Excessively long text for the indexed column [...]")
#    user.save  # => false
#    user.errors.any?  # => true
#    user.errors.where(:bio).first.type  # => :index_limit_exceeded
#    user.save!  # => ActiveRecord::RecordNotSaved  (NOT ActiveRecord::RecordInvalid b/c validation has succeeded)
#
# == Background
#
# Japanese characters usually take 3 bytes per character, so the upper limit is less than 1000 characters.
# In addition, 
#
# Importantly, the quoted upper-limits are those for a single *index* in DB, NOT necessarily
# for a single column.  If there is a combined unique constraint (hence a DB index) for 6 columns,
# the upper limits are applied to the total byte size of the 6 columns; so if all 6 columns are
# in an equal length, the upper limit per column will be about 450 bytes, or 150 Asian characters only.
#
# Another complication is that if a column of interest has a large byte-size, PostgreSQL
# applies native compression before comparing it with the above-mentioned upper limits (and before indexing).
# If a String is a highly repetitive one, the compression can be very effective.
#
# For these reasons, implementing an accurate Rails-level validation for the column length
# is very difficult and impractical.  Implementing a simple, obvious validation
# like a 2-letter constraint in Controllers would eliminate the need of including this module.
# However, you should give a serious consideration before posing a hard limit in U/I because
# there are almost always exceptions in the real-world cases...
#
# === Detailed background
#
# The former of the limits (8191 and 2704 bytes) is obtained with
#   block_size = ActiveRecord::Base.connection.execute("SHOW block_size;").first["block_size"].to_i  # => 8192
#
# and the latter is then caculated with:
#
#   usable_space = block_size - 24  # 8168
#   max_with_tuple_header = usable_space / 3  # 2722
#   max_index_size = (max_with_tuple_header - 12 - 6) & ~7  # 2704
#
# where (according to Gemini)
#
# 1. Postgres aligns index boundaries to 8 bytes, subtracting 12 bytes for standard tuple headers
# 2. plus 6 bytes maxalign rounding padding.
# 3. In Postgres 12+, an additional 8 bytes are deducted for B-Tree V4 posting lists.
#
module SaveIndexGuard
  extend ActiveSupport::Concern

  # Error type when an error is caught in this module
  ERROR_TYPE = :index_limit_exceeded

  # Using prepend ensures our rescue block wraps ActiveRecord's native saving pipeline
  included do
    prepend ClassMethods
  end

  module ClassMethods
    private

    # Extends the Rails core method to handle :save (and :save!), :create, and :updates in ActiveRecord
    def create_or_update(...)
      self.class.transaction(requires_new: true) do
        super(...)  # +(...)+ should be explicitly in place here, allegedly (the bare +super+ is less robust and may behave unexpectedly (likely with no errors raised) in some edge cases)
      end
    rescue ActiveRecord::StatementInvalid => er
      if er.cause.is_a?(PG::ProgramLimitExceeded) && er.message.include?("maximum")
        _handle_index_limit_error(er.message)
        false # .save / .update returns false natively in failure
      else
        raise
      end
    end
  end

  private

  def _handle_index_limit_error(error_message)
    # Case 1: Traditional index limit error (e.g., maximum 2704 for index "...")
    match = error_message.match(/for index "([^"]+)"/)

    columns = 
      if match && (index_name = match[1])
        _columns_for_index(index_name)
      else
        # Case 2: Maximum physical row/block size limit exceeded (e.g., maximum size is 8191)
        #  In this case, finds all indexed columns on the table b/c we don't have an index name
        self.class.connection.indexes(self.class.table_name).flat_map(&:columns).uniq
      end

    if columns.any?
      column_sizes = columns.each_with_object({}) do |column, hash|
        hash[column.to_sym] = self.read_attribute(column).to_s.bytesize
      end

      largest_column, largest_size = column_sizes.max_by { |_col, size| size }

      # Adds the custom :index_limit_exceeded type symbol for programmatic checking
      errors.add(
        largest_column, 
        ERROR_TYPE,
        message: "Too large size (currently #{largest_size} bytes) exceeds the DB limit",  # 2704 bytes for the B-tree index of PostgreSQL
      )
    else
      errors.add(:base, ERROR_TYPE, message: "Data size exceeds the DB hard limits.") # for B-tree index (8191 bytes) in PostgreSQL
    end
  end

  def _columns_for_index(index_name)
    index = self.class.connection.indexes(self.class.table_name).find { |i| i.name == index_name }
    return [] unless index
    Array(index.columns)
  end
end
