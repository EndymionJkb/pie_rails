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
require 'rails_helper'

RSpec.describe PriceIdentifier, type: :model do
  let(:price) { FactoryBot.create(:price_identifier) }
  let(:pie) { FactoryBot.create(:pie) }
  let(:assigned_price) { FactoryBot.create(:assigned_price_identifier, :pie => pie) }
  
  subject { assigned_price }
  
  it "should respond to everything" do
    expect(price).to respond_to(:whitelisted)
  end
  
  it { should be_valid }
  
  its(:pie) { should be == pie }
  
  describe "Missing whitelisted address" do
    before { assigned_price.whitelisted = nil }
    
    it { should_not be_valid }
  end
  
  it "Should allow unassigned" do
    expect(price.pie).to be_nil
    expect(price.valid?).to be true
  end
end
