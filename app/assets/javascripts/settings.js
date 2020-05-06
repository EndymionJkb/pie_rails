function update_settings() {
  var crypto_selection = $('input[name="focus"]:checked').val();
  var coins = ['usdc', 'dai', 'usdt', 'tusd', 'tcad', 'taud', 'tgbp', 'thkd', 'usds'];
  var selected_coins = [];
  
  for (var idx = 0; idx < coins.length; idx++) {
    var checked = $('#' + coins[idx]).prop('checked');	
    if (checked) {
    	selected_coins.push(coins[idx]);
    }
  }
  
  if (selected_coins.length != 3) {
  	alert("Please select exactly three stable coins!");
  }
  else {
  	var data = {'crypto':crypto_selection, 'stable':selected_coins };
  	
    jQuery.ajax({url:'/settings/update_coins.js',
         data: data,
         type: "PUT",
         success: function() { alert("Coins updated successfully"); },
         error: function() { alert('Oh noes!'); }, 
         async: false});
  }
}
