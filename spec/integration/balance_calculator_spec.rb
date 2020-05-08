require 'balance_calculator'
require 'rails_helper'

RSpec.describe 'BalanceCalculator' do

  let(:pie) { FactoryBot.create(:pie) }
  
  describe "Calculate with no input" do
    let(:calc) { BalanceCalculator.new(pie, {}, 10000) }
    
    it "should generate 'list empty'" do
      expect(calc.calculate).to be == {:result => false, 
                                       :errors => [{:msg => BalanceCalculator::COIN_LIST_EMPTY}]}
    end
  end  
  
  describe "Calculate with invalid initial investment" do
    [nil, 0, -1000].each do |investment|
      let(:calc) { BalanceCalculator.new(pie, {:usdc => 2000}, 10000) }

      it "should generate 'invalid investment'" do
        expect(calc.calculate).to be == {:result => false, 
                                         :errors => [{:msg => BalanceCalculator::INVALID_INVESTMENT}]}
      end      
    end
  end

  describe "Calculate with missing pie" do
    let(:calc) { BalanceCalculator.new(nil, {:usdc => 2000}, 10000) }

    it "should generate 'invalid pie'" do
      expect(calc.calculate).to be == {:result => false, 
                                       :errors => [{:msg => BalanceCalculator::INVALID_PIE}]}
    end
  end

  describe "Calculate with invalid pie" do
    let(:calc) { BalanceCalculator.new(pie, {:usdc => 2000}, 10000) }
    
    before { pie.pct_gold = 120 }
    
    it "should generate 'invalid pie'" do
      expect(calc.calculate).to be == {:result => false, 
                                       :errors => [{:msg => BalanceCalculator::INVALID_PIE}]}
    end
  end

=begin  
  describe "Should return insufficient funds if missing USDT" do
    let(:user) { FactoryBot.create(:user) }
    let(:setting) { FactoryBot.create(:setting, :user => user) }
    let(:pie) { FactoryBot.create(:usdt_pie, :user => user) }
    let(:calc) { BalanceCalculator.new(pie, {:usdc => 2000}, 10000) }
    
    it "should generate 'insufficient funds - no USDT'" do
      expect(calc.calculate[:result]).to be false
      expect(calc.calculate[:errors[0][:msg]]).to match(BalanceCalculator::INSUFFICIENT_FUNDS)
      expect(calc.calculate[:errors[0][:msg]]).to match("USDT")
    end    
  end

  describe "Should return insufficient funds if not enough USDT" do
    let(:user) { FactoryBot.create(:user) }
    let(:setting) { FactoryBot.create(:setting, :user => user) }
    let(:pie) { FactoryBot.create(:usdt_pie, :user => user) }
    let(:calc) { BalanceCalculator.new(pie, {:usdt => 2000}, 10000) }
    
    it "should generate 'insufficient funds - not enough USDT'" do
      expect(calc.calculate[:result]).to be false
      expect(calc.calculate[:errors[0][:msg]]).to match(BalanceCalculator::INSUFFICIENT_FUNDS)
      expect(calc.calculate[:errors[0][:msg]]).to match("USDT")
    end    
  end
=end
end
