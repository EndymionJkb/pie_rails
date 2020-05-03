class PiesController < ApplicationController
  before_action :authenticate_user!
  
  def show
    current_user.ensure_pie
    
    @pie = current_user.pie
    
    @chart_data = @pie.build_chart 
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
    @to_copy = Pie.find(params[:src])
    
    redirect_to edit_py_path(@pie), :notice => "Copied #{@to_copy.name}"
  end
    
private
  def pie_params
    params.require(:pie).permit(:pct_gold, :pct_cash, :pct_crypto, :pct_equities, :name, 
                                :crypto_attributes => [:id, :pct_curr1, :pct_curr2, :pct_curr3],
                                :stable_coin_attributes => [:id, :pct_curr1, :pct_curr2, :pct_curr3])
  end
end
