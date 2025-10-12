# -*- coding: utf-8 -*-

require "plain_text"
require "active_record/relation/query_methods"  # If this raise NameError, the timing to require this file must be wrong -- probably too early.  This file should be require-d at the end of app/models/application_record.rb after ApplicationRecord has been created.  See the comment in the file.

# See the comment lines (far) below for detail of this file and what this does.

# This file should not be read twice.
return if ActiveRecord::QueryMethods.const_defined?(:REVERSE_SQL_ORDER_ORIG_DEFINED)

qm_file_paths = $LOADED_FEATURES.grep(%r@/activerecord[^/]*/lib/active_record/relation/query_methods\.rb$@)
if qm_file_paths.size != 1
  if qm_file_paths.empty?
    msg = "(#{__FILE__}) /lib/active_record/relation/query_methods.rb does not exist! Strange."
    warn msg
    Rails.logger.warn msg
    return
  end
  msg = "(#{__FILE__}) Multiple files of /lib/active_record/relation/query_methods.rb are found! Strange. We check out #{qm_file_paths.first} Make sure to compare it with #{__FILE__}"
  warn msg
  Rails.logger.warn msg
  msg = nil
end

qm_file_path = qm_file_paths.first

# Original statements of reverse_sql_order as of (Rails) activerecord-7.0.4, which this patch assumes
assumed_statements_reverse_sql_order = <<'EOF'
      def reverse_sql_order(order_query)
        if order_query.empty?
          return [table[primary_key].desc] if primary_key
          raise IrreversibleOrderError,
            "Relation has no current order and table has no primary key to be used as default order"
        end

        order_query.flat_map do |o|
          case o
          when Arel::Attribute
            o.desc
          when Arel::Nodes::Ordering
            o.reverse
          when Arel::Nodes::NodeExpression
            o.desc
          when String
            if does_not_support_reverse?(o)
              raise IrreversibleOrderError, "Order #{o.inspect} cannot be reversed automatically"
            end
            o.split(",").map! do |s|
              s.strip!
              s.gsub!(/\sasc\Z/i, " DESC") || s.gsub!(/\sdesc\Z/i, " ASC") || (s << " DESC")
            end
          else
            o
          end
        end
      end
EOF

# Actual statements of reverse_sql_order in use now
actual_statements_reverse_sql_order =
  PlainText.head(
    PlainText.tail(
      File.read(qm_file_path),
      /^      def reverse_sql_order\(/
    ),
    /^      def does_not_support_reverse\?\(/,
    inclusive: false
  ).sub(/\n+\z/, "\n")

if assumed_statements_reverse_sql_order != actual_statements_reverse_sql_order
  msg = "(#{__FILE__}) Method reverse_sql_order.rb in #{qm_file_path} in use currently differs from the one (activerecord-7.0.4) that this patch assumes.  Make sure to compare it with #{__FILE__} and correct the patch to suit the original as soon as possible."
  warn msg
  Rails.logger.warn msg
end

module ActiveRecord
  module QueryMethods

    # Set a constant so that this file is never read again.
    REVERSE_SQL_ORDER_ORIG_DEFINED = true

    private

      # Patched version by Masa, based on /activerecord-7.0.4/lib/active_record/relation/query_methods.rb 
      #
      # The native Rails/ActiveRecord's +reverse_order+ raises IrreversibleOrderError
      # when it encounters almost any String +order+. This is a patch for the method
      # +reverse_sql_order+ in /activerecord-*/lib/active_record/relation/query_methods.rb
      # which is a private sub-method called from method +reverse_order+ so that
      # it can handle with the specifica case of order according to a given Array
      # of primary IDs.
      #
      # The method is basically copied from the original, but 2 lines are added,
      # along with a separate private method.
      #
      # == Background ==
      #
      # Datagrid Gem assumes the given +scope+ is reversible to enable the user to
      # sort according to the column. Therefore, it is necessary to modify this method
      # to make the (Datagrid) functionality available.
      #
      # @note
      #   Because the original method reverse_sql_order is a private method, you cannot make an alias or
      #   even make it public temporaliry (you cannot find it).
      #   So, reverse_sql_order is simply overwritten below without a backcup!
      #
      def reverse_sql_order(order_query)
        if order_query.empty?
          return [table[primary_key].desc] if primary_key
          raise IrreversibleOrderError,
            "Relation has no current order and table has no primary key to be used as default order"
        end

        order_query.flat_map do |o|
          case o
          when Arel::Attribute
            o.desc
          when Arel::Nodes::Ordering
            o.reverse
          when Arel::Nodes::NodeExpression
            o.desc
          when String
            trystr = reverse_sql_order_string_ids(o)
            next trystr if trystr 
            if does_not_support_reverse?(o)
              raise IrreversibleOrderError, "Order #{o.inspect} cannot be reversed automatically"
            end
            o.split(",").map! do |s|
              s.strip!
              s.gsub!(/\sasc\Z/i, " DESC") || s.gsub!(/\sdesc\Z/i, " ASC") || (s << " DESC")
            end
          else
            o
          end
        end
      end

      # Returns the reversed-order one if String-SQL for ORDER is just for IDs
      # else nil
      #
      # Specifically, this assumes the original Rails +order()+ statement is as follows:
      #   ids = [4, 1, 3, 2]  # Model is sorted according to the order of these IDs
      #   MyModel.order(Arel.sql("array_position(array#{ids}, id)"))
      #    # i.e., raw SQL: "array_position(array[4, 1, 3, 2], id)"
      #
      # @note It is case-insensitive and space-insensitive.
      #
      # @param order_str [String]
      # @return [String, NilClass] String if it is reversible else nil
      def reverse_sql_order_string_ids(order_str)
        retstr = order_str.strip.sub(/\b(array_position\s*\(\s*array\s*\[)\s*((?:\d+,\s*)*\s*\d*)\s*(\]\s*,\s*id\s*\))/i){s1=$1;s2=$3;sc=$2.split(/,\s*/).reverse.join(",");s1+sc+s2}
        (retstr == order_str) ? nil : retstr
      end
  end
end
