# coding: utf-8
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
require "test_helper"

class StaticPageTest < ActiveSupport::TestCase
  include StaticPagesHelper

  test "non-null" do
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::NotNullViolation){
      p StaticPage.create!(mname: 'm1', title: 't1') }  # PG::NotNullViolation => Rails: "Validation failed: Langcode can't be blank"

    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::NotNullViolation){
      p StaticPage.create!(langcode: 'fr', title: 't1') }  # PG::NotNullViolation => Rails: "Validation failed: mname can't be blank"

    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::NotNullViolation){
      p StaticPage.create!(mname: 'm1', langcode: 'fr') }  # PG::NotNullViolation => Rails: "Validation failed: Title can't be blank"
  end

  test "unique" do
    sp = static_pages(:static_one)
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique){
      p StaticPage.create!(langcode: sp.langcode, mname: sp.mname, title: 't2') }  # PG::UniqueViolation => "Validation failed: Langcode has already been taken"
    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique){
      p StaticPage.create!(langcode: sp.langcode, mname: 'm2', title: sp.title) }  # PG::UniqueViolation => "Validation failed: Langcode has already been taken"
  end

  test "belongs_to" do
    assert StaticPage.first.page_format.mname
  end

  test "markdown input" do
    page = static_pages(:static_terms_conditions)
    rendered = page.render
    assert_no_match(/<h1>/, rendered)
    assert_match(/<em>/, rendered)
    assert_match(/<a /, rendered)
  end

  test "load html page from file" do
    (fullpath = _get_fullpath_to_load(/^privacy_policy/)) || return
    page = StaticPage.load_file! fullpath, langcode: 'en', clobber: true
    assert_match(/\bPrivacy policy/i, page.title)
    assert_equal PageFormat::FULL_HTML, page.page_format.mname
    assert_not_includes page.content, 'DOCTYPE'
    assert_not_includes page.content, '</html>'
    rendered = page.render
    if rendered.include?("invalid anchor")  # If the test data under /test/fitures/data are used.
      assert_includes rendered, '[invalid anchor](https://random.example.com/)', 'Markdown should not be interpreted in HTML format, but?'
      assert_includes rendered, 'いろはにほへと'
    end
    assert_operator 300, '<', rendered.size
    assert_no_match(/<h1>/, rendered)
    assert_match(/<ul>/, rendered)
    assert_match(/privacy policy/i, page.title)
  end

  test "load markdown page from file" do
    (fullpath = _get_fullpath_to_load(/^about_us/)) || return
    page = StaticPage.load_file! fullpath, langcode: 'en', clobber: true
    assert_match(/\bAbout\b/, page.title)
    assert_equal PageFormat::MARKDOWN, page.page_format.mname
    rendered = page.render
    assert_operator 300, '<', rendered.size
    assert_no_match(/<h1>/, rendered)
    assert_match(   /<h2>/, rendered)
    assert_equal 'about us', page.title.downcase

    page = StaticPage.load_file! fullpath, langcode: 'en', clobber: false
    assert_nil page
  end

  test "_remove_markdown_h1" do
    str = "abc\ndef \n# xyz\n123\n"
    assert_equal str, _remove_markdown_h1(str)

    str = "abc\ndef\n\n # xyz\n123\n"
    assert_equal str, _remove_markdown_h1(str)

    str = " # xyz\n123\n"
    assert_equal str, _remove_markdown_h1(str)

    str = "abc\ndef\n\n#xyz\n123\n"
    assert_equal str, _remove_markdown_h1(str)

    str = "abc\ndef\n\n# xyz\n123\n"
    exp = "abc\ndef\n\n123\n"
    assert_equal exp, _remove_markdown_h1(str)

    str = "  \n# xyz\n123\n"
    exp =        "\n\n123\n"
    assert_equal exp, _remove_markdown_h1(str)

    str = "# xyz\n123\n"
    exp =      "\n\n123\n"
    assert_equal exp, _remove_markdown_h1(str)

    str = "abc\ndef \nxyz\n==\n123\n"
    assert_equal str, _remove_markdown_h1(str)

    str = "abc\ndef\n\n xyz\n==\n123\n"
    assert_equal str, _remove_markdown_h1(str)

    str = " xyz\n==\n123\n"
    assert_equal str, _remove_markdown_h1(str)

    str = "abc\ndef\n\nxyz\n==\n123\n"
    exp = "abc\ndef\n\n123\n"
    assert_equal exp, _remove_markdown_h1(str)

    str = "  \nxyz\n==\n123\n"
    exp =        "  \n\n123\n"
    assert_equal exp, _remove_markdown_h1(str)

    str = "xyz\n==\n123\n"
    exp =        "\n123\n"
    assert_equal exp, _remove_markdown_h1(str)
  end

  # @param re [Regexp] to identify the file
  # @param from_env: [Boolean] set this true to test dotenv-rails
  # @return [String, NilClass]
  def _get_fullpath_to_load(re, from_env: false)
    if from_env
      fdir  = ENV['STATIC_PAGE_ROOT']   # defined in .env
      return if !fdir
      fnames = ENV['STATIC_PAGE_FILES'] # defined in .env
      return if !fnames
      fnames = fnames.split(/,/)
    else
      fdir = Rails.root.join(*(%w(test fixtures data))).to_s
      # fdir  = 'file://'+fdir.to_s
      fnames = Dir.glob(fdir.to_s+'/*.{html,md}').map{|i| i.sub(%r@.*/@, '')}
    end
    
    fname = fnames.find{|i| re =~ i}
    fdir.sub(%r@/$@, '')+'/'+fname
  end
end

