class StaticPagesController < ApplicationController
  respond_to :html
  
  before_action :authenticate_user!, :except => [:home, :works, :about]

  def home
  end
  
  def test
  end
  
  def works
  end
end
