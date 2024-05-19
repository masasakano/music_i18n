# -*- coding: utf-8 -*-

# Common module to overwrite "inspect"
#
module ModuleModifyInspectPrintReference
  #def self.included(base)
  #  base.extend(ClassMethods)
  #end
  extend ActiveSupport::Concern  # In Rails, the 3 lines above can be replaced with this.

  module ClassMethods
    # Default maximum length of String given for inspect.
    # If the String is longer than this, it is truncated 5 characters
    # shorter than the original appended with "[...]"
    DEF_MAX_INSPECT_INFORMATION_STRING_LENGTH = 23

    # Redefine (overwrite) inspect to display belongs_to association information
    #
    # For all belongs_to references, human-readable information is added to the output of inspect,
    # except for those that have methods of none of "mname", "title_or_alt", "title",
    # "name", and "machine_name" (in this order of priority), unless a block
    # is given to handle them.  This means that user-related information in inspect
    # is not modified in default (because User has only the "display_name" method).
    #
    # When cols_yield supplied and block_given?, the parent ActiveRecord for the column (+*_id+)
    # is passed to yield, which should return String that is to be appended immediately
    # after Integer-pID in the inspect output.  If the record is nil, the block is not called.
    # Note that the block must take care of everything, including the prefix and suffix parentheses and
    # a potentially null title value (the ActiveRecord is guaranteed to exist unless yield_nil=true
    # is specified, but its "title" may not).
    #
    # The default language is used for the returned title, so most Artist and Music are in Japanese
    # (if an English-translated titles for Music was displayed in English, it could be cryptic!).
    #
    # An example output of inspect is like
    #
    #   => #<ArtistMusicPlay id: 4, event_item_id: 20(MayJ&HARAMIchan_Event_<_Street_playing),
    #      artist_id: 1227(May J.), music_id: 2244(Sweetest Crime (fe[...]), play_role_id: 2(singer),
    #      cover_ratio: nil, contribution: 0.5nil, note: nil, created_at: "2024-...[snipped]>
    #
    # where +*_id+ is followed by a title enclosed with a pair of parentheses.  In this case,
    # the long title of +music_id+ is truncated automatically, whereas that of +event_item_id+
    # is long as it is because the caller class specifies so, supplying a block.
    #
    # @example the most simple case
    #   class ChannelOnwer
    #     alias_method :inspect_orig, :inspect if ! self.method_defined?(:inspect_orig) # Preferred to  alias :text_new :to_s
    #     include ModuleModifyInspectPrintReference
    #     redefine_inspect
    #   end
    #
    # @example an especially complicated case with a block supplied
    #   class MyClass
    #     alias_method :inspect_orig, :inspect if ! self.method_defined?(:inspect_orig) # Preferred to  alias :text_new :to_s
    #     include ModuleModifyInspectPrintReference
    #     redefine_inspect(cols_yield: %w(my_col1 my_col2), yield_nil: true){ |record, colname, self_record|
    #       # returns diplayed String-s for either of the two columns
    #       break " <It really is nil>," if !record  # a silly demonstration for the use of "yield_nil=true"
    #       case colname
    #       when "my_col1_id"  # exact column name in DB
    #         "("+record.my_title_name.sub(/\A(.{17})......+/, '\1[...]')+")"
    #       when "my_col2_id"
    #         s = self_record.inspect_place_helper(record) # defined in module_common.rb (ModuleCommon methods can be called from self_record)
    #         "(#{s ? s : ''})"  # even the longest title can be displayed as it is.
    #       end
    #     }
    #   end
    #
    # @param cols_yield: [Array<Symbol, String>] when block_given, processing of these columns are delegated to yield
    # @param yield_nil: [Boolean] If true (Def: false), the value for cols_yield is passed to yield even if it is nil.
    # @param debug: [Boolean] If true (Def: false), it raises an Exception when the supplied block raises one.
    # @yield With [record, column_name_str, self_record] given, it should return String to display, where column_name is like "sex_id"
    def redefine_inspect(cols_yield: [], yield_nil: false, debug: false)
      cols_yield = cols_yield.map(&:to_s).map{|i| i.sub(/(_id)?$/, "_id")}
      define_method(:inspect) do 
        foreign_keys = self.class.reflect_on_all_associations(:belongs_to).map(&:foreign_key)  # e.g., ["sex_id", "create_user_id"]
        return(super()) if foreign_keys.all?{|ecol| !send(ecol)}

        hsprm = foreign_keys.map{|ecol|
          next nil if !respond_to?(ecol[0..-4])  # no method "foo_baa" defined for "foo_baa_id" (unlikely case, but playing safe!)
          obj = send(ecol[0..-4])
          if cols_yield.include?(ecol) && block_given? && (obj || yield_nil)
            value = yield(obj, ecol, self)
          elsif !obj
            next [ecol, ""]
          else
            lcode = ([Artist, Music, Channel, ChannelOwner].include?(obj.class) ? "ja" : "en")
            value = 
              if obj.respond_to? :mname
                obj.mname
              elsif obj.respond_to? :title_or_alt
                obj.title_or_alt(str_fallback: "")
              elsif %i(title name machine_name).find{|em| obj.respond_to? em}
                obj.send(em)
              else
                ""  # not handled in this routine, and so the inspect output is unmodified.
              end

            value =
              if value.present?
                "("+value.sub(/\A(.{#{DEF_MAX_INSPECT_INFORMATION_STRING_LENGTH-5}})......+/, '\1[...]')+")"
              else
                ""
              end
          end
          [ecol, value]
        }.compact.to_h.with_indifferent_access

        ret = super()  # This may call BaseWithTranslation#inspect (as opposed to Object#inspect)
        # NOTE: here, "()" is mandatory. Otherwise, raises:  RuntimeError: implicit argument passing of super from method defined by define_method() is not supported. Specify all arguments explicitly.

        hsprm.each_pair do |ecol, ev|  # ecol is like "sex_id"
          ret = ret.sub(/, #{ecol}: \d+/, '\0'+ev)
        end
        ret
      rescue
        raise if debug
        # This method itself should never raise an Exception.  However, the supplied block may.
        # "inspect" should never fail in any case.
        super()
      end # define_method(:inspect) do 
    end # def redefine_inspect(cols_yield: [])
  end
end

