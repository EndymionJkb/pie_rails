class PiesController < ApplicationController
  respond_to :html, :js
  
  before_action :authenticate_user!
  
  def show
    current_user.ensure_pie
    
    @pie = current_user.pie
  end
  
  def edit
    @pie = current_user.pie    
  end
  
  def update
    @pie = Pie.find(params[:id])
    
    if @pie.update_attributes(pie_params)   
      redirect_to py_path(@pie), :notice => 'Your pie was successfully updated.'
    else
      render 'edit'
    end        
  end
  
  def reset
    @pie = Pie.find(params[:id])

    @pie.update_attributes(:pct_gold => Pie::DEFAULT_PCT_GOLD,
                           :pct_crypto => Pie::DEFAULT_PCT_CRYPTO,
                           :pct_cash => Pie::DEFAULT_PCT_CASH,
                           :pct_equities => Pie::DEFAULT_PCT_EQUITIES)  
    @pie.crypto.reset
    @pie.stable_coin.reset
    
    redirect_to edit_py_path(@pie)
  end
  
private
  def pie_params
    params.require(:pie).permit(:pct_gold, :pct_cash, :pct_crypto, :pct_equities, :name, 
                                :crypto_attributes => [:id, :pct_curr1, :pct_curr2, :pct_curr3],
                                :stable_coin_attributes => [:id, :pct_curr1, :pct_curr2, :pct_curr3])
  end
end
