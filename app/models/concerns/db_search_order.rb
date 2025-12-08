module DbSearchOrder
  extend ActiveSupport::Concern

  # Step to sort the result of matching [Array<Symbol>]
  PSQL_MATCH_ORDER_STEPS = [:exact, :caseInsensitive, :spaceInsensitiveExact, :spaceInsensitivePartial]

  # dash/hyphen-like characters
  #
  # Unicode "Pd" is: '\u002D\u058A\u05BE\u2010\u2011\u2012\u2013\u2014\u2015\u2E3A\u2E3B\uFE58\uFE63\uFF0D'
  # cf. https://www.compart.com/en/unicode/category/Pd
  # However, Ruby's [\p{Dash}] may slightly differ as follows.
  # cf. https://stackoverflow.com/a/73562709/3577922
  # cf. https://qiita.com/YSRKEN/items/edb5bab23b7d92a3bf63
  PSQL_UNICODE_DASH = '\xAD\u002D\u058A\u05BE\u1400\u1806\u2010-\u2015\u2E17\u2E1A\u2E3A\u2E3B\u2E40\u301C\u3030\u30A0\uFE31\uFE32\uFE58\uFE63\uFF0D'
  PSQL_UNICODE_MIDDLE_DOT = '\u00B7\u2022\u0387\u2219\u22C5\u30FB\uFF65'

  PSQL_UNICODE_EQUAL = '\u003d\uFF1D'

  # Spaces plus middle-point characters like hyphens and equals.
  # Use in PostgreSQL regexp like "[#{PSQL_UNICODE_ALL_MIDDLE_PUNCT}]"
  PSQL_UNICODE_ALL_MIDDLE_PUNCT = '\s' + PSQL_UNICODE_DASH + PSQL_UNICODE_MIDDLE_DOT + PSQL_UNICODE_EQUAL

  module ClassMethods
    # Searches records by columns (title, alt_title, ruby, alt_romaji, etc) affinity, prioritizing matches.
    #
    # This categorizes the conditions and score them as follows in the case of searching for 3 +cols+
    # of +title+, +alt_title+, +romaji+ as an example:
    #
    # * Exact Match: title (Score 0) > alt_title (Score 1) > romaji (Score 2)
    # * Case-Insensitive Match: title (Score 3) > alt_title (Score 4) > romaji (Score 5)
    # * Space-Insensitive Exact Match: title (Score 6) > alt_title (Score 7) > romaji (Score 8)
    # * Space-Insensitive Partial Match: title (Score 9) > alt_title (Score 10) > romaji (Score 11)
    #
    # where "Space-Insensitive" means the search ignores any spaces and dash/hyphen/equal-like characters.
    #
    # Note that the preceding and trailing spaces are significant unless specified so
    # (i.e., +upto+ of +:spaceInsensitiveExact+ or +:spaceInsensitivePartial+) and that
    # most characters like ASCII "&" and the Zenkaku one are not aggressively collated.
    #
    # @example of the order_sql created
    #    Translation.search_by_affinity([:title, :alt_title, :ruby, :alt_ruby], "XXX", t_alias: "t")
    #      ## created order_sql:
    #      # CASE
    #      #   WHEN t.title = 'XXX' THEN 1
    #      #   WHEN t.alt_title = 'XXX' THEN 2
    #      #   WHEN t.ruby = 'XXX' THEN 3
    #      #   WHEN t.alt_ruby = 'XXX' THEN 4
    #      #   WHEN "t"."title" ILIKE 'XXX' THEN 5
    #      #   // ....
    #      #   WHEN REGEXP_REPLACE("t"."title"), '[\s\xAD\u002D\u058A\u...]', '', 'g') = 'XXX' THEN 9
    #      #   // ....
    #      #   WHEN REGEXP_REPLACE("t"."title"), '[\s\xAD\u002D\u058A\u...]', '', 'g') LIKE '%XXX%' THEN 13
    #      #   // ....
    #      #   WHEN REGEXP_REPLACE("t"."alt_ruby"), '[\s\xAD\u002D\u058A\u...]', '', 'g') LIKE '%XXX%' THEN 16
    #      #   -- Default/No Match (Lowest Priority)
    #      #   ELSE 17
    #      # END
    #
    # @param columns [String, Array<String, Symbol>] of the columns in the order of priority
    # @param raw_kwd [String] Keyword to search with
    # @param order_or_where: [Symbol] (mandatory) :order or :where or :both
    # @param order_by_created_at: [Boolean] Only relevant when +order_or_where+ is NOT +:where+.  If true (Def: false), the newest one comes first as the final condition for sorting/ordering.  Give false (Def) if you call this from a parent or grandparent.
    # @param t_alias: [String, NilClass] DB table alias for Translation table, if the given +rela+ uses it. Default is {Translation.table_name} (= "translations")
    # @param parent [Translation::ActiveRecord_Relation, NilClass] Base relation
    # @param upto: [Symbol, NilClass] Up to which step of {PSQL_MATCH_ORDER_STEPS} or nil (Default, meaning all steps)
    # @param upto: nil, debug_return_content_sql: false)
    def search_by_affinity(columns, raw_kwd, order_or_where:, order_by_created_at: false, t_alias: nil, parent: nil, upto: nil, debug_return_content_sql: false)
      raise ArgumentError, "order_or_where="+order_or_where.inspect if ![:order, :where, :both].include?(order_or_where)
      raise ArgumentError, [columns, raw_kwd].inspect if columns.blank? || raw_kwd.blank?
      columns = [columns].flatten.map(&:to_s)
      t_alias ||= self.table_name
      base_rela = (parent || self.all)
      index_upto = (upto ? PSQL_MATCH_ORDER_STEPS.find_index(upto) : PSQL_MATCH_ORDER_STEPS.size-1)
      raise ArgumentError, "upto is not one of PSQL_MATCH_ORDER_STEPS: "+upto.inspect if !index_upto  # if upto is not one of PSQL_MATCH_ORDER_STEPS

      ## Preparation: quote and, if needed, truncate the input keyword (Ruby)
      quoted_kwd = connection.quote(raw_kwd)

      if index_upto >= PSQL_MATCH_ORDER_STEPS.find_index(:caseInsensitive)
        quoted_kwd_like = sanitize_sql_like(quoted_kwd)

        if index_upto >= PSQL_MATCH_ORDER_STEPS.find_index(:spaceInsensitiveExact)
          truncated_kwd_base = raw_kwd.to_s.downcase.gsub(/[\s\p{Dash}]/u, "")  # space-eliminated and downcased
          quoted_truncated_kwd_base = connection.quote(truncated_kwd_base)
          truncated_kwd_like = sanitize_sql_like(truncated_kwd_base)

          # Helper for space/hyphen/equal removal for WHERE and ORDER clauses (relying on ILIKE).
          # NOTE(alternative, with "LIKE"): "REGEXP_REPLACE(LOWER(#{t_alias}.#{col}), '[#{PSQL_UNICODE_ALL_MIDDLE_PUNCT}]', '', 'g')"
          truncate_where_sql = ->(col) { "REGEXP_REPLACE(\"#{t_alias}\".\"#{col}\", '[#{PSQL_UNICODE_ALL_MIDDLE_PUNCT}]', '', 'g')" }
        end
      end

      # 2. Define the ORDER BY clause (the combined "n_col x 4_cases" point scoring mechanism)
      order_sql = "CASE\n"
      score = 0
      where_conditions = nil  # which will be set inside the iterator below.

      # --- Build the ORDER BY and WHERE conditions ---

      # Iteratively builds clauses for the four cases (the Array elements are for human readability only).
      PSQL_MATCH_ORDER_STEPS.each_with_index do |match_type, i_step|
        # Storing OR conditions for multiple columns; reset at every loop so that
        # only the ones for the last outer-loop (e.g., :caseInsensitive) remain.
        where_conditions = []

        columns.each do |col|
          score += 1

          # Determines the SQL expression based on the match type
          condition_sql =
            case match_type
            when :exact
              sprintf '"%s"."%s" = %s', t_alias, col, quoted_kwd
            when :caseInsensitive
              sprintf '"%s"."%s" ILIKE %s', t_alias, col, quoted_kwd_like  # ==: "LOWER(#{t_alias}.#{col}) = LOWER(#{quoted_kwd})"
            when :spaceInsensitiveExact
              sprintf("%s ILIKE   '%s'",   truncate_where_sql.call(col), truncated_kwd_like)
            when :spaceInsensitivePartial
              sprintf("%s ILIKE '%%%s%%'", truncate_where_sql.call(col), truncated_kwd_like)
            else
              raise "Should never happen. Contact the code developer. "+match_type.inspect
            end

          # Add to ORDER BY and WHERE
          order_sql += "  WHEN #{condition_sql} THEN #{score}\n"
          where_conditions << condition_sql
        end # columns.each do |col|

        break if  (i_step >= index_upto)
      end # PSQL_MATCH_ORDER_STEPS.each_with_index do |match_type, i_step|

      # ELSE clause for ORDER BY
      order_sql << "  -- Default/No-match (Lowest priority)\n  ELSE #{score+1}\nEND"

      # Compiles the WHERE clause with "OR"
      where_sql = where_conditions.join(" OR\n")

      ## returning DEBUG output
      if debug_return_content_sql
        return case order_or_where
               when :both
                 [order_sql, where_sql]
               when :order
                 order_sql
               when :where
                 where_sql
               else
                 raise
               end
      end

      ret = base_rela
      ret = ret.where(Arel.sql(where_sql)) if :order != order_or_where
      if :where != order_or_where
        ret = ret.order(Arel.sql(order_sql))
        ret = ret.order(Arel.sql("LENGTH(\"#{t_alias}\".\"#{columns.first.to_s}\") ASC"))
        ret = ret.order('"'+t_alias+'".created_at' => :desc) if order_by_created_at
      end
      ret
    end # def search_by_affinity()
  end # module ClassMethods
end # module DbSearchOrder
