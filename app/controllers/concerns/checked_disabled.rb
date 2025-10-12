
# Class to give 2 attributes
class CheckedDisabled

  # Default (fallback) index to check
  DEFCHECK_INDEX = 0

  # Index to be "checked" for a set of radio buttons (or checkboxes)
  attr_reader :checked_index

  # The values of +model.attr+ or something specified by the user, maybe in initialization.
  attr_accessor :contents

  # If all the contents are equal, they are disabled.
  #
  # The first one with a non-nil element is checked. Else defcheck_index.
  # If all of them are the same, disabled is true.
  # In default, only one of them is non-nil, disabled is true.
  #
  # Used in /app/views/layouts/_form_merge.html.erb
  #
  # Note if arguments +disabled+ is true and +checked_index+ is significant, this class works just as a container.
  #
  # Note if blank?, it is regarded as being nil.
  #
  # == Algorithm
  #
  # If the model class has a method "index_boss" to determine the priority, it is consulted
  # *unless* the argument checked_index is non-nil.  For example, {Place.index_boss} determines
  # that if one of the Places is {Place#unkown} and the other is not, the latter is selected.
  #
  # @param models [Array<ActiveRecord>] can be nil only if disabled and checked_index are specified.
  # @param attr [Symbol] attribute method. if nil, models are directly used.
  # @param refute [Boolean] If true (Def: false), the return of :attr is reversed (it should be Boolean in this case).
  # @param defcheck_index [Integer] Default.
  # @param disable_if_nil [Boolean] If true (Def) and if there is no significant one, return disabled? == true
  # @param disabled [Boolean, NilClass] If non-nil, this value is used for {#disabled?}
  # @param checked_index [Integer, NilClass] if non-nil, this value is simply used for {#checked_index}
  #    Note that +@disabled+ will be (perhaps) set regardless of this value, unless the given +disabled+ is non-nil.
  #    For example, in the case where @disabled is set true and @checked_index is set 0 in Default,
  #    if checked_index=1 is given, the return has @disabled=true and @checked_index=1.
  # @param contents [Array<Object>] Basically, the values of +model.attr+ and retrieved with {#contents}.
  #    If non-nil elements are specified, it is not overwritten.
  # @return [Hash] :disabled? => Boolean, :checked_index => Index
  def initialize(models=nil, attr=nil, refute: false, defcheck_index: DEFCHECK_INDEX, disable_if_nil: true, disabled: nil, checked_index: nil, contents: [])
    defcheck_index = defcheck_index.to_i
    @disabled = disabled
    @checked_index = (checked_index.present? && checked_index.to_i)
    @contents = contents
    return if !@disabled.nil? && @checked_index  # Already set

    arres = (attr ? models.map{|em| em.send(attr)} : models.dup)
    arres.map!{|i| !i} if attr && refute
    arres.each_with_index do |ec, i|
      @contents[i] ||= ec
    end

    should_disabled = @disabled
    if @disabled.nil?
      @disabled = should_disabled = false
      if arres.uniq.size <= 1
        @disabled = should_disabled = true
      elsif arres.map{|i| i.blank? ? nil : i }.compact.size <= 1
        should_disabled = true
        @disabled = true if disable_if_nil
      end
    end

    ## return if checked_index  # given as an argument.
    @checked_index ||= (arres.find_index{|em| !em.blank?} || defcheck_index)

    return if (should_disabled && !checked_index) || !arres[@checked_index].class.respond_to?(:index_boss)

    ## The model class has a method "index_boss" to determine the priority.
    # The :index_boss method should return an index or nil if none of them have a priority.
    obj = arres[@checked_index].class.index_boss(arres, defcheck_index: defcheck_index)

    if obj.respond_to?(:checked_index)
      # Basically, if the object is this class's instance.
      @disabled      = obj.disabled?
      @checked_index = obj.checked_index if !checked_index  # If specified as an argument, it remains unchanged.
    else
      # It is either nil or Integer
      @checked_index = (obj || @checked_index) if !checked_index  # If specified as an argument, it remains unchanged.
    end
    @checked_index &&= @checked_index.to_i
  end

  # Whether the item in the form should be disabled.
  def disabled?
    @disabled
  end
end
