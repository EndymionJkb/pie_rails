function render_model_graphs() {
	$('.graph_data').each(function(i, obj) {
		var row_id = obj.id + "_val";		
		var label_id = obj.id + "_label";		
		var data = {'data': $('#' + row_id).val(), 'label': $('#' + label_id).val()};
		
	    jQuery.ajax({url:'/graphs.js',
	         data: data,
	         type: "POST",
	         success: function(data) { 
	         	Highcharts.chart(obj.id, JSON.parse(data));
	         },
	         error: function() { alert('Oh noes!'); }, 
	         async: false});
	});
}
