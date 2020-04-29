# == Schema Information
#
# Table name: stocks
#
#  id           :bigint           not null, primary key
#  cca_id       :bigint           not null
#  run_date     :date             not null
#  company_name :string(128)      not null
#  sector       :string(64)       not null
#  forecast_e   :decimal(8, 4)
#  forecast_s   :decimal(8, 4)
#  forecast_g   :decimal(8, 4)
#  alpha        :decimal(8, 4)
#  m1_return    :float
#  m3_return    :float
#  m6_return    :float
#  y1_return    :float
#  price        :decimal(10, 4)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class Stock < ApplicationRecord
  ESG_WEIGHT = 0.8
  FORECAST_WEIGHT = 0.15
  PERFORMANCE_WEIGHT = 0.05
  EPSILON = 0.01

  validates_presence_of :company_name, :sector
  validates_length_of :company_name, :maximum => 128
  validates_length_of :sector, :maximum => 64
  
  validates_numericality_of :forecast_e, :forecast_s, :forecast_g, :alpha, :m1_return, :m3_return, :m6_return, :y1_return

  def self.find_best(setting, top_n=250)
    min_e, max_e = Stock.all.minimum(:forecast_e), Stock.all.maximum(:forecast_e)
    min_s, max_s = Stock.all.minimum(:forecast_s), Stock.all.maximum(:forecast_s)
    min_g, max_g = Stock.all.minimum(:forecast_g), Stock.all.maximum(:forecast_g)
    min_alpha, max_alpha = Stock.all.minimum(:alpha), Stock.all.maximum(:alpha)
    min_m1, max_m1 = Stock.all.minimum(:m1_return), Stock.all.maximum(:m1_return)
    min_m3, max_m3 = Stock.all.minimum(:m3_return), Stock.all.maximum(:m3_return)
    min_m6, max_m6 = Stock.all.minimum(:m6_return), Stock.all.maximum(:m6_return)
    min_y1, max_y1 = Stock.all.minimum(:y1_return), Stock.all.maximum(:y1_return)
    e_range = max_e - min_e
    s_range = max_s - min_s
    g_range = max_g - min_g
    alpha_range = max_alpha - min_alpha
    m1_range = max_m1 - min_m1
    m3_range = max_m3 - min_m3
    m6_range = max_m6 - min_m6
    y1_range = max_y1 - min_y1
    
    # avoid division by zero
    e_range = EPSILON if 0 == e_range
    s_range = EPSILON if 0 == s_range
    g_range = EPSILON if 0 == g_range
    alpha_range = EPSILON if 0 == alpha_range
    m1_range = EPSILON if 0 == m1_range
    m3_range = EPSILON if 0 == m3_range
    m6_range = EPSILON if 0 == m6_range
    y1_range = EPSILON if 0 == y1_range
    
    # 80% weight on ESG, 15% predicted alpha, 5% past performance
    # priorities are percentages, so max score is 100.    
    Stock.all.sort_by { |s| ((s.forecast_e - min_e)/e_range * setting.e_priority +
                             (s.forecast_s - min_s)/s_range * setting.s_priority +
                             (s.forecast_g - min_g)/g_range * setting.g_priority) * ESG_WEIGHT + 
                             (s.alpha - min_alpha)/alpha_range * 100 * FORECAST_WEIGHT * 
                             ((s.m1_return - min_m1)/m1_range * 0.05 + # weight shorter-term performance less
                              (s.m3_return - min_m3)/m3_range * 0.15 + 
                              (s.m6_return - min_m6)/m6_range * 0.2 +
                              (s.y1_return - min_y1)/y1_range * 0.6) * PERFORMANCE_WEIGHT}[0..top_n-1].reverse
  end
end
