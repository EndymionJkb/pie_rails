module Utilities
  # (PRODUCT(1+vector[x]/100)-1) * 100
  def self.geometric_sum(vector)
    v = 1
    vector.each do |n|
      v *= (1 + n/100) unless n.nil?
    end
    
    (v - 1)*100
  end
end
