function update_pie() {
	var gold = jQuery('#pie_pct_gold').val();
	var crypto = jQuery('#pie_pct_crypto').val();
	var cash = jQuery('#pie_pct_cash').val();
	var equities = jQuery('#pie_pct_equities').val();
	
	var total = parseInt(gold) + parseInt(crypto) + 
	            parseInt(cash) + parseInt(equities);
	                         
	jQuery('#pie_total').val(total);
	
	// Only enable submission if it's 100
	if (100 == total) {
		$('#submit_pie').removeAttr('disabled');
	}
	else {
		jQuery('#submit_pie').attr('disabled', 'disabled');	
	}
}
