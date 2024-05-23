module MusicsHelper

  # @return [Array[String,Engage]] maybe hyperlink (if permitted)
  def engage_title_link(music, artist)
    ## construct a Hash (key of year (9999 for nil)) of Arrays of Hashes
    hsyear = {}  #
    artist.engage_how_list(music).each do |ea_hs|  # [Engage,Title,Year,Contribution]
      if hsyear.keys.include?(yr=(ea_hs[:year] || 9999))
        hsyear[yr] << ea_hs
      else
        hsyear[yr] = [ea_hs]
      end
    end

    return [] if hsyear.empty?

    can_read = can?(:read, hsyear.first[1].first[:engage])  # If one can read one Engage, they should be allowed to read any Engage.
      # n.b., Hash#first gives a pair of Array(key, value)

    years = hsyear.keys.sort
    retstr = years.map{ |eyr|
      hsyear[eyr].map{ |ehs|
        if can_read
          link_to ehs[:title], ehs[:engage]
        else
          ERB::Util.html_escape(ehs[:title]) 
        end
      }.join("/")+"("+((9999 == eyr) ? t('musics.show.year_unknown') : eyr.to_s)+")"
    }.join(t(:comma)).html_safe

    [retstr, hsyear.first[1].first[:engage]]
  end
end
