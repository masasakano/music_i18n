# -*- coding: utf-8 -*-

class Harami1129s::DownloadHarami1129 < ApplicationRecord
  # include ActiveModel::Model
  self.abstract_class = true  # instantiation would raise NotImplementedError

  extend  ModuleCommon  # get_pair_tags_from_a_css() etc
  #include ModuleCommon  # zenkaku_to_ascii etc

  # Main selector to get a row in the downloaded HTML
  # to give to Nokogiri::HTML(my_string).css(my_selector)
  CSS_TABLE_SELECTOR = 'div.entry-content table tr'

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
  # @param max_entries_fetch: [Integer, NilClass] if nil, no limit.
  # @param html_str: [String, NilClass] Direct HTML String. If nil, read from the default URI.
  # @param debug: [Boolean]
  # @return [Harami1129s::DownloadHarami1129::Ret] where 6 instance variables are set.
  def self.download_put_harami1129s(max_entries_fetch: nil, html_str: nil, debug: false)
    ret = self::Ret.new

    if debug && !max_entries_fetch
      logger.warn "(#{__method__}) When params[:debug] is true, max_entries_fetch should not be nil. It is reset to 3."
      max_entries_fetch = 3
    end
    max_entries_fetch = max_entries_fetch.to_i if max_entries_fetch

    if debug #|| max_entries_fetch
      logger.info "(#{__method__}) [DEBUG-mode]: max_entries_fetch=(#{max_entries_fetch})."
    end

# max_entries_fetch = 23 if !max_entries_fetch   # for DEBUG-ging

    begin
      if html_str
        logger.info "(#{__method__}) Opening String "+((html_str.size < 200) ? html_str.inspect : html_str[0..190].inspect.sub(/"$/, '...[snip]"'))
        page = Nokogiri::HTML(html_str)
      else
        if Harami1129sController::URI2FETCH.blank?
          msg = "Harami1129sController::URI2FETCH (environmental variable URI2FETCH) is not defined. Contact the code developper."
          logger.error msg
          raise msg
        end
        logger.info "(#{__method__}) Opening "+Harami1129sController::URI2FETCH
        page = Nokogiri::HTML(URI.open(Harami1129sController::URI2FETCH))
      end
    rescue Exception => err
      # Various errors, including SocketError, possible
      ret.alert << "Failed to fetch the data over the Internet"
      if err.is_a? SocketError
        ret.alert << " due to SocketError"
      end
      ret.alert << ". Try again later."
      logger.error ret.alert+"  #{err.class.name}: "+err.message

      return ret
    end

    # tbody = page.css('div.entry-content table tbody')  # Does not work...
    trs = page.css(CSS_TABLE_SELECTOR)
    if !trs.respond_to? :each_with_index
      ret.alert << "HTML rendering failed completely, perhaps because of a null response from the remote server. Try again later."
      return ret
    end

    n_alltrs  = trs.size
    n_entries = n_alltrs - 1  # Except for a single header line
    if debug #|| max_entries_fetch
      str_entry = ActionController::Base.helpers.pluralize([(max_entries_fetch || Float::INFINITY), n_alltrs].min, "entry", locale: :en)
      msg = "[DEBUG-mode](#{__method__}): processing #{str_entry} out of #{n_entries} entries."
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
      break if max_entries_fetch && i_sigificant > max_entries_fetch

      if debug && i%100 == 0
        logger.debug "[DEBUG-mode](#{__method__}): #{i}-th (#{i_sigificant}th significant row, out of #{n_entries}) remote-Harami1129 table row being processed..."
      end
      entry = { id_remote: i_sigificant } # %i(singer song release_date title link_time link_root)

      # First 3 columns
      row[0..2].zip(%i(singer song release_date)).each do |ean|
        entry[ean[1]] = ean[0].text
        entry[ean[1]].strip! if entry[ean[1]]
      end

      if entry[:song].blank?
        msg = "An entry (#{i.ordinalize} row) fetched from #{Harami1129sController::URI2FETCH.split('/')[2]} contains no song: "+ea_tr.text
        logger.info msg
        ret.msg << "INFO: "+msg+"\n" if debug
        next
      end

      # Release date conversion from String form like "2019/9/22"
      ar_date_str = entry[:release_date].split(%r@[/\s\-]@)
      if ar_date_str.size == 3
        entry[:release_date] = Date.new(*(ar_date_str.map(&:to_i)))
      end

      # The 4th column:
      # URI (and start-time) and Video title
      uri_nk = row[-1].css('a')
      entry[:title] = (uri_nk.text rescue '').strip.sub(/\s*\([\d:]+～?\)$/, '')
      href = (uri_nk[0].attributes['href'].value rescue '').strip  # or .text
      m = RE_YOUTUBE.match href
      entry[:link_time] = (m ? m[2].to_i : nil)
      entry[:link_root] = (m ? m[1] : href)

      h1129 = insert_one_db!(entry, ea_tr, ret, debug: debug)
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


  # Insert one entry to DB.  Exception if fails.
  #
  # @param entry [Hash] The data to insert
  # @param trow [Nokogiri] HTML table row object. Used for Error message.
  # @param retu [Harami1129::DownloadHarami1129] To set its "last_err" attribute if need be.
  # @return [ActiveRecord, Exception] nil if failed. Otherwise {Harami1129} instance (you need to "reload")
  def self.insert_one_db!(entry, trow, retu, debug: false)

    begin
      harami = Harami1129.insert_a_downloaded!(**entry)
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
  #    "嵐","Happiness","2020/1/2","Link→【嵐メドレー】神曲7曲繋げて弾いたらファンの方が…!!【都庁ピアノ】(0:3:3～) https://youtu.be/EjG9phmijIg?t=183s"
  #
  # @example raw input 2
  #    あいみょん,マリーゴールド,2019/7/20,Link→【即興ピアノ】ハラミのピアノ即興生ライブ❗️vol.1【ピアノ】(1:20:16～) https://youtu.be/N9YpRzfjCW4?t=4816s
  #
  # @example output
  #    <tr><td>あいみょん</td><td>マリーゴールド</td><td>2019/7/20</td><td><font color="red">Link→</font><a rel="noopener" target="_blank" href="https://youtu.be/N9YpRzfjCW4?t=4816s">【即興ピアノ】ハラミのピアノ即興生ライブ❗️vol.1【ピアノ】(1:20:16～)</a><br/>https://youtu.be/N9YpRzfjCW4?t=4816s</td></tr>
  #
  # @param css_csv [String] in CSV format
  # @return [String] of a HTML table
  def self.generate_sample_html_table(css_csv)
    tag_i, tag_f = get_pair_tags_from_css CSS_TABLE_SELECTOR
    contents = []
    regex = remove_az_from_regexp RE_YOUTUBE
    CSV.parse(css_csv).each do |ea_row|
      ea_row[3] = ea_row[3].sub(/\b(Link\s*→)/, '<font color="red">\1</font>')
      mat = regex.match ea_row[3]
      ea_row[3] = ea_row[3].sub(/(\A|\/font>)([^<>]+) (#{Regexp.quote mat[0]})/, sprintf('%s<a rel="noopener" target="_blank" href="%s">%s</a><br/>%s', '\1', mat[0], '\2', '\3'))
      contents << '<td>'+ea_row.join('</td><td>')+'</td>' if !ea_row.empty?
    end
    tag_i + contents.join("</tr>\n<tr>") + tag_f
  end

end

