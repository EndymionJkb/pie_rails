# UNUSED for now - want to make this part of the Pie form submit
class StableCoinsController < ApplicationController
  respond_to :js

  before_action :authenticate_user!

  def update
    @cash = StableCoin.find(params[:id])
    # sanity check
    if @cash.pie.user.id != current_user.id
      raise 'Wrong user!'
    end
    
    @cash.update_attributes(cash_params)
    
    respond_to do |format|       
      format.js { head :ok  }
      format.html { redirect_to root_path }     
    end         
  end
  
private
  def cash_params
    params.require(:stable_coin).permit(:pct_curr1, :pct_curr2, :pct_curr3)    
  end
end
