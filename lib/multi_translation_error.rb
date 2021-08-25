module MultiTranslationError
  class AmbiguousError < StandardError; end
  class InsufficientInformationError < StandardError; end
  class UnavailableLocaleError < StandardError; end
end

