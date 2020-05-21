# == Schema Information
#
# Table name: price_identifiers
#
#  id          :bigint           not null, primary key
#  pie_id      :bigint
#  whitelisted :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class PriceIdentifier < ApplicationRecord
  # If there is no pie "owner", it is unassigned
  belongs_to :pie, :optional => true
  
  validates_presence_of :whitelisted
end
