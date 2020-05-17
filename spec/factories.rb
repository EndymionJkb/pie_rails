FactoryBot.define do
  Faker::Config.locale = 'en-US'
  
  sequence(:random_email) { |n| Faker::Internet.email }
  sequence(:random_sentence) { |n| Faker::Lorem.sentence }
  sequence(:random_alphanumeric) { |n| Faker::Alphanumeric.alphanumeric(:number => 12) }
  sequence(:random_past_date) { |n| Faker::Date.between(from: 10.year.ago, to: Date.today) }
  sequence(:random_future_date) { |n| Faker::Date.between(from: 1.month.from_now, to: 2.years.from_now) }
  sequence(:random_paragraph) { |n| Faker::Lorem.paragraph }
  sequence(:random_url) { |n| Faker::Internet.url }
  sequence(:random_eth_address) { |n| Faker::Blockchain::Ethereum.address }
  sequence(:random_coin) { |n| Faker::Name.initials }
  sequence(:random_product) { |n| Faker::Commerce.product_name }
  
  factory :user do
    email { generate(:random_email) }
    password { generate(:random_sentence) }
    password_confirmation { "#{password}" }
  end
  
  factory :pie do
    user 
    
    pct_gold { Random.rand(100) }
    pct_cash { Random.rand(100) }
    pct_crypto { Random.rand(100) }
    pct_equities { Random.rand(100) }
    uma_expiry_date { generate(:random_future_date) }
    name { generate(:random_product) }
    
    factory :usdt_pie do
      pct_gold { 0 }
      pct_cash { 100 }
      pct_crypto { 0 }
      pct_equities { 0 }

      after :create do |pie|
        create :stable_coin, :pie => pie, :pct_curr1 => 0, :pct_curr2 => 0, :pct_curr3 => 100
      end
    end
    
    after :create do |pie|
      create :stable_coin, :pie => pie
      create :crypto, :pie => pie
    end
  end
  
  factory :setting do 
    user 
    
    e_priority { Random.rand(100) }
    s_priority { Random.rand(100) }
    g_priority { Random.rand(100) }
    
    focus { 'Large Cap' }
    stable_coins { 'USDC,DAI,USDT' }
  end
  
  factory :stable_coin do
    pie
    
    pct_curr1 { Random.rand(100) }
    pct_curr2 { Random.rand(100) }
    pct_curr3 { Random.rand(100) }
  end

  factory :crypto do
    pie
    
    pct_curr1 { Random.rand(100) }
    pct_curr2 { Random.rand(100) }
    pct_curr3 { Random.rand(100) }
  end
  
  factory :balancer_pool do
    pie
    
    uma_address { generate(:random_eth_address) }
    bp_address { generate(:random_eth_address) }
    allocation { generate(:random_paragraph) }
  end    

  factory :price_history do
    coin { ["BTC", "ETH", "LINK", "PAXG"].sample }
    date { generate(:random_past_date) }
    price { Random.rand() * 5000 + 1 }
  end

  factory :coin_info do
    coin { generate(:random_coin) }
    address { generate(:random_eth_address) }
  end
  
  factory :uma_expiry_date do
    date_str { ['6/1/2020','7/1/2020','8/1/2020'].sample }
    unix { generate(:random_alphanumeric) }
    ordinal { Random.rand(16) + 1 }
  end  

  factory :price_identifier do
    whitelisted { generate(:random_alphanumeric) }
    
    factory :assigned_price_identifier do
      pie
    end
  end
end
