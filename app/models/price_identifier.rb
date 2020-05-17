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
# Represents a currently whitelisted PriceIdentifier
# All new synthetics need to have a PriceIdentifier for the DVM
# Since each Synthetic tracks different things, the price identifiers will all be different
# Plan is to whitelist them in batches, then assign them
class PriceIdentifier < ApplicationRecord
  # If there is no pie "owner", it is unassigned
  belongs_to :pie, :optional => true
  
  validates_presence_of :whitelisted
end
