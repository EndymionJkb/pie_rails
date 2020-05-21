function deposit_collateral(pie) {
	var amount = $('#amount').val();
	
	if (amount > 0) {
		jQuery.ajax({url: '/pies/'+ pie + '/deposit_collateral.js',
		             data: {'amount': amount},
		             type: "PUT",
		             success: function(data) { update_graphics(JSON.parse(data)); },
		             error: function() { alert('Oh noes!'); }, 
		             async: false});
    }
    else {
    	alert("Please enter a valid amount");
    }
}

function withdraw_collateral(pie) {
	var amount = $('#amount').val();

	if (amount > 0) {
		jQuery.ajax({url: '/pies/'+ pie + '/withdraw_collateral.js',
		             data: {'amount': amount},
		             type: "PUT",
		             success: function(data) { update_graphics(JSON.parse(data)); },
		             error: function() { alert('You cannot withdraw so much that your collateralization falls below the minimum!'); }, 
		             async: false});
    }
    else {
    	alert("Please enter a valid amount");
    }
}

function redeem_tokens(pie) {
	var amount = $('#amount').val();

	if (amount > 0) {
		jQuery.ajax({url: '/pies/'+ pie + '/redeem_tokens.js',
		             data: {'amount': amount},
		             type: "PUT",
		             success: function(data) { update_graphics(JSON.parse(data)); },
		             error: function() { alert('Oh noes!'); }, 
		             async: false});
    }
    else {
    	alert("Please enter a valid amount");
    }
}

function update_graphics(data) {
	$('#collateralization').text(data.collateralization);
	$('#collateral_progress').attr('class', data.progress_class + " progress-bar progress-bar-striped");
	$('#adjustments').text(data.adjustments);
	$('#total_value').text(data.total_value);
}
