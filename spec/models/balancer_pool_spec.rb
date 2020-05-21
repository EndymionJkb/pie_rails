# == Schema Information
#
# Table name: balancer_pools
#
#  id              :bigint           not null, primary key
#  pie_id          :bigint
#  uma_address     :string(42)
#  bp_address      :string(42)
#  allocation      :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  swaps_completed :boolean          default(FALSE), not null
#  finalized       :boolean          default(FALSE), not null
#
require 'rails_helper'

RSpec.describe BalancerPool, type: :model do
  let(:pie) { FactoryBot.create(:pie) }
  let(:pool) { FactoryBot.create(:balancer_pool, :pie => pie) }
  
  subject { pool }

  it "should respond to everything" do
    expect(pool).to respond_to(:uma_address)
    expect(pool).to respond_to(:bp_address)
    expect(pool).to respond_to(:allocation)
    expect(pool).to respond_to(:balancer_url)
    expect(pool).to respond_to(:swaps_completed)
    expect(pool).to respond_to(:finalized)
  end
  
  it { should be_valid }
  
  its(:pie) { should be == pie }
  
  describe "Invalid uma_address" do
    before { pool.uma_address = 'A'*43 }
    
    it { should_not be_valid }
  end

  describe "Invalid bp_address" do
    before { pool.bp_address = 'A'*43 }
    
    it { should_not be_valid }
  end
  
  describe "Missing swaps_completed" do
    before { pool.swaps_completed = nil }
    
    it { should_not be_valid }
  end

  describe "Missing finalized" do
    before { pool.finalized = nil }
    
    it { should_not be_valid }
  end
end
