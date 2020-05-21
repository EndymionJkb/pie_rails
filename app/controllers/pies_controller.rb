require 'pie_calculator'

class PiesController < ApplicationController
  before_action :authenticate_user!
  before_action :no_pool, :only => [:edit_allocation]
  
  def show
    current_user.ensure_pie
    
    @pie = current_user.pie
    
    @chart_data = @pie.build_chart 
  end
  
  def edit
    @pie = current_user.pie 
    @expiry_dates = UmaExpiryDate.all
    @default_date = @pie.uma_expiry_date or UmaExpiryDate.first.date_str   
  end
  
  def update
    @pie = Pie.find(params[:id])
    
    if @pie.update_attributes(pie_params)  
      # Calculate returns 
      perf = PieReturnsCalculator.new(@pie, [1, 3, 6, 12])
      perf.calculate
      perf.save
      pc = PieBacktestCalculator.new(@pie)
      pc.calculate
      pc.save
      
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
    @pie.etfs.delete_all
    @pie.stocks.delete_all
    
    redirect_to edit_py_path(@pie)
  end
  
  def edit_allocation
    @pie = Pie.find(params[:id])   
    @show_etfs = 'true' == params[:etf] 

    @current_alloc = []
    @held_etf_ids = []
    @held_stock_ids = []
    @pie.etfs.each do |etf|
      @current_alloc.push(etf)
      @held_etf_ids.push(etf.id)
    end
    
    @pie.stocks.each do |stock|
      @current_alloc.push(stock)
      @held_stock_ids.push(stock.id)
    end    
    
    # Find ETFs and Stocks based on ESG preferences
    @etfs = Etf.find_best(@pie.user.setting).paginate(:page => params[:page])
    @stocks = Stock.find_best(@pie.user.setting).paginate(:page => params[:page])
  end
  
  def update_allocation
    @pie = Pie.find(params[:id])   
    @held_etf_ids = []
    @held_stock_ids = []
    @pie.etfs.each do |etf|
      @held_etf_ids.push(etf.id)
    end
    
    @pie.stocks.each do |stock|
      @held_stock_ids.push(stock.id)
    end    
    
    @stocks_to_add = []
    @stocks_to_delete = []
    @etfs_to_add = []
    @etfs_to_delete = []
    
    # Look for add_etf_#, remove_etf_#, add_stock_#, remove_stock_#
    params.keys().each do |key|
      fields = key.split('_')
      uid = fields[2].to_i
      
      if 'add' == fields[0]
        if 'stock' == fields[1]
          unless @held_stock_ids.include?(uid)
            # This is a new stock - add it
            @stocks_to_add.push(Stock.find(uid))
          end
        else
          unless @held_etf_ids.include?(uid)
            @etfs_to_add.push(Etf.find(uid))
          end
        end
      else
        if 'stock' == fields[1]
          if @held_stock_ids.include?(uid)
            # This is a new stock - add it
            @stocks_to_delete.push(Stock.find(uid))
          end
        else
          if @held_etf_ids.include?(uid)
            @etfs_to_delete.push(Etf.find(uid))
          end
        end
      end
    end
    
    # Make sure we don't have more than the max
    total = @held_etf_ids.count + @held_stock_ids.count + 
            @stocks_to_add.count + @etfs_to_add.count -
            @stocks_to_delete.count - @etfs_to_delete.count

    if total > Pie::MAX_EQUITIES
      redirect_to edit_allocation_py_path(@pie), :alert => t('too_many', :max_equities => Pie::MAX_EQUITIES), :format => 'html'
    else
      unless @stocks_to_add.empty?
        @pie.stocks << @stocks_to_add
      end
      
      unless @etfs_to_add.empty?
        @pie.etfs << @etfs_to_add
      end
      
      @stocks_to_delete.each do |s|
        @pie.stocks.delete(s)
      end
      
      @etfs_to_delete.each do |e|
        @pie.etfs.delete(e)
      end
      
      redirect_to edit_allocation_py_path(@pie), :notice => t('pie_updated'), :format => 'html'
    end
  end

  # Model portfolios
  def index
    @models = Pie.where(:user_id => nil)
  end

  def copy
    @pie = Pie.find(params[:id])   
    @src = Pie.find(params[:src])
    
    @pie.update_attributes(:pct_gold => @src.pct_gold, 
                           :pct_crypto => @src.pct_crypto,
                           :pct_cash => @src.pct_cash,
                           :pct_equities => @src.pct_equities)

    if @src.crypto.nil?
      @pie.crypto.reset
    else
      @pie.crypto.update_attributes(:pct_curr1 => @src.crypto.pct_curr1, 
                                    :pct_curr2 => @src.crypto.pct_curr2,
                                    :pct_curr3 => @src.crypto.pct_curr3)
    end
    
    if @src.stable_coin.nil?
      @pie.stable_coin.reset
    else
      @pie.stable_coin.update_attributes(:pct_curr1 => @src.stable_coin.pct_curr1, 
                                         :pct_curr2 => @src.stable_coin.pct_curr2,
                                         :pct_curr3 => @src.stable_coin.pct_curr3)
    end
    @pie.etfs.delete_all
    @pie.stocks.delete_all
    
    @pie.etfs << @src.etfs unless 0 == @src.etfs.count
    @pie.stocks << @src.stocks unless 0 == @src.stocks.count
                     
    redirect_to edit_py_path(@pie), :notice => "Copied #{@src.name}"
  end

  def deposit_collateral
    @pie = Pie.find(params[:id])
    
    snap = YAML::load(@pie.uma_snapshot)
    
    snap[:net_collateral_adjustment] += params[:amount].to_i
    @pie.update_attribute(:uma_snapshot, YAML::dump(snap))
    
    @collateralization, @progress_class, @total_value = @pie.compute_uma_collateralization
    
    respond_to do |format|       
      format.js do
         render :json => {:collateralization => @collateralization,
                          :progress_class => @progress_class,
                          :adjustments => snap[:net_collateral_adjustment],
                          :total_value => @total_value}
      end
      format.html { redirect_to root_path }     
    end             
  end
  
  def withdraw_collateral
    @pie = Pie.find(params[:id])
    
    snap = YAML::load(@pie.uma_snapshot)

    # They can't withdraw so much that the collateralization falls below the minimum!     
    snap[:net_collateral_adjustment] -= params[:amount].to_i    
    @collateralization, @progress_class, @total_value = @pie.compute_uma_collateralization(snap[:net_collateral_adjustment])
    
    if @collateralization >= MIN_COLLATERALIZATION * 100
      @pie.update_attribute(:uma_snapshot, YAML::dump(snap))
    else
      raise 'You cannot withdraw so much that the collateralization falls below the minimum!'
    end
    
    respond_to do |format|       
      format.js do
         render :json => {:collateralization => @collateralization,
                          :progress_class => @progress_class,
                          :adjustments => snap[:net_collateral_adjustment],
                          :total_value => @total_value}
      end
      format.html { redirect_to root_path }     
    end             
  end
  
  # For a $500 investment, at a collateralization of 1.75, the intial deposit would be 875
  # They would get 500 synthetic tokens for 875 Dai, for instance
  # If they redeem 200 tokens, they should get back 200*1.75 = 350
  # This only gets called if the redemption succeeds
  def redeem_tokens
    @pie = Pie.find(params[:id])
    
    snap = YAML::load(@pie.uma_snapshot)
    
    snap[:net_collateral_adjustment] += params[:amount].to_i * MIN_COLLATERALIZATION
    @pie.update_attribute(:uma_snapshot, YAML::dump(snap))
    
    @collateralization, @progress_class, @total_value = @pie.compute_uma_collateralization
    
    respond_to do |format|       
      format.js do
         render :json => {:collateralization => @collateralization,
                          :progress_class => @progress_class,
                          :adjustments => snap[:net_collateral_adjustment],
                          :total_value => @total_value}
      end
      format.html { redirect_to root_path }     
    end             
  end 
  
  def synthetics_index    
  end
  
  def balancer_index
  end
    
private
  def pie_params
    params.require(:pie).permit(:pct_gold, :pct_cash, :pct_crypto, :pct_equities, :name, :uma_collateral,
                                :uma_token_name, :uma_expiry_date,
                                :crypto_attributes => [:id, :pct_curr1, :pct_curr2, :pct_curr3],
                                :stable_coin_attributes => [:id, :pct_curr1, :pct_curr2, :pct_curr3])
  end
  
  def no_pool
    unless current_user.pie.balancer_pool.bp_address.nil?
      redirect_to root_path, :alert => t('no_edit_allocation')
    end
  end
end
