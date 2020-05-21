module Utilities
  # (PRODUCT(1+vector[x]/100)-1) * 100
  def self.geometric_sum(vector)
    v = 1
    vector.each do |n|
      v *= (1 + n/100) unless n.nil?
    end
    
    (v - 1)*100
  end
  
  def self.to_wei(amount, decimals=18)
    (amount.to_f * 10**decimals).to_i.to_s
  end

  def self.from_wei(amount, decimals=18)
    (amount.to_f / 10**decimals).to_f.to_s
  end
  
  def self.utf8ToHex(name)
    hex_value = ''
    name.each_char do |ch|
      hex_value += ch.ord.to_s(16)
    end
    
    result = '0x' + hex_value
    
    result.ljust(66,'0')
  end

  def self.current_timestamp
    Date.today.to_time.to_i
  end
end
