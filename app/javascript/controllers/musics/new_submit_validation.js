
// Validator in saving in Music#new
$('#form_musics_new_primary').submit(function(event) {
  const fieldArtistName = $('#music_artist_name');
  const selectEngageHows = $('#music_engage_hows');

  // When the artist_name field is filled, at least one EngageHow must be selected.
  if ((fieldArtistName.val().trim() !== '') && (!selectEngageHows.val().length)) {
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

