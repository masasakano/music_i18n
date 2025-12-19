module DbSearchOrder
  extend ActiveSupport::Concern

  # Step to sort the result of matching [Array<Symbol>]
  # See also {Translation::MATCH_METHODS} which also defines :exact_absolute,
  # :exact_ilike (same as :case_insensitive), :optional_article_like, 
  # :include, :include_ilike
  PSQL_MATCH_ORDER_STEPS = [:exact, :case_insensitive, :optional_article_ilike, :space_insensitive_exact, :space_insensitive_forward, :space_insensitive_partial]

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
    # Find all records by columns (title, alt_title, ruby, alt_romaji, etc) affinity, prioritizing matches.
    #
    # This categorizes the conditions and score them as follows in the case of searching for 3 +cols+
    # of +title+, +alt_title+, +romaji+ as an example:
    #
    # * Exact Match: title (Score 1) > alt_title (Score 2) > romaji (Score 3)
    # * Case-Insensitive Match: title (Score 4) > alt_title (Score 5) > romaji (Score 6)
    # * Case-Insensitive Definite-article-insensitive Match: title (Score 7) > alt_title (Score 8) > romaji (Score 9)
    # * Space-Insensitive Exact Match: title (Score 10) > alt_title (Score 11) > romaji (Score 12)
    # * Space-Insensitive Forward Match: title (Score 13) > alt_title (Score 14) > romaji (Score 15)
    # * Space-Insensitive Partial Match: title (Score 16) > alt_title (Score 17) > romaji (Score 18)
    # * Other (Score 19; though this should never happen, because WHERE condition should have filtered out them, unless +order_or_where: :order+ and inconsistent +parent+ is specified)
    #
    # where "Space-Insensitive" means the search ignores any spaces and dash/hyphen/equal-like characters.
    #
    # Note that the preceding and trailing spaces are significant unless specified so
    # (i.e., +upto+ of +:space_insensitive_exact+ or +:space_insensitive_partial+) and that
    # most characters like ASCII "&" and the Zenkaku one are not aggressively collated.
    #
    # In the same category, the shorter ones come first.
    #
    # See {Translation.build_sql_match_one} and {Translation.tuple_collate_equal} (the latter for collation)
    #
    # @example of the order_sql created
    #    Translation.find_all_by_affinity([:title, :alt_title, :ruby, :alt_ruby], "XXX", t_alias: "t")
    #      ## created order_sql:
    #      # CASE
    #      #   WHEN t.title = 'XXX' THEN 1
    #      #   WHEN t.alt_title = 'XXX' THEN 2
    #      #   WHEN t.ruby = 'XXX' THEN 3
    #      #   WHEN t.alt_ruby = 'XXX' THEN 4
    #      #   WHEN "t"."title" ILIKE 'XXX' THEN 5
    #      #   // ....
    #      #   WHEN REGEXP_REPLACE("t"."title"), '\, (the|le|...)$', '', 'i') = 'XXX' THEN 9
    #      #   // ....
    #      #   WHEN REGEXP_REPLACE(REGEXP_REPLACE("t".title, ...), '[\s\xAD\u002D\u058A\u...]', '', 'g') = 'XXX' THEN 13
    #      #   // ....
    #      #   WHEN REGEXP_REPLACE(REGEXP_REPLACE("t".title, ...), '[\s\xAD\u002D\u058A\u...]', '', 'g') ILIKE 'XXX%' THEN 17
    #      #   // ....
    #      #   WHEN REGEXP_REPLACE(REGEXP_REPLACE("t".title, ...), '[\s\xAD\u002D\u058A\u...]', '', 'g') ILIKE '%XXX%' THEN 21
    #      #   // ....
    #      #   WHEN REGEXP_REPLACE(REGEXP_REPLACE("t".alt_ruby, ...), '[\s\xAD\u002D\u058A\u...]', '', 'g') ILIKE '%XXX%' THEN 24
    #      #   -- Default/No Match (Lowest Priority)
    #      #   ELSE 25
    #      # END
    #
    # @param columns [String, Array<String, Symbol>] of the columns in the order of priority
    # @param raw_kwd [String] Keyword to search with
    # @param order_or_where: [Symbol] (mandatory) :order or :where or :both
    # @param order_by_created_at: [Boolean] Only relevant when +order_or_where+ is NOT +:where+.  If true (Def: false), the newest Translation comes first as the final condition for sorting/ordering, or else in a crude alphabetical order of +:title+ (regardless of whether +:title+ is significant or not).
    # @param t_alias: [String, NilClass] DB table alias for Translation table, if the given +rela+ uses it. Default is {Translation.table_name} (= "translations")
    # @param parent [Translation::ActiveRecord_Relation, NilClass] Base relation
    # @param upto: [Symbol, NilClass] Up to which step of +order_steps+ or nil, which is Default and means all steps.  See {PSQL_MATCH_ORDER_STEPS} for the step names.
    # @param order_steps: [Array<Symbol>] Steps (Def: {PSQL_MATCH_ORDER_STEPS}).
    # @param collate_to: [String, NilClass] Def (nil) is taken from {ApplicationRecord.utf8collation}
    # @param debug_return_content_sql: [Boolean] If true (Def: false), this returns either a SQL String for the core part (either :order or :where) or its Array (if +upto+ is :both)
    # @return [ActiveRecord::Relation]
    def find_all_by_affinity(columns, raw_kwd, order_or_where:, order_by_created_at: false, t_alias: nil, parent: nil, upto: nil, order_steps: PSQL_MATCH_ORDER_STEPS, collate_to: ApplicationRecord.utf8collation, debug_return_content_sql: false)
      raise ArgumentError, "order_or_where="+order_or_where.inspect if ![:order, :where, :both].include?(order_or_where)
      raise ArgumentError, [columns, raw_kwd].inspect if columns.blank? || raw_kwd.blank?
      columns = [columns].flatten.map(&:to_s)
      t_alias ||= self.table_name
      base_rela = (parent || self.all)
      index_upto = (upto ? order_steps.find_index(upto.to_sym) : order_steps.size-1)
      raise ArgumentError, "upto is not one of order_steps: "+upto.inspect if !index_upto  # if upto is not one of order_steps

      ## Preparation of modified search-word: quoted and, if needed, truncated ones (processed by Ruby)
      kwds = _kwds_for_affinity_search(raw_kwd, order_steps, index_upto)

      ## helper method (implicitly using the argument t_alias)
      #truncate_where_sql = ->(col) { "REGEXP_REPLACE(#{psql_definite_article_stripped(col, t_alias: t_alias)}, '[#{PSQL_UNICODE_ALL_MIDDLE_PUNCT}]', '', 'g')" }
      truncate_where_sql = ->(col) { sprintf("REGEXP_REPLACE(%s, '[%s]', '', 'g')", psql_definite_article_stripped(col, t_alias: t_alias), PSQL_UNICODE_ALL_MIDDLE_PUNCT) }

      # Defines the ORDER BY clause (the combined "n_col x 4_cases" point scoring mechanism)
      order_sql = "CASE\n"
      score = 0
      where_conditions = nil  # which will be set inside the iterator below.

      # --- Build the ORDER BY and WHERE conditions ---

      # Iteratively builds clauses for the four cases (the Array elements are for human readability only).
      order_steps.each_with_index do |match_type, i_step|
        # Storing OR conditions for multiple columns; reset at every loop so that
        # only the ones for the last outer-loop (e.g., :case_insensitive) remain.
        where_conditions = []

        columns.each do |col|
          score += 1

          # Determines the SQL expression based on the match type
          three_sqls =
            case match_type
            when :exact_absolute
              [sprintf('"%s"."%s"', t_alias, col), "=", kwds[:quoted_raw]]
            when :exact  # The definite article moved to the tail.
              [sprintf('"%s"."%s"', t_alias, col), "=", kwds[:quoted]]
            when :case_insensitive, :exact_ilike
              [sprintf('"%s"."%s"',t_alias, col), "ILIKE", kwds[:quoted_like]]  # ==: "LOWER(#{t_alias}.#{col}) = LOWER(#{kwds[:quoted]})"
            when :optional_article_ilike, :optional_article
              like = ((:optional_article_ilike == match_type) ? "ILIKE" : "LIKE")
              [psql_definite_article_stripped(col, t_alias: t_alias), like, kwds[:quoted_no_article_like]] # defined in module_common.rb
            when :space_insensitive_exact  # regardless of the definite article, case-insensitive
              [truncate_where_sql.call(col), "ILIKE",           kwds[:quoted_truncated_like]]
            when :space_insensitive_forward
              [truncate_where_sql.call(col), "ILIKE",           kwds[:quoted_truncated_like]+" || '%'"]
            when :space_insensitive_partial
              [truncate_where_sql.call(col), "ILIKE", "'%' || "+kwds[:quoted_truncated_like]+" || '%'"]
            else
              # cannot handle :include, :include_ilike unlike {Translation.build_sql_match_one}
              raise "Should never happen. Contact the code developer. "+match_type.inspect
            end

          condition_sql = collated_condition_sql(three_sqls)

          # Add to ORDER BY and WHERE
          order_sql += "  WHEN #{condition_sql} THEN #{score}\n"
          where_conditions << condition_sql
        end # columns.each do |col|

        break if  (i_step >= index_upto)
      end # order_steps.each_with_index do |match_type, i_step|

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
        min_len = (kwds[:truncated_base] || kwds[:no_article] || raw_kwd.strip).size
        ret = sorted_by_min_valid_length_title_or_alt(ret, min_len, t_alias: t_alias)
        ret =
          if order_by_created_at
            ret.order('"'+t_alias+'".created_at' => :desc)
          else
            ret.order('"'+t_alias+'".title')
          end
      end
      ret
    end # def find_all_by_affinity()

    # Internal routine to prepare a set of "normalized" search keywords
    #
    # @param raw_kwd [String] Keyword to search with
    # @param order_steps: [Array<Symbol>] Steps (Def: {PSQL_MATCH_ORDER_STEPS}).
    # @param index_upto: [Index] upto index (to process) in +order_steps+
    # @return [Hash] .with_indifferent_access
    def _kwds_for_affinity_search(raw_kwd, order_steps, index_upto)
      kwds = {}.with_indifferent_access
      kwds[:raw] = raw_kwd.dup
      kwds[:raw_article_tail] = definite_article_to_tail(raw_kwd)  # defined in module_common.rb

      ## Preparation: quote and, if needed, truncate the input keyword (Ruby)
      kwds[:quoted_raw] = connection.quote(raw_kwd)
      kwds[:quoted] = connection.quote(kwds[:raw_article_tail])

      if (ind=order_steps.find_index(:case_insensitive)) && index_upto >= ind
        # kwds[:quoted_raw_like] = sanitize_sql_like(kwds[:quoted_raw])
        kwds[:quoted_like] = sanitize_sql_like(kwds[:quoted])

        if (ind=order_steps.find_index(:optional_article_ilike)) && index_upto >= ind
          kwds[:no_article] = definite_article_stripped(raw_kwd.to_s.downcase).strip  # downcased, definitely-article-stripped, space-stripped at head & tail
          kwds[:quoted_no_article_like] = connection.quote(sanitize_sql_like(kwds[:no_article]))

          if (ind=order_steps.find_index(:space_insensitive_exact)) && index_upto >= ind
            kwds[:truncated_base] = kwds[:no_article].gsub(/[\s\p{Dash}]/u, "")  # definitely-article-stripped, space-hyphen-stripped, and downcased
            # kwds[:quoted_truncated_base] = connection.quote(kwds[:truncated_base])
            kwds[:truncated_like] = sanitize_sql_like(kwds[:truncated_base])
            kwds[:quoted_truncated_like] = connection.quote(sanitize_sql_like(kwds[:truncated_base]))

            # Helper to return the left side for removing space/hyphen/equal signs and a definite article (ia any) for WHERE and ORDER clauses (for ILIKE).
            # NOTE(alternatively, with "LIKE" (if ignoring handling of a definite article)): "REGEXP_REPLACE(LOWER(#{t_alias}.#{col}), '[#{PSQL_UNICODE_ALL_MIDDLE_PUNCT}]', '', 'g')"

          end
        end
      end
      kwds
    end
    private :_kwds_for_affinity_search

    # Returns a PostgreSQL conditional statement with COLLATE if specified.
    #
    # @example
    #    Translation.collated_condition_sql("title", "ILIKE", "'abc'")
    #     # => "title COLLATE \"und-x-icu\" ILIKE 'abc'"
    #
    # @param *three_prms [Array<String, Array<String>>] String-Array or tuple of up to size 3 of SQL. The first one must be the left side of the SQL. Usually "Left-side", Operator, Right-side.
    # @param collate_to: [String] collation. Default collation is "und-x-icu" (more general than "C.UTF-8" (BSD) or "C.utf8" (Linux))
    # @return [String] SQL to feed to WHERE
    def collated_condition_sql(*three_prms, collate_to: ApplicationRecord.utf8collation)
      three_prms = [three_prms].flatten
      three_prms[1] ||= ""
      lside = three_prms[0] + (collate_to.blank? ? "" : sprintf(' COLLATE "%s"', collate_to.to_s.strip))
      ([lside] + three_prms[1..-1]).join(" ").strip
    end


    # Finds the smallest number of the most likely matches by iteratively
    # checking the strictest affinity level first.
    #
    # The order of checking is like, with regard to {PSQL_MATCH_ORDER_STEPS},
    #
    # 1. The least significant index, treated as negative (either -1 or as converted from +upto+ if specified)
    # 2. The most significant index: 0
    # 3. The second least significant index, "(1) - 1"
    # 4. The second most significant index: 1
    # 5. and so on.
    #
    # @param columns [String, Array<String, Symbol>] of the columns in the order of priority
    # @param raw_kwd [String] Keyword to search with
    # @param order_by_created_at: [Boolean] If true (Def: false), the newest one comes first as the final condition for sorting/ordering.
    # @param t_alias: [String, NilClass] DB table alias for the table.
    # @param parent [ActiveRecord_Relation, NilClass] Base relation
    # @param upto: [Symbol, NilClass] Up to which step of {PSQL_MATCH_ORDER_STEPS} to attepmt (when no matches are found) or nil (Default, meaning all steps)
    # @param order_steps: [Array<Symbol>] Steps (Def: {PSQL_MATCH_ORDER_STEPS}).
    # @return [ActiveRecord::Relation]
    def find_all_best_matches(columns, raw_kwd, t_alias: nil, parent: nil, upto: nil, order_steps: PSQL_MATCH_ORDER_STEPS, **opts)
      t_alias ||= self.table_name
      index_upto = (upto ? order_steps.find_index(upto.to_sym) : order_steps.size-1)
      raise ArgumentError, "upto is not one of order_steps: "+upto.inspect if !index_upto  # if upto is not one of order_steps
      order_steps_now = order_steps[0..index_upto]

      n_steps = index_upto + 1
      i_begin = (upto ? order_steps_now.find_index(upto.to_sym) : n_steps-1)  # positive index
      n_steps_mod = i_begin + 1  # if upto==::case_insensitive, yielding i_begin==1, n_steps_mod==2, while n_steps==4
      i_now = index_negative_array(i_begin, n_steps)  # negative index
      last_relas = {where: (parent || self.all), both: nil, ids: nil, tra_ids: nil}.with_indifferent_access
      curr_relas = {where: nil,                  both: nil, ids: nil, tra_ids: nil}.with_indifferent_access

      def get_hs_where_ids(relas, t_alias)
        hsmap = {ids: :id, tra_ids: sql_tbl_col_str(t_alias, :id).to_sym}
        [:ids, :tra_ids].map{|k| (ar=relas[k]) ? [hsmap[k], ar] : nil}.compact.to_h
      end

      100.times.each do  # 100 as a conservative safety net.  This should not loop more than the size of +order_steps_now+ (Def: PSQL_MATCH_ORDER_STEPS)
        # Get the relation using only the WHERE clause up to the current strictness level.
        # This determines the *set* of matches at this level of strictness.
        %i(where both).each do |ek|
          curr_relas[ek] = find_all_by_affinity(columns, raw_kwd, order_or_where: ek, upto: order_steps_now[i_now], t_alias: t_alias, parent: last_relas[:where], **opts)
        end

        return curr_relas[:both] if (1 == n_steps_mod)

        i_next = index_next_bsearch(i_now, n_steps, n_trimmed: n_steps_mod)  # defined in ModuleCommon

        curr_relas[:ids]     = curr_relas[:where].ids.uniq
        cur_siz = curr_relas[:ids].size
        curr_relas[:tra_ids] = curr_relas[:where].pluck(sql_tbl_col_str(t_alias, :id)).uniq  # defined in ModuleCommon

        if (0 == cur_siz && i_begin == index_positive_array(i_now, n_steps)) ||  # if no records are found at the first step; defined in ModuleCommon
           (1 == cur_siz) ||  # if narrowed down to 1 record
           (0 < cur_siz && (!i_next || 0 <= i_now)) # if multiple AND (last-step or index is non-negative (i.e., will not be narrowed down further))
          # Returning the currently obtained Relation
          return curr_relas[:both].where(get_hs_where_ids(last_relas, t_alias))
        elsif (0 == cur_siz) && (!i_next || i_now < 0)
          # Returning the Relation obtained in the last (<-if i_now is positive) or second-last (<-if negative) step.
          # If getting NONE yet if this is the last step, or if the previous iteration at a negative index (which is either the last or second-last) must have found *multiple* candidates
          return last_relas[:both].where(get_hs_where_ids(last_relas, t_alias))
        else  # [implicitly] i_next is guaranteed to be truthy
          if (0 == cur_siz && i_now >= 0)
            i_now = i_next
            next
          elsif (1 < cur_siz && i_now.negative?)
            last_relas.merge!(curr_relas)
            i_now = i_next
            next
          else
            raise "Should never come here... Contact the code developer."
          end
        end # if (1 == cur_siz) || (0 < cur_siz && 0 <= i_now) || (0 == cur_siz && i_begin == index_positive_array(i_now, n_steps))
      end # 100.times.each do
      raise "Should never come here after loop... Contact the code developer."
    end # def find_all_best_matches()

    # Sort {Translation} in the ascending order of the length of either +title+ or +alt_title+
    #
    # For sorting,
    #
    # 1. Either of the columns that is shorter than the given +min_len+ is ignored,
    # 2. The shorter of the two is used for comparison.
    #
    # Note that you might think condition 1 may be unnecessary because such too-short rows should
    # have been filtered out.  However, (1) some +:alt_title+ may be much shorter than +:title+
    # that has matched or vice versa, (2) +order_or_where+ in +find_all_by_affinity+ may be :order,
    # in which case such too-short rows may remain.
    #
    # See also {Translation.arel_order_by_min_title_length} and its scope +:order_by_min_title_length+
    #
    # @param rela [ActiveRecord::Relation] The Relation of Translation records (or a relation joined to translations).
    # @param min_len [Integer] The minimum length required for a title/alt_title to be considered for sorting (word without the definite article or spaces).
    # @param t_alias: [String, NilClass] DB table alias for the table.
    # @return [ActiveRecord::Relation] The ordered Relation.
    def sorted_by_min_valid_length_title_or_alt(rela, min_len, t_alias: nil)
      min_len_safe = min_len.to_i  # Ensure min_len is an integer

      # Finds the shorter of title and alt_title, providing longer than min_len, using LEAST().
      # PostgreSQL LEAST() function ignores NULL values when comparing, which comes last in default in PostgreSQL.
      # NOTE: -- Effective length for 'title': returns NULL if too short, otherwise returns length
      sort_sql = <<-SQL.squish
        LEAST(
          (CASE WHEN LENGTH("#{t_alias}".title)     < #{min_len_safe} THEN NULL ELSE LENGTH("#{t_alias}".title)     END),
          (CASE WHEN LENGTH("#{t_alias}".alt_title) < #{min_len_safe} THEN NULL ELSE LENGTH("#{t_alias}".alt_title) END)
        )
      SQL

      rela.order(Arel.sql("#{sort_sql} ASC"))
    end # def sorted_by_min_valid_length_title_or_alt(rela, min_len, t_alias: nil)
    private :sorted_by_min_valid_length_title_or_alt
  end # module ClassMethods
end # module DbSearchOrder
