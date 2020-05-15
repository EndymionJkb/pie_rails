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
require 'rails_helper'

RSpec.describe UmaExpiryDate, type: :model do
  let(:expiry) { FactoryBot.create(:uma_expiry_date) }
  
  subject { expiry }
  
  it "should respond to everything" do
    expect(expiry).to respond_to(:date_str)
    expect(expiry).to respond_to(:unix)
    expect(expiry).to respond_to(:ordinal)
  end
  
  it { should be_valid }
  
  describe "Missing date_str" do
    before { expiry.date_str = nil }
    
    it { should_not be_valid }
  end

  describe "date_str too long" do
    before { expiry.date_str = 'd'*17 }
    
    it { should_not be_valid }
  end

  describe "Missing unix" do
    before { expiry.unix = nil }
    
    it { should_not be_valid }
  end

  describe "unix too long" do
    before { expiry.unix = 'd'*17 }
    
    it { should_not be_valid }
  end
  
  describe "Invalid ordinal" do
    [nil, 0, -1, 2.5, 'abc'].each do |ord|
      before { expiry.ordinal = ord }
      
      it { should_not be_valid }
    end
  end
end
