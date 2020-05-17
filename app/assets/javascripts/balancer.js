function update_weights() {
	var total = 0;
	    
	$('.balancer_input').each (function(i, obj) {
	  total += parseInt(obj.value);
	});   
	                          
	$('#balancer_total').text("Total: " + total + "%");
	
	// Only enable submission if it's 100
	if (100 == total) {
	  $('#adjust_weights').removeAttr('style');
	}
	else {
	  $('#adjust_weights').attr('style', 'pointer-events: none;'); 
	}
}
