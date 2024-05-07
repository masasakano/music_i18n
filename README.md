# README — multiple translation website #

This is a Ruby-on-Rails framework for a website system to manage multiple translations for each term in each language. This works in combination with PostgreSQL database.

The standard I18n framework in Rails (and I think many other CMSs and website frameworks) assumes there is only one translation for each language locale for each term. Also, as far as the terms are concerned, they are stored in the source-code tree, not in the DB.  As for the latter, it is efficient performance-wise, but it does not work well in cases where

* many translations are accepted for each locale for each term (you would need countless locales!),
* translations are modified and added all the time (which is exactly what the DB is for!).

This system is the framework to deal with this type of complex and dynamic cases.

## Notes ##

### Environmental variables ###

* `LOAD_COUNTRIES` : Comma-separated ISO-3166-1 Alpha-2 country code, which will be loaded in seeding. Else all the countries are loaded
* `URI_HARAMI1129` : URI to download Harami1129 data
* `STATIC_PAGE_ROOT` : Root directory URI to load StaticPage-s in seeds
* `STATIC_PAGE_FILES` : Comma-separated filenames of StaticPage-s to load in seeds with proper suffixes like `.html` and `.md` or `.text` (for markdown).
* `MUSIC_I18N_DEF_FIRST_EVENT_YEAR` : Year of the first (potential) Event, used for forms and seeds (Default: 2019).
* `MUSIC_I18N_DEF_TIMEZONE_STR` : Default Time Zone in setting a Date or Time (Default: "+09:00"). Note that all are saved in the DB in UTC.
* `MUSIC_I18N_DEFAULT_COUNTRY` : Default country code (Default: "JPN").

#### Environmental variables for testing ###

* `TEST_STRICT` : if "1", more strict tests are performed.
* `SKIP_W3C_VALIDATE` : (*recommended*) if "1", W3C validations in testing, which connects to the W3C website, are skipped.
* `URI_HARAMI1129_LOCALTEST` : (*recommended*) the URI to access instead of `URI_HARAMI1129` for testing, e.g., `test/controllers/harami1129s/data/harami1129_sample.html`

### Database ###

This app assumes a PostgreSQL database.

Although many parts are database-independent, I am afraid some parts do not work in other database systems. For example, this uses `ILIKE` for case-incensitive matches and REGEXP functions of PostgreSQL, and some migrations use CHECK constraints.

### Static page strategy ###

**Requirements**:

1. Stored in the DB
   * Interface to edit it by admin
   * authorization
2. Versioning
3. i18n
4. readable Path for SEO
5. allowing dynamic parameters in the content
6. Admin interface on the web, desirably

To achieve these:

1. Standard Rails model StaticPage, generate scaffold, with controller StaticPagesController
   * Columns: mname, langcode, title, meta, format_content, content, summary
     * format determines "full HTML", "filtered HTML", etc.
   * Only admin can view/edit. No one else can.
2. Use [PaperTrail](https://rubygems.org/gems/paper_trail)
3. Based on `langcode` in *StaticPage*
   * `Mobility` gem (for i18n) does not work with `PaperTrail` at the time of writing ([see issue](https://github.com/shioyama/mobility/issues/324))
4. Simply edit `routes.rb` to accept any path with wildcards
   * which is handled by StaticPagePublicsController
     * Define the index layout in which the corresponding *StaticPage* model is selected according to the path name, and is loaded.
   * `constraints()` in combination with `lambda` is used to exclude files with a suffix like image files from the candidates (of static pages).
   * Alternative method may be Gem [HighVoltage](https://rubygems.org/gems/high_voltage)
     * A layout must be specified for each page, which is troublesome
     * Each layout can read a template from the DB like: `StaticPage.find_by mname: XXX`
5. Based on `page_format_id` column in `StaticPage`
   * `belongs_to` PageFormat
   * In step 4, `StaticPage#render` returns the content, where the processing method is defined in the method
     * Markdown processingl, using Gem Redcarpet.
   * In render, it is possible to introduce tokens like `<%= something %>`. But given everything is stored in the DB, the need is limited. Potential tokens include
     1. environmental variable
     2. Config parameters
     3. Pre-defined methods of `StaticPage`, maybe.
     4. eval as ERB (risky!)

## Asset pipeline and JavaScript ##

As of Version "v.0.11.0" (or "v.0.3" and onwards), this application adopts Rails 7.0 with esbuild and Sprockets in conjunction with Bootstrap, using occasionally jQuery (*jquery-ui-dist*).
In the earlier versions with Rails 6, it used to use Rails-6 + webpacker up to Version "v.0.2.1".

----------

