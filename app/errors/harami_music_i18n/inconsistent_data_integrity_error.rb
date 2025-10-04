module HaramiMusicI18n
  class InconsistentDataIntegrityError < StandardError  # HaramiMusicI18n::InconsistentDataIntegrityError
    ## Error of inconsistency in basic data integrity, such as, Country.unknown is undefined and returns nil.
    ## This error should be never raised in normal operations.
    ## However, in large-scale DB migrations, this may be raised. For example, the wikipedia-link migrations assumes SiteCategory.default is already defined. However, seeding is required to load SiteCategory.default (note that for a completely fresh DB migrations from scratch, this would not be a problem because there would be no data loaded to +HaramiVid#wiki_ja+ etc, so no data would be migrated).
  end
end
