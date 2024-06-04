# -*- coding: utf-8 -*-

class Harami1129s::DownloadHarami1129 < ApplicationRecord
  # include ActiveModel::Model
  self.abstract_class = true  # instantiation would raise NotImplementedError

  extend  ModuleCommon  # get_pair_tags_from_a_css() etc
  #include ModuleCommon  # zenkaku_to_ascii etc

  # HTML format version in the Harami1129 server: %w(2022 2023)
  HARAMI1129_HTML_FMT = "2023"

  # Main selector (2022 version) to get a row in the downloaded HTML to give to Nokogiri::HTML(my_string).css(my_selector)
  CSS_TABLE_SELECTOR2022 = 'div.entry-content table tr'

  # Default column number for Harami1129 table
  DEF_HARAMI1129_TABLE_COLNOS =
    case HARAMI1129_HTML_FMT
    when "2022"
      {singer: 0, song: 1, release_date: 2, title_col: 3}
    else
      {singer: 0, song: 1, release_date: 2, memo: 3, title_col: 4}
    end
  DEF_HARAMI1129_TABLE_COLNOS.with_indifferent_access

  # Regexp to match a YouTube String
  # Note that /\A/ and /$/ are included!  You may need to delete them?
  RE_YOUTUBE = %r@\Ahttps?://(?:www.)?(?:youtu\.be|youtube.com)/([^?]+)(?:\?t=(\d+)s)?$@i

  # Class to hold 6 variables
  class Ret
    attr_accessor :last_err
    attr_accessor :msg
    attr_accessor :alert
    attr_accessor :num_errors
    attr_accessor :harami1129
    attr_accessor :harami1129s

    def initialize
      @last_err = nil
      @msg = []
      @alert = ""
      @num_errors = nil
      @harami1129 = nil
      @harami1129s = []
      super
    end
  end

  # Download Harami1129 from the Internet
  #
  # Returns self where 6 instance variables are set (to be used in the corresponding Controller).
  #
  # If failing completely like access failure, only @msg and @alert are non-nil.
  # If one or more of the entries failed to be inserted/updated to DB,
  # all four of them are significant.
  # In normal end, all of them but @last_err are significant.
  #
  # @param init_entry_fetch: [Integer, NilClass] 1 if nil.
  # @param max_entries_fetch: [Integer, NilClass] if nil, no limit.
  # @param html_str: [String, NilClass] Direct HTML String. If nil, read from the default URI.
  # @param debug: [Boolean]
  # @param kwds: [Hash] See #{Harami1129s::DownloadHarami1129#insert_one_db!}, or ultimately {ApplicationRecord#logger_after_create}
  # @return [Harami1129s::DownloadHarami1129::Ret] where 6 instance variables are set.
  def self.download_put_harami1129s(init_entry_fetch: 1, max_entries_fetch: nil, html_str: nil, debug: false, **kwds)
    ret = self::Ret.new

    init_entry_fetch = 1 if init_entry_fetch < 1
    if debug && !max_entries_fetch
      logger.warn "(#{__method__}) When params[:debug] is true, max_entries_fetch should not be nil. It is reset to 3."
      max_entries_fetch = 3
    end
    max_entries_fetch = max_entries_fetch.to_i if max_entries_fetch

    if debug #|| max_entries_fetch
      logger.info "(#{__method__}) [DEBUG-mode]: init_entry_fetch=#{init_entry_fetch.inspect}, max_entries_fetch=(#{max_entries_fetch})."
    end

# max_entries_fetch = 23 if !max_entries_fetch   # for DEBUG-ging

    page = _get_page_html(html_str, ret) # Nokogiri::HTML
    logger.debug "socket error or something: ret=#{page.inspect}" if debug && page.respond_to?(:harami1129s)
    return page if page.respond_to?(:harami1129s) # SocketError or something (here, "page" is Ret)

    # Nokogiri::HTML <tr>-s (in <table>)
    trs = _get_page_trs(page, ret)
    logger.debug "HTML format error or something: ret=#{trs.inspect}" if debug && trs.respond_to?(:harami1129s)
    return trs if trs.respond_to?(:harami1129s) # Possibly, the HTML format on the server has been altered.
    hscolnos = _hs_table_structure(trs) # =hash_column_numbers

    n_alltrs  = trs.size
    n_entries = n_alltrs - 1  # Except for a single header line
    if debug #|| max_entries_fetch
      logger.debug "[DEBUG-mode]: hash_column_numbers=#{hscolnos.inspect}"
      str_entry = ActionController::Base.helpers.pluralize([(max_entries_fetch || Float::INFINITY), n_alltrs].min, "entry", locale: :en)
      msg = "[DEBUG-mode](#{__method__}): processing #{str_entry} out of #{n_entries} entries, starting from #{init_entry_fetch.inspect}."
      logger.info msg
      ret.msg << msg
    end

    n_before = Harami1129.count
    n_success = 0
    i_sigificant = 0  # Ignores an empty row (or table header <th>) in the fetched table.
    trs.each_with_index do |ea_tr, i|
      row = ea_tr.css('td')
      next if !row || row.size < 1

      i_sigificant += 1
      next if init_entry_fetch > i_sigificant

      break if max_entries_fetch && (i_sigificant - init_entry_fetch + 1 > max_entries_fetch)

      if debug && i%100 == 0
        logger.debug "[DEBUG-mode](#{__method__}): #{i}-th (#{i_sigificant}th significant row, out of #{n_entries}) remote-Harami1129 table row being processed..."
      end

      # Hash containing "song", "release_date" etc.
      entry = _get_row_entry(row, ret, i_sigificant: i_sigificant, hscolnos: hscolnos, tr_this: ea_tr, debug: debug)
      next if entry.respond_to?(:harami1129s) # containing no song.

      h1129 = insert_one_db!(entry, ea_tr, ret, debug: debug, **kwds)
      next if !h1129  # Failure in saving
      ret.harami1129 = h1129
      ret.harami1129s.push h1129

      n_success += 1
    end  # trs.each_with_index do |ea_tr, i|

    n_after = Harami1129.count
    #n_entries = trs.size
    ret.num_errors = n_entries - n_success
    armsg = ["Harami1129 table updated with the data from #{Harami1129sController::URI_ROOT};"]
    # armsg.push view_context.pluralize(n_success, "entry") # How to use pluralize in Controller
    armsg.push ActionController::Base.helpers.pluralize(n_success, "entry", locale: :en)
    armsg.push sprintf("were inserted out of %d received. The number of the DB entries", n_entries)
    if n_before == n_after
      armsg.push sprintf("unchanged at %d (new entries: 0).", n_before)
    else
      armsg.push sprintf("increased from %d to %d (new entries: %d).", n_before, n_after, n_after-n_before)
    end

    ret.msg << armsg.join(" ")
    logger.info armsg.join(" ")
    ret
  end

  # Creates a Nokogiri object to process.
  #
  # @param html_str [String, NilClass] Direct HTML String. If nil, read from the default URI.
  # @param ret [Harami1129s::DownloadHarami1129::Ret] to return in case of error
  # @return [Nokogiri, Harami1129s::DownloadHarami1129::Ret] If network-unreachable, returns Ret.
  def self._get_page_html(html_str, ret)
    begin
      if html_str
        logger.info "(#{__method__}) Opening String "+((html_str.size < 200) ? html_str.inspect : html_str[0..190].inspect.sub(/"$/, '...[snip]"'))
        return Nokogiri::HTML(html_str)
      else
        if Harami1129sController::URI2FETCH.blank?
          msg = "Harami1129sController::URI2FETCH (environmental variable URI2FETCH) is not defined. Contact the code developper."
          logger.error msg
          raise msg
        end
        logger.info "(#{__method__}) Opening "+Harami1129sController::URI2FETCH

        #return Nokogiri::HTML(URI.open(Harami1129sController::URI2FETCH))
        ## Memo: The above would cause an encoding error in some cases. Below is a fix. cf: https://stackoverflow.com/a/4702055/3577922
        html = URI.open(Harami1129sController::URI2FETCH)
        doc = Nokogiri::HTML(html.read)
        doc.encoding = 'utf-8'
        return doc
      end
    rescue Exception => err
      # Various errors, including SocketError, possible
      ret.alert << "Failed to fetch the data over the Internet"
      if err.is_a? SocketError
        ret.alert << " due to SocketError"
      end
      ret.alert << ". Try again later."
      logger.error ret.alert+"  #{err.class.name}: "+err.message

      ret
    end
  end
  private_class_method :_get_page_html


  # Get a Table-Trs Nokogiri object.
  #
  # Returns tr-s for the (first) Table tag whose <th> contains "アーティスト" & "リリース"
  #
  # @param ret [Harami1129s::DownloadHarami1129::Ret] to return in case of error
  # @return [Nokogiri, Harami1129s::DownloadHarami1129::Ret] If something goes wrong, returns Ret.
  def self._get_page_trs(page, ret)
    # # Old format till 2022
    # trs = page.css(CSS_TABLE_SELECTOR2022)
    # if !trs.respond_to? :each_with_index
    #   ret.alert << "HTML rendering failed completely, perhaps because of a null response from the remote server. Try again later."
    #   return ret
    # end
    # return trs if trs.size > 0

    # Generalized algorithm
    page.css("table").each do |table|
      ths = table.css("tr")[0].css("th")
      next if ths.blank?
      if ["アーティスト", "リリース"].all?{|ek| ths.any?{|et| /#{ek}/ =~ et.text}}
        trs = table.css("tr")
        if !trs.respond_to? :each_with_index
          ret.alert << "HTML rendering failed completely, perhaps because of a null response from the remote server. Try again later."
          return ret
        end
        return trs
      end
    end

    ret.alert << "Failed to find the main table tag, possibly because either a null response is returned from the remote server (try again later) or the HTML format on the server has been altered (contact the code developer)."
    return ret
  end
  private_class_method :_get_page_trs

  # Returns Hash to point the column number for each column
  #
  # The returned hash "hs" is like +hs["song"] == 1+ meaning +trs[x][1]+ is a song.
  #
  # @param trs [Nokogiri] <tr>-s
  # @return [Hash]
  def self._hs_table_structure(trs)
    ths = trs[0].css("th")
    if ths.blank?
      logger.warn "(#{File.basename __FILE__}) The first row of the Harmai1129 table is NOT <th>. Format=#{HARAMI1129_HTML_FMT} is assumed. Check it."
      return DEF_HARAMI1129_TABLE_COLNOS
    end

    reths = {}
    ths.each_with_index do |ea_th, ind|
      case ea_th.text.strip
      when /アーティスト/
        reths[:singer] = ind
      when /リリース|日/
        reths[:release_date] = ind
      when /リンク|タイトル|題/
        reths[:title_col] = ind
      when /メモ|注/
        reths[:memo] = ind
      when /^曲|曲名/
        reths[:song] = ind
      else
        logger.warn "WARNING: (#{File.basename __FILE__}:#{__method__}) Unrecognized table column header (#{ea_th}) in the Harmai1129 table."
      end
    end

    %i(singer song release_date title_col).each do |ek|
      if !reths.key? ek
        logger.warn "WARNING: (#{File.basename __FILE__}:#{__method__}) Table column header for (#{ek.to_s}) fails to be identified. Use the default (=#{DEF_HARAMI1129_TABLE_COLNOS[ek]})."
        reths[ek] = DEF_HARAMI1129_TABLE_COLNOS[ek]
      end
    end

    ar = reths.values.sort
    if ar.size != ar.uniq.size
      logger.warn "WARNING: (#{File.basename __FILE__}:#{__method__}) Identified Table column header is strange: for (#{reths.inspect}). Use the default instead (#{DEF_HARAMI1129_TABLE_COLNOS.inspect})."
      reths = DEF_HARAMI1129_TABLE_COLNOS
    end

    reths
  end
  private_class_method :_hs_table_structure

  # Get "entry" Hash for a Table row
  #
  # Keys(indifferent) in returned Hash: id_remote singer song release_date title link_time link_root
  #
  # @param tds [Nokogiri] Array-ish of <td>-s
  # @param ret [Harami1129s::DownloadHarami1129::Ret] to return in case of error
  # @param i_sigificant [Integer]
  # @param hscolnos [Hash] Symbol (or String) to point to an index in +tds+
  # @param tr_this [Nokogiri] for Error message just in case.
  # @return [Hash, Harami1129s::DownloadHarami1129::Ret] If contains no song, returns Ret.
  def self._get_row_entry(tds, ret, i_sigificant: nil, hscolnos: nil, tr_this: nil, debug: false)
    entry = { id_remote: i_sigificant } # %i(singer song release_date title link_time link_root)

    # First 3 columns
    %i(singer song release_date).each do |ek|
      entry[ek] = tds[hscolnos[ek]].text
      entry[ek].strip! if entry[ek]
    end

    ## First 3 columns
    #tds[0..2].zip(%i(singer song release_date)).each do |ean|
    #  entry[ean[1]] = ean[0].text
    #  entry[ean[1]].strip! if entry[ean[1]]
    #end

    if entry[:song].blank?
      msg = "An entry (#{2.ordinalize} tds) fetched from #{Harami1129sController::URI2FETCH.split('/')[2]} contains no song: "+tr_this.text
      logger.info msg
      ret.msg << "INFO: "+msg+"\n" if debug
      return ret
    end

    # Release date conversion from String form like "2019/9/22"
    ar_date_str = entry[:release_date].split(%r@[/\s\-]@)
    if ar_date_str.size == 3
      entry[:release_date] = Date.new(*(ar_date_str.map(&:to_i)))
    end

    # The 4th(2022)/5th(2023) column:
    # URI (and start-time) and Video title
    uri_nk = tds[hscolnos[:title_col]].css('a')
    entry[:title] = (uri_nk.text rescue '').strip.sub(/\s*\([\d:]+～?\)$/, '')
    href = (uri_nk[0].attributes['href'].value rescue '').strip  # or .text
    m = RE_YOUTUBE.match href
    entry[:link_time] = (m ? m[2].to_i : nil)
    entry[:link_root] = (m ? m[1] : href)
    entry

    ## The 4th column:
    ## URI (and start-time) and Video title
    #uri_nk = tds[-1].css('a')
    #entry[:title] = (uri_nk.text rescue '').strip.sub(/\s*\([\d:]+～?\)$/, '')
    #href = (uri_nk[0].attributes['href'].value rescue '').strip  # or .text
    #m = RE_YOUTUBE.match href
    #entry[:link_time] = (m ? m[2].to_i : nil)
    #entry[:link_root] = (m ? m[1] : href)
    #entry
  end
  private_class_method :_get_row_entry

  # Insert one entry to DB.  Exception if fails.
  #
  # @param entry [Hash] The data to insert
  # @param trow [Nokogiri] HTML table row object. Used for Error message.
  # @param retu [Harami1129::DownloadHarami1129] To set its "last_err" attribute if need be.
  # @param extra_str: [String] see {ApplicationController#logger_after_create}
  # @param execute_class: [Class, String] usually a subclass of {ApplicationController} (though the default here is inevitably ActiveRecord...)
  # @param method_txt: [String] pass +__message__+
  # @param user: [User] if specified and if a new record is saved, {ApplicationRecord#logger_after_create} is called.
  # @return [ActiveRecord, Exception] nil if failed. Otherwise {Harami1129} instance (you need to "reload")
  def self.insert_one_db!(entry, trow, retu, extra_str: "", execute_class: self, method_txt: "create", user: nil, debug: false)

    begin
      harami = Harami1129.insert_a_downloaded!(extra_str: extra_str, execute_class: execute_class, method_txt: method_txt, user: user, **entry)
      #harami.save!
    rescue ActiveRecord::RecordInvalid => err
      #new_or_upd = (harami.id ? "create a" : "update an existing (ID=#{harami.id})")
      msg = sprintf "Failed to update/create a record (%s) from harami1129 on DB with a message: %s", trow.text, err.message
      logger.warn msg
      retu.last_err = msg
      return nil
    end

    harami
  end


  # Returns a HTML table that can be read by {DownloadHarami1129.download_put_harami1129s}
  #
  # @example raw input 1
  #    "嵐","Happiness","2020/1/2","【嵐メドレー】神曲7曲繋げて弾いたらファンの方が…!!【都庁ピアノ】(0:3:3～) https://youtu.be/EjG9phmijIg?t=183s"
  #
  # @example raw input 2
  #    あいみょん,マリーゴールド,2019/7/20,【即興ピアノ】ハラミのピアノ即興生ライブ❗️vol.1【ピアノ】(1:20:16～) https://youtu.be/N9YpRzfjCW4?t=4816s
  #
  # @example raw input 3
  #    あいみょん,マリーゴールド,2019/7/20,追記だよ,【即興ピアノ】ハラミのピアノ即興生ライブ❗️vol.1【ピアノ】(1:20:16～) https://youtu.be/N9YpRzfjCW4?t=4816s
  #
  # @example output 2022
  #    <div class="entry-content">
  #    <table>
  #      <tr><th>アーティスト</th><th>曲名</th><th>リリース日</th><th>リンク</th></tr>
  #      <tr><td>あいみょん</td><td>マリーゴールド</td><td>2019/7/20</td><td><font color="red">Link→</font><a rel="noopener" target="_blank" href="https://youtu.be/N9YpRzfjCW4?t=4816s">【即興ピアノ】ハラミのピアノ即興生ライブ❗️vol.1【ピアノ】(1:20:16～)</a><br/>https://youtu.be/N9YpRzfjCW4?t=4816s</td></tr></table></div>
  #
  # @example output 2023
  #    <table>
  #      <tr><th>アーティスト</th><th>曲名</th><th>リリース日</th><th>メモ</th><th>リンク</th></tr>
  #      <tr><td>あいみょん</td><td>マリーゴールド</td><td>2019/7/20</td><td>追記だよ</td><td><a href=\"https://youtu.be/N9YpRzfjCW4?t=4816s\" target=\"_blank\">【即興ピアノ】ハラミのピアノ即興生ライブ❗️vol.1【ピアノ】(1:20:16～)</a></td></tr></table>
  #
  # @param css_csv [String] in CSV format
  # @param html_fmt: [String] HTML format version in the server: "2022" or others ("2023")
  # @return [String] of a HTML table
  def self.generate_sample_html_table(css_csv, html_fmt: HARAMI1129_HTML_FMT)
    html_fmt = html_fmt.to_s.strip
    contents = []
    contents << "<th>アーティスト</th><th>曲名</th><th>リリース日</th>" +
      case html_fmt
      when "2022"
        ""
      else
        "<th>メモ</th>"
      end + "<th>リンク</th>"

    i_col = DEF_HARAMI1129_TABLE_COLNOS[:title_col] # Column number for title+link

    regex = remove_az_from_regexp RE_YOUTUBE
    CSV.parse(css_csv).each do |ea_row|
      mat = regex.match ea_row[i_col]
      case html_fmt
      when "2022"
        ea_row[i_col] = ea_row[i_col].sub(/\b(Link\s*→)/, '<font color="red">\1</font>')
        ea_row[i_col] = ea_row[i_col].sub(/(\A|\/font>)([^<>]+) (#{Regexp.quote mat[0]})/, sprintf(%Q@%s<a rel="noopener" target="_blank" href="%s">%s</a><br/>%s@, '\1', mat[0], '\2', '\3'))
      else
        ea_row[i_col] = ea_row[i_col].sub(/(\A|\/font>)([^<>]+) (#{Regexp.quote mat[0]})/, sprintf(%Q@%s<a href="%s" target="_blank">%s</a>@, '\1', mat[0], '\2'))
      end
      contents << '<td>'+ea_row.join('</td><td>')+'</td>' if !ea_row.empty?
    end

    tag_i, tag_f =
           case html_fmt
           when "2022"
             get_pair_tags_from_css CSS_TABLE_SELECTOR2022
           else
             get_pair_tags_from_css "table tr"
           end

    tag_i + contents.join("</tr>\n<tr>") + tag_f
  end

  ## private class methods

    # Get all the <tr> of the main table
    #
    # From mid-2022, there is an advert <table> at the top. Nothing at the bottom.
    #
    # @param page [Nokogiri]
    # @return [Nokogiri]
    def self.get_trs(page)
      # trs = page.css(CSS_TABLE_SELECTOR)  # up to mid(?)-2022
      trs = page.css("table")[-1].css("tr") # from mid-2022
    end
    private_class_method :get_trs

end

