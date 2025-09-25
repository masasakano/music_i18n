
// Validator in saving in Music#new
//$('#form_musics_new_primary').submit(function(event) {
$('form#new_music').submit(function(event) {
  // console.log("submit detected.");
  const fieldArtistName = $('#music_artist_name');
  //const selectEngageHows = $('#music_engage_hows');  // Old one (select-box) before SimpleForm (checkboxes)
  const selectEngageHows = $('fieldset.music_engage_hows').find('input[type="checkbox"]:checked');

  // When the artist_name field is filled, at least one EngageHow must be selected.
    // if ((fieldArtistName.val().trim() !== '') && (!selectEngageHows.val().length)) {  // Old one before SimpleForm
  if ((fieldArtistName.val().trim() !== '') && selectEngageHows.length === 0) {
    alert('Error! At least one enagegement needs to be specified when Artist is given.');
    event.preventDefault();
    return false;
  }
});

// Modifies a placeholder
// This placeholder would disappear when the screen is reloaded.
$('#music_year').on('input', function() {
  const musicYearEngage = $('#music_year_engage');

  musicYearEngage.attr("placeholder", $(this).val().trim() );
  return false;
});

