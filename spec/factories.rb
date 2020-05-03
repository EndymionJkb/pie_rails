FactoryBot.define do
  Faker::Config.locale = 'en-US'
  
  sequence(:random_email) { |n| Faker::Internet.email }
  sequence(:random_sentence) { |n| Faker::Lorem.sentence }
  sequence(:random_country) { |n| Faker::Address.country }
  sequence(:random_city) { |n| Faker::Address.city }
  sequence(:random_state) { |n| Faker::Address.state }
  sequence(:random_zipcode) { |n| Faker::Address.zip_code }
  sequence(:random_plus4) { |n| Faker::PhoneNumber.subscriber_number }
  sequence(:random_street_address) { |n| Faker::Address.street_address }
  sequence(:random_phone) { |n| "(#{Faker::PhoneNumber.area_code}) #{Faker::PhoneNumber.exchange_code}-#{Faker::PhoneNumber.subscriber_number}"}
  sequence(:random_alphanumeric) { |n| Faker::Alphanumeric.alphanumeric(:number => 12) }
  sequence(:random_first_name) { |n| Faker::Name.first_name }
  sequence(:random_last_name) { |n| Faker::Name.last_name }
  sequence(:next_number) { |n| n }
  sequence(:random_university) { |n| Faker::University.name }
  sequence(:random_academic_major) { |n| Faker::Educator.subject }
  sequence(:random_degree) { |n| Faker::Educator.degree }
  sequence(:random_academic_course) { |n| Faker::Educator.course_name }
  sequence(:random_past_date) { |n| Faker::Date.between(from: 10.year.ago, to: Date.today) }
  sequence(:random_future_date) { |n| Faker::Date.between(from: 1.month.from_now, to: 2.years.from_now) }
  sequence(:random_product) { |n| Faker::Commerce.product_name }
  sequence(:random_department) { |n| Faker::Commerce.department(max: 1, fixed_amount: true) }
  sequence(:random_paragraph) { |n| Faker::Lorem.paragraph }
  sequence(:random_url) { |n| Faker::Internet.url }
  sequence(:random_eth_address) { |n| Faker::Blockchain::Ethereum.address }
  
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
    
    name { generate(:random_product) }
  end

  factory :balancer_pool do
    pie
    
    uma_address { generate(:random_eth_address) }
    bp_address { generate(:random_eth_address) }
    uma_expiry { generate(:random_future_date) }
    allocation { generate(:random_paragraph) }
  end    

  factory :price_history do
    coin { ["BTC", "ETH", "LINK", "PAXG"].sample }
    date { generate(:random_past_date) }
    price { Random.rand() * 5000 + 1 }
  end
end
