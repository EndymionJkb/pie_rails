class SettingsController < ApplicationController
  respond_to :html, :js
  
  before_action :authenticate_user!
  
  def show
    current_user.ensure_setting
    
    @setting = current_user.setting
  end
  
  def update
    @setting = Setting.find(params[:id])
    
    @setting.update_attributes(settings_params)
    
    respond_to do |format|       
      format.js { head :ok  }
      format.html { redirect_to root_path }     
    end     
  end
  
private
  def settings_params
    params.require(:setting).permit(:e_priority, :s_priority, :g_priority)
  end
end
