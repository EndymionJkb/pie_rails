# UNUSED for now - want to make this part of the Pie form submit
class CryptosController < ApplicationController
  respond_to :js

  before_action :authenticate_user!

  def update
    @crypto = Crypto.find(params[:id])
    # sanity check
    if @crypto.pie.user.id != current_user.id
      raise 'Wrong user!'
    end
    
    @crypto.update_attributes(crypto_params)
    
    respond_to do |format|       
      format.js { head :ok  }
      format.html { redirect_to root_path }     
    end         
  end
  
private
  def crypto_params
    params.require(:crypto).permit(:pct_curr1, :pct_curr2, :pct_curr3)    
  end
end
