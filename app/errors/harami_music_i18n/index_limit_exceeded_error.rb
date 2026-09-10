module HaramiMusicI18n
  #
  # @example
  #    raise HaramiMusicI18n::IndexLimitExceededError.new("Associated translation hit an index threshold.", self)
  #
  class IndexLimitExceededError < StandardError
    attr_reader :record
    attr_reader :original_message

    # @note
    #    You may retrieve the original error message with err.record.errors.full_messages
    #    where +err+ is the instance of this Exception.
    def initialize(message="Data exceeds PostgreSQL built-in index limits.", record=nil, original_message=nil)
      @record = record
      super(message)
    end
  end
end

