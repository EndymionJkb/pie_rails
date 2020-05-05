require 'balance_calculator'

class BalancerPoolsController < ApplicationController
  before_action :authenticate_user!

  def new
    @pie = current_user.pie
    @pool = @pie.build_balancer_pool  
    
    @metamask = {'USDC' => 2000,
                 'ETH' => 10,
                 'DAI' => 3000,
                 'BAT' => 500}  
    @btc_address = '14a4aHGFggMCne6AuVszrtiDfSZbcCr51L'
    @btc_amount = 0.125
    @investment = params[:investment]
    
    @calculator = BalanceCalculator.new(@pie, @metamask, @investment)
    @chart_data = @calculator.build_chart 
  end
  
  def create
  end
  
  def show
  end
end
