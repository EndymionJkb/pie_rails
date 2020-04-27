# == Schema Information
#
# Table name: stocks
#
#  id           :bigint           not null, primary key
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
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class Stock < ApplicationRecord
  validates_presence_of :company_name, :sector
  validates_length_of :company_name, :maximum => 128
  validates_length_of :sector, :maximum => 64
  
  validates_numericality_of :forecast_e, :forecast_s, :forecast_g, :alpha, :m1_return, :m3_return, :m6_return, :y1_return
end
