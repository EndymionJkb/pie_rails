# == Schema Information
#
# Table name: settings
#
#  id         :bigint           not null, primary key
#  user_id    :bigint
#  e_priority :integer          not null
#  s_priority :integer          not null
#  g_priority :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Setting < ApplicationRecord
  DEFAULT_E = 34
  DEFAULT_S = 33
  DEFAULT_G = 33

  belongs_to :user
  
  validates_numericality_of :e_priority, :s_priority, :g_priority, :only_integer => true, 
                            :greater_than_or_equal_to => 0, :less_than_or_equal_to => 100
end
