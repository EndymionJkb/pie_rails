class StaticPagesController < ApplicationController
  respond_to :html
  
  before_action :authenticate_user!, :except => [:home]

  def home
  end
  
  def test
  end
end
