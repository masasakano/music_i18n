# coding: utf-8

class Musics::Merges::MusicWithIdsController < BaseMerges::BaseWithIdsController
  # This constant should be defined in each sub-class of BaseMergesController
  # to indicate the mandatory parameter name for +params+
  MODEL_SYM = :music

  def index
    super
  end

  private

end
