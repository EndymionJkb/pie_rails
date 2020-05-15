# == Schema Information
#
# Table name: uma_expiry_dates
#
#  id         :bigint           not null, primary key
#  date_str   :string(16)       not null
#  unix       :string(16)       not null
#  ordinal    :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class UmaExpiryDate < ApplicationRecord
  validates_presence_of :date_str, :unix
  validates_length_of :date_str, :unix, :maximum => 16
  validates_numericality_of :ordinal, :only_integer => true, :greater_than => 0
  
  def self.default_scope
    order(:unix)
  end
end
