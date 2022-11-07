# coding: utf-8

class Artists::Merges::ArtistWithIdsController < BaseMerges::BaseWithIdsController
  # This constant should be defined in each sub-class of BaseMergesController
  # to indicate the mandatory parameter name for +params+
  MODEL_SYM = :artist

  def index
    super
  end

  private

end
