const { environment } = require('@rails/webpacker')

// The following added to enable jQuery in Rails 6
// cf. https://rubyyagi.com/how-to-use-bootstrap-and-jquery-in-rails-6-with-webpacker/
//
// Note that the following is similar, but the jquery path does not work...
// https://www.botreetechnologies.com/blog/introducing-jquery-in-rails-6-using-webpacker
const webpack = require('webpack')
environment.plugins.prepend('Provide',
  new webpack.ProvidePlugin({
    // $: 'jquery',
    // jQuery: 'jquery',
    // jquery: 'jquery',
    //'window.jQuery': 'jquery',
    'window.jQuery': 'jquery/src/jquery',
    toastr: 'toastr/toastr',
    Rails: ['@rails/ujs'],
    $: 'jquery/src/jquery',
    jQuery: 'jquery/src/jquery',
    jquery: 'jquery/src/jquery',
    //Popper: ['popper.js', 'default'],
    Popper: ['popper.js/dist/popper', 'default']
  })
)

// cf. https://stackoverflow.com/a/58580434/3577922
const aliasConfig = {
    // 'jquery': 'jquery-ui-dist/external/jquery/jquery.js',  // A slightly different version (for testing?)
    'jquery-ui': 'jquery-ui-dist/jquery-ui.js'  // yarn add jquery-ui-dist
};
environment.config.set('resolve.alias', aliasConfig);

module.exports = environment
