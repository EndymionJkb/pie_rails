class GraphsController < ApplicationController
  respond_to :js

  def create
    data = Hash.new
    data[:chart] = {:type => 'pie'}
    data[:title] = {:text => params[:label]}
    data[:subtitle] = {:text => params[:subtitle]}
    data[:plotOptions] = {:series => {:dataLabels => {:enabled => true, :distance => -30, :format => '{point.name}<br>{point.y:.1f}%'}}}

    sections = []

    slices = params[:data].split('/')
    slices.each do |div|
      fields = div.split(':')
      yval = fields[1].to_f
      if yval > 0
        sections.push({:name => fields[0], :y => yval, :drilldown => nil})
      end
    end

    data[:series] = [{:name => '',
                      :colorByPoint => true,
                      :data => sections}]
    
    respond_to do |format|       
      format.js { render :json => data.to_json.html_safe  }
      format.html { redirect_to root_path }     
    end             
  end
end
