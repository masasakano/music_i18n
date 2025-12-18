# README — multiple translation website #

This is a Ruby-on-Rails framework for a website system to manage multiple translations for each term in each language. This works in combination with PostgreSQL database.

The standard I18n framework in Rails (and I think many other CMSs and website frameworks) assumes there is only one translation for each language locale for each term. Also, as far as the terms are concerned, they are stored in the source-code tree, not in the DB.  As for the latter, it is efficient performance-wise, but it does not work well in cases where

* many translations are accepted for each locale for each term (you would need countless locales!),
* translations are modified and added all the time (which is exactly what the DB is for!).

This system is the framework to deal with this type of complex and dynamic cases.

## Notes ##

### Environmental variables ###

* `DEF_VIEW_MAX_NROWS` : Default maximum number of rows displayed in a Table.  If unspecified, `config.def_view_max_nrows` set in  `/config/application.rb` is used.
* `LOAD_COUNTRIES` : Comma-separated ISO-3166-1 Alpha-2 country code, which will be loaded in seeding. Else all the countries are loaded
* `URI_HARAMI1129` : URI to download Harami1129 data
* `STATIC_PAGE_ROOT` : Root directory URI to load StaticPage-s in seeds
* `STATIC_PAGE_FILES` : Comma-separated filenames of StaticPage-s to load in seeds with proper suffixes like `.html` and `.md` or `.text` (for markdown).
* `MUSIC_I18N_DEF_FIRST_EVENT_YEAR` : Year of the first (potential) Event, used for forms and seeds (Default: 2019).
* `MUSIC_I18N_DEF_TIMEZONE_STR` : Default Time Zone in setting a Date or Time (Default: "+09:00"). Note that all are saved in the DB in UTC.
* `MUSIC_I18N_DEFAULT_COUNTRY` : Default country code (Default: "JPN").
* `YOUTUBE_API_KEY` : Essential to use Youtue-API-related methods, such as those in `/app/controllers/concerns/module_youtube_api_aux.rb` .

#### Environmental variables for testing ###

* `TEST_STRICT` : if "1", more strict tests are performed.
* `SKIP_W3C_VALIDATE` : if "1", W3C validations in testing, which connects to the W3C website, are skipped.
* `USE_W3C_SERVER_VALIDATOR` : (*recommended not to be set*) if "1", this uses the original W3C server for W3C validation.
* `URI_HARAMI1129_LOCALTEST` : (*recommended*) the URI to access instead of `URI_HARAMI1129` for testing, e.g., `test/controllers/harami1129s/data/harami1129_sample.html`
* `SKIP_YOUTUBE_MARSHAL` : In testing, if this is set, marshal-ed data are not used, and the testing scripts access Youtube with the API whenever necessary.
  * `UPDATE_YOUTUBE_MARSHAL` : set this if you want to *update* the marshal-ed Youtube data from the remote Youtube server.  If this is set, `SKIP_YOUTUBE_MARSHAL` is ignored and treated as set.  Note that even if this is set, this does *not* create the marshal-ed data. For creating them, use `lib/tasks/save_marshal_youtube.rake`
  * For more detail about caching, refer to the comment at the head of `app/controllers/concerns/module_youtube_api_aux.rb`
* `CAPYBARA_LONGER_TIMEOUT` : If set with an integer in second, Capybara system-tests wait for a longer wait time in specific blocks (see method `with_longer_wait` in `/test/helpers/test_system_helper.rb`).
* `PRINT_DEBUG_INFO` : If set, display some debug information in some tests (especially for system tests, where the location of the error may be hard to pin point). Recommended to be used only temporarily, perhaps with a single test file.

##### Preparation for testing #####

Unless `SKIP_W3C_VALIDATE` is "1", run your (W3C) VNU server in a separate terminal with (in the case of macOS M1/2/3):

```bash
  java -Dnu.validator.servlet.bind-address=127.0.0.1 -cp $HOMEBREW_CELLAR/vnu/`vnu --version`/libexec/vnu.jar \
    nu.validator.servlet.Main 8888
```

Note that you may explicitly set the environmental variable `HOMEBREW_CELLAR` to `/usr/local/Cellar` for macOS Intel.

### Database ###

This app assumes a PostgreSQL database.

Although many parts are database-independent, I am afraid some parts do not work in other database systems. For example, this uses `ILIKE` for case-incensitive matches and REGEXP functions of PostgreSQL, and some migrations use CHECK constraints.

### Translation and strategy ###

When an entity may have title expressions in multiple languages, all expressions are stored in the table and model Translation, which has a polymorphic association with the model with multi-language titles.  All those model classes are unifiedly a child (or descendant) of a child model of ActiveRecord, BaseWithTranslation, which provides many useful methods.  For example, its `title` method returns the title in the original language in default.

In this scheme, an entity has an arbitrary number of multiple Translations.  In addition, translators (logged-on users with the translator priviledge) can add Translations even for an existing language.  On the website, only the best translations are usually displayed except in some cases.  However, all the registered translations are used in searaching.  If an entity has multiple nicknames, all of them can be registered, which would be of help in searching.

The priority of multiple Translations are determined on the basis of their attributes by algorithm.  In other words, all of them are structually the same, unlike some popular models, where the original name and its translations are structually distinguished, such as, `title` and `title_fr`.

### Seeding and fixtures for testing

#### Seeding scheme

When a new (ActiveRecord) model is introduced, you often want to define a few initial records without delay.  It is sometimes essential when a series of new models that have mandatory associations between them are introduced.  Seeding serves the purpose.  Since you don't know in general what the current database is like, it is best to code the seeding executable in such a way that it loads only those data that are missing in the current database, not overwriting the existing records (unless some modifications for essential data that should not be allowed have been made).

In this framework, I have written some initial seeding directly in `/db/seeds.rb`, which loads some data from JSON files in `/lib/assets/seeds/` .  But it soon became clear as this framework grew that it is unsuitable.  Although I keep the seeding file (if it ain't broke, don't fix it!), I developed a new seeding scheme to seed those that are not directly included in the seeding file.

The new module `Seeds` is defined in `/db/seeds/common.rb`. Here, the constant `Seeds::Common::ORDERED_MODELS_TO_DESTROY` defines the (reverse) order of seeding, and should be updated every time a new model is defined.  Evety time a new model is introduced, a new seeding file should be created in `/db/seeds/` with the name of snake-case plural model name, e.g., `site_categories.rb` for the model `SiteCategory`. Refer to `/db/seeds/domain_names.rb`, for example, to see how you write the file.  In short,

1. require the `commonrb` : `require_relative("common.rb")`
2. Define a new module under the name space of `Seeds` with a camel-case plural word of the model, e.g., `Seeds::SiteCategories` for the model `SiteCategory`
3. Extend it with `extend Seeds::Common`
4. Define the main `with_indifferent_access` hash `SEED_DATA` with an arbitrary key and value that is a `with_indifferent_access` hash with the data to load, including its Translations (if any), plus any extra information.
   1. Most keys for the innermost hash is the names of the attributes, such as `:note`.
   2. For translations, use `ja`, `en`, `fr`, and `orig_langcode` as the keys; they are reserved.
   3. `regex` is the reserved key, where you define either the regular expression to identify the existing record that has been already loaded from the seed or Proc to identify it.  For further detail, consult `common.rb`, specifically `_load_seeds_core`
   4. You can include other random keys.
   5. If the value is a Proc, it is *called* in seeding.
5. Define the callback `load_seeds`, in which you give the list of main attribute names (in other words, the keys of `SEED_DATA` that are not included here are ignored in direct seeding (though you may used them in fixtures!).

One important point to note is that no data have been loaded when this `SEED_DATA` is defined. For this reason, if you need to dinamically define the value of an attribute, such as the associated pID, you must define the algorithm to derive it in Proc so that it is run on the spot when the seeds are being loaded.  For example,

```ruby
unknown: {
  site_category: Proc.new{SiteCategory.find_by(mname: "unknown") || raise(SiteCategory.all.inspect)},
  site_category_key: :unknown,
}
```

Here, the latter is the dummy keyword for seeding but is used to define the fixture, as explained below.

#### Fixtures loaded from the seeds

The Test environment should be close to the real environment. (I note that although you may want to test some boundary cases, which may rarerly or even never happen in real situations but are important to be tested to assure the quality of the software, you should do so by preparing specific test cases, including a combination of some model records, while keeping the general-use test environment as close as the real situations as possible; the Rails general test fixtures serve the latter).

For this reason, I have implemented the scheme to load the same resources for test fixtures as those for seeding.

An example is taken from `/test/fixtures/domain_names.yml`:

```ruby
<% Seeds::DomainNames::SEED_DATA.each_pair do |ekey, edata| %>
domain_name_<%= ekey %>:
  site_category: site_category_<%= (pro=edata[:site_category_key]) ? pro.to_s : "unknown" %>
  weight: <%= edata[:weight] %>
  note: SiteCategory<%= ekey.to_s.camelize %>
  memo_editor: <%= edata[:memo_editor] %>
<% end %>
```

Most are self-explanatory.  An important point is how to write an association.  If the part is written as

```ruby
  site_category_id: <%= (pro=edata[:site_category]) ? pro.call.id : nil %>
```

it would not work well in large-scale testing with a hard-to-pin-down error of `ActiveRecord::Fixture::FormatError`, although it may work for small-scale testing, confusingly.
The reason it may not work is (I think) although `SEED_DATA` is perfectly created in the first go, `SEED_DATA` is not automatically refreshed in multiple creation of fixtures, unless specified so.
`site_category_id` is an Integer attribute and would not be refeshed.  When a new set of fixures is re-created, a whole set of new SiteCategory is also created, meaning the pID of the *unknown* SiteCategory changes.  Yet, the value of its foreign-key attribute `site_category_id` is not updated, resulting in a broken association.

That is why the standard way of writing association in fixtures is this:

```ruby
  site_category: one
```

The point is (1) it is `site_category` as opposed to `*_id`, and (2) referring to the name of the corresponding fixture (of SiteCategory).  In this case, the fixture generation algorithm dynamically recreate the entire set of fixtures, keeping its internal consistency.

Thus, you must write the fixtures according to this way, and for that, your ERB-embeded code should just give the name of the corresonding fixture. Obviously, I am assuming the fixtures for SiteCategory is written in the same manner as described above (or you can simply write it manually if you want).


### Procedure to generate a new sub-class and DB table of BaseWithTranslation

How to generate a new ActiveRecord model with Translation.

1. `bin/rails generate scaffold MyModel ...` (scaffoling) or generate model.
2. Edit the migration file. In addition to possibly adding comments for DB table/columns like `t.text :memo_editor, comment: "Internal-use memo for Editors"`, an important point is to edit the *down* direction so the down-migration will destroy some related DB records. Two obvious classes to look at are Translation (polymorphicaly associated) and ModelSummary (and its Translations).  Do as follows for example (n.b., it is important not to use currently existing models as they may not exist at the time of future migrations, hence the new definitions of the model classes inside the migration file):

   ```ruby
   class CreateMyModels < ActiveRecord::Migration[7.0]
     class Translation < ActiveRecord::Base
     end
     class ModelSummary < ActiveRecord::Base
     end
   
     def change
       create_table :my_models, comment: 'MyModel blah blah...' do |t|
         # ...
         t.timestamps
       end
   
       modelname = "MyModel"
       reversible do |direction|
         direction.down do
           record = ModelSummary.where(modelname: modelname).first
           record.destroy if record  # This should destroy its Translations
           Translation.where(translatable_type: modelname).delete_all  # Note: destroy_all may cause violations
         end
       end
       # ...
     end
   ```

3. Run DB migration.
4. Adjust seeds-related files and fixtures.  In this framework, many fixtures are loaded from the seeds file (so that fixtures mimic the real situation), where the Rails naming convention is often assumed.
   1. First, create `/db/seeds/my_models.rb` (plural), referring to, say, `channels.rb` in the same directory.
      1. At the top, you should load other seeding files that your model depends on, if any.
      2. Make sure the module name matches your model name.
      3. Write your seeds.
   2. In `/db/seeds/common.rb`, add your new model (MyModel) in the Array `ORDERED_MODELS_TO_DESTROY`. Here, the order matters. Your model should be placed so that any model befoer your model can be destroyed freely and that destroying your model would not violate any constraints posed by the remaining models. It is basically the reverse list of building models.
   3. Edit (or create if not present) the fixture file of your new model at `/test/fixtures/my_models.yml`
   4. Edit the fixture `/test/fixtures/translations.yml`
      1. In addition to the Translation fixtures for your manually-added new test models (at `/test/fixtures/my_models.yml`), add your model name in the outer-most ERB-type triple-nested iterator somewhere lower down (search by keywords of "SEED_DATA.each_pair" to find it).  This adds Translations corresponding to your fixture models of your new model created according to the new seed files.
   5. In the constant Hash `SEED_DATA` in `/db/seeds/model_summaries.rb`, add a new entry, which is a human-readable description of the model mostly served for the editors of the website.
      * On the website, it is displayed at `/model_summaries` (providing you are logged on and have a suitable priviledge).
   6. Run the seed test to confirm the seeds files have been written right: `DO_TEST_SEEDS=1 bin/rails test test/seeds/seeds_*rb`
5. In the model file, `/app/models/my_model.rb`,
   1. change the parent class from `ApplicationRecord` to `BaseWithTranslation`
   2. You may include `ModuleUnknown` if your model has the method `unknown` and `ModuleWhodunnit` if the model contains an attribute(s) like `create_user`
   3. define the constant `ARTICLE_TO_TAIL` appropriately, which is used in methods of BaseWithTranslation. It is true, if the title is very short like one to a few words, else false (i.e., if the title of the model is usually a sentence).
   4. you may define the constant `MAIN_UNIQUE_COLS` which is used in BaseWithTranslation to identify what constitutes a unique Translation. For example, there should be no two prefectures with an identical name withing a country. Howewver, it is perfectly fine for two separate countries, such as, Perth in the UK and Australia. So, `Prefecture::MAIN_UNIQUE_COLS` has a single element of `country_id`. An attempt to create a new Prefecture in a Country with an idential name should be prohibited as a result.
   5. If you include `ModuleUnknown`, you should define the hash constant `UNKNOWN_TITLES` for at least English and Japanese.
      * You may also define `self.default`, which may simply return `MyModel.unknown` providing that you have included `ModuleUnknown`
   6. Define the translation-related callback `validate_translation_callback` used in BaseWithTranslation.  Usually, you would need at least `validate_translation_neither_title_nor_alt_exist`
   7. Define desired associations, validations, and methods if any.
6. In the controller file,
   1. Add usful modules at the top, including `ModuleCommon` (general-purpose module), `ModuleMemoEditor` (if editor-only `memo_editor` attribute is included in the model). If you use the gridder for index, add also `ModuleGridController`.
   2. Adjust the access permission (for CanCanCan).  In default (as defined in ApplicationController), unauthorized user are prohibited to access any of the methods.  
      * For a (rare) publicly viewable model, `skip_before_action :authenticate_user!, only: [:index, :show]` is essential.
      * Otherwise, `load_and_authorize_resource except: [:create]` does the job, usually (while deleting the line of `before_action set_my_model`).
   3. Adjust the params handling.
      * Since Translation-related attributes like `title` are **not** part of this model's attributes, the Rails default `params` does not work well in processing the form input including `title` etc. Refer to, for example, `domain_names_controller.rb`, to see how to handle the case neatly. In short, you define the class constant `MAIN_FORM_KEYS` (maybe also employing `PARAMS_PLACE_KEYS` if your edit-form contains a Place selection), and `before_action` method (say, `model_params_multi`) for `:create` and `:update`, in which `set_hsparams_main_tra(:my_model)` (defined in the parent class in `application_controller.rb`) is called (n.b., for the class without Translation, call `set_hsparams_main_tra(:my_model)` instead). It sets three instance variables of Arrays, `@hsmain`, `@hstra`, and `@prms_all`, which contains the form parameters except Translation-related ones, only Translation-related ones, and both, respectively.
      * For processing the final outputs in `:create` and `:update`, `def_respond_to_format()` (again defined in `application_controller.rb`) is a handy method.
7. Edit the access-permission setting file for CanCanCan: `/app/models/ability.rb`
   1. In default, no action is allowed for anyone but authorized users with a role (as defined in UserRoleAssoc). So, you must explicity allow certain methods to certain roles (or higher-rank ones).
8. Edit Views, in particular forms.  The key is to include the Translation-model part. Consult the Views for DomainName, for example.  Also, flash is handled in the application layout. So, you can remove the flash-related parts from the views. Here are some useful helpers (layouts).
   1. partial `'layouts/form_print_errors'` displays an error message contained in the model.
   2. partial `'layouts/all_registered_translations'` displays the Translation in Show and also Edit.
   3. partial `'layouts/partial_new_translations'` presents the form for title and translation-related field. Here, `disable_is_orig: false` should be given in most cases, which hides the field to choose the original language, unless the model is about a general stuff like an animal, which has no original language defined but can be equally expressed in any language.
   4. partial `'layouts/form_note_memo_editor'` displays note-related part of the form in SimpleForm %>
   5. partial `'layouts/show_edit_destroy'` shows the footer like Edit button
9. Internationalization(I18n) / Localization (L10n)
  * Edit translation fixtures of at least `/config/locales/common.en.yml` and `common.ja.yml`, registering how the new model is called (to display). You may also add other model-specific translations in `view.en.yml` etc.
10. Edit fixtures.  In particular, you must add entries in `translations.yml`.  Note that you can embed a piece of Ruby code in the ERB format to import the translations of your model records automatically imported from the seed files, where you should have already written the translations.  See the example for DomainName.
    * *NOTE*: `/test/models/fixture_test.rb` performs a basic check of fixture integrity, which would fail if you have forgotten to include Translation fixtures for your new model.
11. Edit your test files
    1. Model tests. Basic tests for validations and associations should be included at least.
    2. Controller tests. Basic tests for validations and associations should be included at least.
       1. You should add `include Devise::Test::IntegrationHelpers` and `teadown` for cache-clearing, providing at least some actions like editing/destroying a record would need an authorized priviledge.
12. Execute seeding (`bin/rails db:seed`), providing the seeding tests succeed. Execute a couple of times (in the development environment) to confirm no errors would be raised.  If it does, seeding may fail in the production evironment!
    * A case of failure is that a model has a machine-name attribute, which is used in idnetifying a duplication, and yet the machine-name is modified either in the seed file or on the website.  In this case, their Translations may raise a violation.


### Procedure to define a new association of a model to Url through polymorphic Anchoring

#### Framework

In this framework, the ActiveRecord/BaseWithTranslation model *Url* holds *Url* records in a polymorphic way so that the information can be associated to any class, as long as the basic association setups of `has_many` and `belongs_to` are defined mutually. Each 

#### Procedure

The join class *Anchoring* provides a polymorphic many-to-many association between *Url* and other classes (of *BaseWithTranslation*, a subclass of *ActiveRecord*).  Here is a standard procedure to define it to a new model.  Whereas the modification to the model is tiny (just one line!), you are most likely to need a new Controller for it, which needs a bit more work. In the following procedure, you add an editing interface of Url in the Show page of the model, where an editor can edit it on the spot.

Here, let us call the new model the "target model" *Target*.

Almost all the methods for Controller and layouts for Views are already provided.  So, only you need is basically to link them to your Cnotroller and View, along with an added line to your routes file.

1. In the model file of *Target* (`/app/models/target.rb`), adds a line (maybe at the top though anywhere is acceptable): `include Anchorable`
2. Run (at your shell): `bin/rails generate controller targets/anchorings --no-helper` which will generate
   * This generates a template Controller and test files, along with the directory like `/app/controllers/targets/`
   * In fact, instead you can just manually create new directories and copy and paste the files, changing the file names appropriately, of 1 Controller, 1 controller test, and many views from respective template files from another model like `/app/controllers/places/anchorings_controller.rb` and `test/controllers/places/anchorings_controller_test.rb` and `/app/views/places/anchorings/` Each of them contains only a few lines, which require to be modified according to your target class name.
3. Edit your route file `/config/routes.rb` , adding the following lines (replacing *:targets* according to your class name).  Rails-generate does not automatically modify the route for the nested resources.

   ```ruby
   resources :targets do
     resources :anchorings, controller: 'targets/anchorings'
   end
   ```
4. Edit your controller file (`/app/controllers/targets/anchorings_controller.rb`). A key is **to replace the parent class**.  The Controller file needs only 3 lines as follows (make sure to change the class name according to your *Target* class name); the Controller should be a child class of `BaseAnchorablesController` and defines your model-specific constant `ANCHORABLE_CLASS` .  All the methods (like `show` and `create`) are defined in the parent class.

   ```ruby
   class Targets::AnchoringsController < BaseAnchorablesController
     ANCHORABLE_CLASS = self.name.split(":").first.singularize.constantize  # Place class
   end
   ```
5. Copy your view files from a template, `/app/views/places/anchorings/` 
   * You discard the auto-generated View files by `rails generate`
   * In this case, the file names are also identical. So you can actually copy the directory as a whole.
6. Edit the View file for Show for *Target* (either `/app/views/targets/show.html.erb` or its standard partial `_target.html.erb`), addig the following (making sure to change the name `target` to your model name).

   ```ruby
   <%= turbo_frame_tag "targets_anchorings_"+dom_id(@target) do %>
     <%= render partial: 'layouts/index_anchorings', locals: {record: @target} %>
   <% end %>
   ```
7. Edit the Controller-test file (`/test/controllers/targets/anchorings_controller_test.rb`)
   * A nominal way is just to copy the contents from a template at `/test/controllers/places/anchorings_controller_test.rb` and change the contents of the two instance variables `@anchorable` and `@anchorabl2` in +setup+ with your fixture record for *Target*
   * The copied file then tests basic CRUD with the newly associated *Target*-*Anchoring* (and *Url*). A key is a few lines near the top. Basically, your *ControllerTest* class should be a subclass of the custom *BaseAnchoringsControllerTest*:
   
     ```ruby
     require "test_helper"
     require "controllers/base_anchorings_controller_test.rb"

     class Places::AnchoringsControllerTest < BaseAnchoringsControllerTest  # < ActionDispatch::IntegrationTest
     ```
   * If a test fails, it may be because of permission because the editing permission follows that of the parent class (*Target* in this case), which varies.  Access to some models are more restricted than others.  You may edit the `fail_users` and `success_users` in the test file.
   * You may add some more specific tests, including system tests.

Finally, if you decide to add more (Controller) methods or tests, you may want to add them to `BaseAnchorablesController` or `helpers/controller_anchorable_helper`, respectively, because most of them should be applicable across all *anchorable* models.

##### Comment about descriptions and notes related to URL #####

A few *titles* and *notes* are available for *Url*, *Anchoring*, and related relations.  Here is a breakdown.  Here, `i18n` (=internationalization) means different texts can be given for separate languages.

* *SiteCategory*: `title` (i18n): describing the biggest category of the site, such as, "Priimary (website)", "Media", "Encyclopedia"
* *DomainTitle*: `title` (i18n): describing what the domain is, e.g., "Youtube", "Instagram", "Wikipedia". Many of the DomainTitles can be simply the domain address, though.
* *Url*: `title` (i18n): describing what the URL/URI is, e.g., "2025 Yahoo-news interview of HARAMIchan", "Budokan".
* *Url*: `note`: any additional comment about the URL/URI, e.g., "The access is limited within Japan", "Grand overview of Budokan". This can be edited only in the specific *Url* edit page (and **not** in the Show page of target models)
* *Anchoring*: `note`: describing the relation with the Target record or context about the URL, e.g., "Media report" (for Event-model association), "First-played place" (for Music-model association).

Here, `Url#title` and `Url#note` are URL-specific and association-wide; so you should not give an association-specific description, for example, explaining why this link is listed in the Show page is inappropriate for them.  Remember the same URL may be referred to from completely different pages!  For example, the last example of *Anchoring* shows it well. It describes why the URL (for the Wikipedia entry of "Budokan" is listed in the Music#show page, whereas the explanation would be out of context in other pages.

In each target-model Show page, each item is displayed in a form of

    (SiteCategory#title: DomainTitle#title) [Url#url_langcode] Url#title (NOTE: Url#note; Anchoring#note)

where `Url#title` is highlighted as the anchor.  In the on-the-spot edit screen, an editor can edit `Anchoring#note` but NOT `Url#note` (visit the specific-edit page of *Url* to edit `Url#note`).

#### Framework for Url and Anchoring, including testing ####

Here I present an in-depth description of the framework.

##### Models

* *Url* `belongs_to` *Anchoring*
  * *Url* `has_many` *Anchorings* and many "anchorables" (i.e., "targets" with the notation above) through *Anchorings* (in a polymorphic way)
* *Anchoring* `has_many` *Urls* and `has_many` "anchorables" in a polymorphic way
* "anchorable" `belongs_to` *Anchoring*
  * "anchorable" `has_many` *Anchorings* and many *Urls* through *Anchorings*

To illustrate the relations:

    Url → (has_many)        → Anchorings → (EACH belongs_to)      → anchorable
    Url ← (EACH belongs_to) ← Anchorings ← (polymorphic has_many) ← anchorable

Because of the polymorphic relations, Rails provides no built-in methods for `Url#anchorables`; I define it so that it returns a Ruby Array of "anchorables" as opposed to the DB records or its relation, which is a standard (and only) way.

In practice, in the current setting, *Url* and all the *anchorable* class are subclasses of *BaseWithTranslation*, which is a subclass of *ActiveRecord*; accordingly, they also have polimorphically many *Translations*.  Although this relation is not an absolute requirement for "anchorable" classes, many of the methods and framework scheme assume that it is the case.

A utility module *Anchorable* is defined, which can be (and are) included in each anchorable class, setting up the association and providing several methods.

##### Controllers

*Url* itself can be fully edited with its standard RESTful user-interface (UI) by permitted editors through *UrlsController*.
However, it does not provide functionality to edit its associations to "anchorables", that is, (join-table records) *Anchorings*.

Instead, the framework provides an on-the-spot UI for editing the associations inside the Show page of each *anchorable* through *Targets::AnchoringsController*, where "Targets" is the pluralized-CamelCase name of the target ActiveRecord class, such as, *Musics*. Any editor who is permitted to edit the Show page of the record is granted to edit/create/destroy the association of new or existing URLs.  Within the UI, they can **edit** a limited portion of information of the associated *Url* and (in an even more limited way) its parent *Domain*, but they cannot **destroy** a Url record through the UI.

Here, each controller *Targets::AnchoringsController* is a subclass of *BaseAnchorablesController*, which is a subclass of the standard *ApplicationController*.  *BaseAnchorablesController* provides most (or virtually all) of the required methods, such as :show, :update, :destroy for each subclass, so each subclass hardly defines its own method.
*BaseAnchorablesController* includes the *BaseAnchorablesHelper* module, which contains a few utility methods.

##### Views

The index part for *Anchorings* is displayed in the *Show* page of each record of "anchorable", and the part is within a turbo-frame in order that the clicking/tapping hyper-links in it would be intercepted by the Turbo AJAX (by standard browsers). *Targets::AnchoringsController* renders a partial for Turbo, which will be interpreted by the browser with Turbo (JavaScript), providing an on-the-spot editing functionality of *Anchorings*.

##### Testing

Each testing Controller is like *Targets::AnchoringsControllerTest* and is defined as a subclass of *BaseAnchoringsControllerTest*, which is a subclass of the standard *ActionDispatch::IntegrationTest*.
*BaseAnchoringsControllerTest* basically defines the standard testing flow. So, each subclass like *Places::AnchoringsControllerTest* needs the minimum set of test suite.  Indeed, apart from the model-dependent permission issues, they are designed to behave in an almost identical way, regardless of the class of the *anchorable*.

*BaseAnchoringsControllerTest* includes the helper *ActiveSupport::TestCase::ControllerAnchorableHelper* (found at the time of writing in `/test/controllers/musics/anchorings_controller_test.rb` though the location is not right...), which defines wrappers of most of test assertions.  Most of the actual assertions are defined in the custom helpers
in `/test/helpers/controller_helper.rb` which I developed as a generic framework for popular Controller tests. Since it is a genral framework, *ActiveSupport::TestCase::ControllerAnchorableHelper* has been developed to provide wrappers that are tailor-made for testing *Anchoring* associations.
Note that *ActiveSupport::TestCase::ControllerAnchorableHelper* (and *BaseAnchoringsControllerTest*) include the module *BaseAnchorablesHelper*.

The above-described framework follows the DRY principle, and indeed, the amount of code required to write when introducing a new *anchorable* class is minimum. The downside is, however, that it is not always easy to pin down **where** and what causes an assertion failure when one happens.  I have coded so that some of the test assertions report some caller information, using Ruby's bind information, but admittedly many of them do not.  Among the Anchoring-associated classes, the testings for `Music`, `Place`, and `HaramiVid` follow this principle diligently, and so they have very little unique test code but some parameters. By contrast, those for Event are deliberately left more primitive, though still heavily using the above-mentioned framework. In addition, some tests that should not be repeated (such as, network-dependent ones) are defined only in Event-Anchoring testings. Finally, The tests for Artist-Anchoring are most primitive, but again I leave them as they are, because they give slightly independent way of testing, even though the current testing framework have evolved from the their testing.

### Strategy for URL normalization

This framework keeps each URL as a unique record in the class *Url* with a major exception of those of *HaramiVid*, which is dedicated for the URLs of the primary Artist's videos.  In either case, the algorithm to guess the uniquness is important; otherwise you might end up with many URL records that basically point to the same content. The cause of such duplication is, in a word, there are usually more than one, or many, ways to express the same URL. An editor may input (copy & paste?) URLs they see in creating/editing an entry on a website, which may inadvertently vary. Here are some popular causes.

* **Path-level forwarding*/*redirection**
  * e.g., www.youtube.com/watch?v=XXX, www.youtube.com/shorts/XXX, and www.youtube.com/live/XXX
* **(Domain-level) forwarding*/*redirection**
  * **www**: e.g., `www.example.com` and `example.com`
  * **locale**: e.g., `en.example.com` and `ja.example.com`
  * **country**: e.g., `google.com` and `google.co.jp`
  * **shortner**: e.g., `youtu.be` (shortened) and `youtube.com`
  * **domain switch**: e.g., Twitter.com and X.com
* **Full forwarding*/*redirection**
  * e.g., tinyurl.com, bit.ly, t.co
* **query and fragment parameters in the URL**
  * **tracking queries**: e.g., `si=XXX` on Youtube, but note `v=XXX` on Youtube is essential
  * **fragment**: `abc#xy123` (to point to a point on the page)
* **scheme**
  * e.g., `http` and `https`. People often simply omit the scheme part.
* **port**
  * e.g., `example.com:80`, `example.com:443`
* **case sensitivity**
  * Domain part is case-insensitive. Path part usually is case-sensitive, but may not be. The consecutive forward slashes in the path part are insignificant as a convention.
* **encoding**
  * **IDN**: `お名前.com` and `%E3%81%8A%E5%90%8D%E5%89%8D.com`

Basically, there are an arbitray number of combinations to express the same content.
To make the matter worse, the insignificance for these varieties entirely depend on each website...  For Youtube, for example, some query parameters are vital whereas some are not at all (perhaps except for the adverts you end up seeing).

Therefore, a URL normalization is a key to maintain the uniquness of each record (at a best-effort basis).

#### classes and module in this framework

In this framework, URLs are basically kept in two models: *HaramiVid* and *Url*. The latter is the dedicated model for the video URLs for the primary artist. Eeverything else is stored in the former and used in a polymorphic way from other models.

For Youtube URLs, which are the primary URLs for the former, HaramiVid sotred them with the shortened form of youtu.be/XXX with no query parameters. Timing can be significant in some cases (which works like the URL fragment). The timings are stored as `HaramiVidMusicAssoc#timing`.

A non-trivial part is that when a user supplies a URL-look String without a scheme, to judge whether it is a Internet-valid URL or not. They are not a valid URI. However, some valid URIs are not Internet-valid URLs.  If the potntial schemes are limited to either `http` or `https`, the algorithm would be greatly simple.  However, to accept a general URL is tricky; for eample, `sftp::` is a perfectly valid scheme.  To address these issues, I basically develop custom routines which primarily relies on `Addressable::URI` to make sure the algorithm is right and also future-proof.

the main class *Url* has a multiple structures as follows.

* Column `url`: everything inclusive except preceding and trailing spaces, but stored in the decoded way (because once it is fully decoded, it is unique within UTF-8). For Youtube URLs, it is the same as with HaramiVid but timing parameters preserved.
* Column `url_normalized`: the normalized URL, where the scheme, preceding `www.`, port parts are removed, the domain part is downcase, and everythig is fully decoded. This is used for uniquness testing among *Url* records.
* Column `domain_id`: Pointing the parent class *Domain*, which keeps only the domain part without the trailing forward slash `/`.
* *DomainTitle* : Parent class of *Oomain*, expessing an organization that maintain the children *Domains*.  Most typically, *Domains* with and without the prefix `www.` belong to a single *DomainTitle*
* The parent class of *DomainTitle* is *SiteCategory*.
* Funciton module *ModuleUrlUtil* have many utility functions.

The following methods are used commonly (they are extensively unit-tested).

* `ModuleUrlUtil.normalized_url`
  * Do-it-all URL normalizer.  Basically, this is the one all the other methods in this framework use with varying parameters according to their individual needs.  This only decodes the URL, not the other way around.  In this framework, we only deal with Internet URLs, not the whole set of URI.
* `ModuleUrlUtil.valid_url_like?`
  * Any String that passes this test is regarded as a valid URL (or that can be compiled into a valid URI by adding a scheme part) in this framework.
* `ModuleUrlUtil.valid_domain_like?`
  * Any String that passes this test is regarded as a valid domain.
* `ModuleUrlUtil.get_uri`
  * returning a valid URI object, providing the given String passes the test by `ModuleUrlUtil.valid_url_like?`
* `ModuleUrlUtil.url_prepended_with_scheme`
  * returning a valid URI String, prepending the scheme `https://` if required, providing the given String passes the test by `ModuleUrlUtil.valid_url_like?`
* `Url.find_url_from_str`
  * Find the *Url* from a given URL-like String (if on the DB)
* `Url.minimum_adjusted_url`
  * the filters used to generate `Url#url` before-save
* `Url.self.normalized_url`
  * the filters used to generate `Url#url_normalized` before-save
* `Domain.find_by_urlstr`
  * Find the *Domain* of a given URL-like String (if on the DB)
* `Domain.extracted_normalized_domain`
  * the filters used to generate `Domain#domain` before-save
* `DomainTitle.find_by_urlstr`
  * Find the *DomainTitle* of a given URL-like String (if on the DB)
* `SiteCategory.find_by_urlstr`
  * Find the *SiteCategory* of a given URL-like String (if on the DB)

In this framework, we basically use `Addressable::URI`, as opposed to the traditional `URI` class/module. because the former is greatly more advanced, including the handling of IDNs.


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

