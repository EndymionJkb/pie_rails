# == Schema Information
#
# Table name: etfs
#
#  id              :bigint           not null, primary key
#  ticker          :string(32)       not null
#  fund_name       :string(128)      not null
#  forecast_e      :decimal(8, 4)
#  forecast_s      :decimal(8, 4)
#  forecast_g      :decimal(8, 4)
#  esg_performance :decimal(8, 4)
#  alpha           :decimal(10, 6)
#  benchmark       :decimal(10, 6)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class Etf < ApplicationRecord
end
