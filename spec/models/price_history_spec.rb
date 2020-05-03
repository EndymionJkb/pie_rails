# == Schema Information
#
# Table name: price_histories
#
#  id         :bigint           not null, primary key
#  coin       :string(8)        not null
#  date       :date             not null
#  price      :decimal(8, 2)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require 'rails_helper'

RSpec.describe PriceHistory, type: :model do
  let(:history) { FactoryBot.create(:price_history) }
  
  subject { history }
  
  it "should respond to everything" do
    expect(history).to respond_to(:coin)
    expect(history).to respond_to(:date)
    expect(history).to respond_to(:price)
  end
  
  it { should be_valid }
  
  describe "missing coin" do
    before { history.coin = nil }
    
    it { should_not be_valid }
  end

  describe "missing date" do
    before { history.date = nil }
    
    it { should_not be_valid }
  end

  describe "invalid price" do
    [nil, -1].each do |price|
      before { history.price = price }
      
      it { should_not be_valid }
    end
  end
end
