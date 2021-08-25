# coding: utf-8

include StaticPagesHelper

# == Schema Information
#
# Table name: static_pages
#
#  id                       :bigint           not null, primary key
#  content                  :text
#  langcode                 :string           not null
#  mname(machine name)      :string           not null
#  note(Remark for editors) :text
#  summary                  :text
#  title                    :string           not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  page_format_id           :bigint           not null
#
# Indexes
#
#  index_static_pages_on_langcode_and_mname  (langcode,mname) UNIQUE
#  index_static_pages_on_langcode_and_title  (langcode,title) UNIQUE
#  index_static_pages_on_page_format_id      (page_format_id)
#
# Foreign Keys
#
#  fk_rails_...  (page_format_id => page_formats.id) ON DELETE => restrict
#
class StaticPage < ApplicationRecord
  has_paper_trail(
    meta: {
      commit_message: :commit_message
    }
  )

  attr_accessor :commit_message

  belongs_to :page_format

  validates_presence_of	[:langcode, :mname, :title]
  validates :mname, uniqueness: { scope: :langcode }, allow_nil: false
  validates :title, uniqueness: { scope: :langcode }, allow_nil: false

  MD_EXTENSIONS = {
    no_intra_emphasis: true,
    tables: true,
    fenced_code_blocks: true,
    autolink: true,
    strikethrough: true,
    space_after_headers: true,
    superscript: true,
  }

  # Returns the model based on mname (and locale)
  #
  # @return [StaticPage, NilClass]
  def self.find_by_mname(mname, locale=I18n.locale)
    where(mname: mname).order(Arel.sql(sprintf("CASE WHEN langcode = '%s' THEN 0 ELSE 1 END, langcode", (locale || 'en')))).first
  end

  # Load an external file to create! a new StaticPage
  #
  # The base filename is interpreted as {StaticPage#mname}.
  #
  # The model is save! (meaning it might raise an Exception).
  #
  # @param langcode [String] mandatory. e.g., "en"
  # @param fname [String] Filename like http://abc.com/about_you.html
  # @param clobber: [Boolean] if true, an existing one will be overwritten.  In default, nothing is done.
  # @param c_message: [String, NilClass] commit message. If nil, automatically created.
  # @return [StaticPage, nil] nil if already exists and !clobber
  def self.load_file!(fname, langcode:, clobber: false, c_message: nil)
    ret_mname = File.basename(fname).sub(/\..*/, '')
    suffix = fname.sub(/\A.*\./m, '')

    sp = StaticPage.find_or_initialize_by(mname: ret_mname, langcode: langcode)

    c_message ||=
      if sp.new_record?
        'Initial commit.'
      elsif !clobber
        return
      else
        'Content overwritten with a file: '+fname.to_s
      end

    #fcontent = open(fname).read
    fname = fname.to_s
    fcontent =
      if (%r@^https?://@ =~ fname)
        #Net::HTTP.get(URI(fname))
        resp = Net::HTTP.get_response(URI(fname))
        if resp.code != '200'
          warn "HTTP ERROR in fetching #{fname} with response: "+resp.inspect
          raise 'Failed to get '+fname
        end
        resp.body
      else
        open(fname).read
      end

    ## This encoding-conversion is neccesary!
    ## Otherwise, all Japanese characters get encoded like "&#26085;&#26412;"
    fcontent.force_encoding('UTF-8') if fcontent.encoding != Encoding.find('UTF-8') || !fcontent.valid_encoding?

    case suffix.downcase
    when 'html', 'htm'
      html = fcontent
      fmt_mname = PageFormat::FULL_HTML
    when 'md', 'text'
      renderer = Redcarpet::Render::HTML.new(prettify: true)
      markdown = Redcarpet::Markdown.new(renderer, MD_EXTENSIONS)
      html = markdown.render(fcontent)
      fmt_mname = PageFormat::MARKDOWN
    when 'json'
      raise 'JSON unsupported, yet, for file='+fname
    else
      raise 'Contact the code developer. fname='+fname
    end

    ret_title, ret_content = _separate_title(html)
    if PageFormat::MARKDOWN == fmt_mname
      ret_content = _remove_markdown_h1(fcontent) # defined in StaticPagesHelper
    end

    sp.title   = ret_title
    sp.content = ret_content
    sp.page_format = PageFormat[fmt_mname]
    sp.commit_message = c_message
    begin
      sp.save!
    rescue ActiveRecord::RecordInvalid
      msg = "Failed to load a file: "+fname
      logger.error msg
      warn msg
      raise
    end
    sp
  end

  # From a HTML content, extract the H1 element and removes it from the content
  #
  # @return [Array<String, String>] 2-element array of [Title, HTML-without-H1]. Title may be nil.
  def self._separate_title(html)
    page = Nokogiri::HTML(html)
    title = nil
    page.search('h1').each do |src|
      title = src.text
      src.remove
      break
    end

    rethtml = (page.css('body')[0] ? page.css('body')[0].inner_html : page.inner_html)
    [title, rethtml]
  end
  private_class_method :_separate_title

  # @option locale [String, NilClass] Unlike the counterpart {StaticPagesController.public_path}, the default is nil.
  # @return [String] returns the path to show the model (without a locale in Default)
  def path_show(locale=nil)
    StaticPagesController.public_path(self, locale)
  end
  alias_method :public_path, :path_show if ! self.method_defined?(:public_path)

  # Returns Summary or (trimmed) Content, whichever exists.
  #
  # @param max_chars: [String] maximum character numbers to display for content
  #   Note several characters like ' (……snipped)' will be added over the max_chars limit.
  # @return [String]
  def summary_or_trimmed_content(max_chars: 300)
    return summary if summary
    return content if content.size <= max_chars
    content[0..(max_chars-1)] + ' (……snipped)'
  end

  # @return [String] Unique ID for each StaticPage; e.g., "ja_about_us"
  def form_id_model
    sprintf "%s_%s", langcode, mname
  end

  # returns the content rendered according to page_format
  #
  # @param **ext: extensions for Redcarpet https://github.com/vmg/redcarpet
  # @return [String] html_safe-ed
  def render(**ext)
      case page_format
      when PageFormat[PageFormat::FULL_HTML], PageFormat[PageFormat::FILTERED_HTML]
        ERB.new(content).result(binding).html_safe
      when PageFormat[PageFormat::MARKDOWN]
        renderer = Redcarpet::Render::HTML.new(prettify: true)
        markdown = Redcarpet::Markdown.new(renderer, MD_EXTENSIONS.merge(ext))
        markdown.render(ERB.new(content).result(binding)).html_safe
      else
        raise 'Unsupported PageFormat. contact the code developer: '+page_format.inspect
      end
  end

  private

end

