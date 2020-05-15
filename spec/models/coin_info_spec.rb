# == Schema Information
#
# Table name: coin_infos
#
#  coin       :string(8)        not null, primary key
#  address    :string(42)       not null
#  decimals   :integer          default(18), not null
#  used       :boolean          default(FALSE), not null
#  abi        :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require 'rails_helper'

RSpec.describe CoinInfo, type: :model do
  let(:contract) { FactoryBot.create(:coin_info) }
  
  subject { contract }
  
  it "should respond to everything" do
    expect(contract).to respond_to(:coin)
    expect(contract).to respond_to(:address)
    expect(contract).to respond_to(:decimals)
    expect(contract).to respond_to(:used)
    expect(contract).to respond_to(:abi)
  end
  
  it { should be_valid }
  
  it "should default to 18 decimals" do
    expect(contract.decimals).to eq(18)  
  end
  
  describe "Invalid decimals" do 
    [nil, 0, -1, 2.5].each do |d|
      before { contract.decimals = d }
      
      it { should_not be_valid }
    end  
  end
  
  describe "missing coin" do
    before { contract.coin = nil }
    
    it { should_not be_valid }
  end

  describe "coin too long" do
    before { contract.coin = 'C'*9 }
    
    it { should_not be_valid }
  end

  describe "missing address" do
    before { contract.address = nil }
    
    it { should_not be_valid }
  end

  describe "address too short" do
    before { contract.address = '0x3423423' }
    
    it { should_not be_valid }
  end

  describe "address too long" do
    before { contract.address = '0'*43 }
    
    it { should_not be_valid }
  end
end
