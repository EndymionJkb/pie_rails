# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  reset_password_token   :string
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
           
  has_one :setting
  has_one :pie
  
  def ensure_setting
    if setting.nil?
      setting = self.create_setting(:e_priority => Setting::DEFAULT_E,
                                    :s_priority => Setting::DEFAULT_S,
                                    :g_priority => Setting::DEFAULT_G)
    end
  end
  
  def ensure_pie
    if pie.nil?
      pie = self.create_pie(:pct_gold => Pie::DEFAULT_PCT_GOLD,
                            :pct_crypto => Pie::DEFAULT_PCT_CRYPTO,
                            :pct_cash => Pie::DEFAULT_PCT_CASH,
                            :pct_equities => Pie::DEFAULT_PCT_EQUITIES)
                            
      pie.create_crypto(:pct_curr1 => Crypto::DEFAULT_PCT_CURR1,
                        :pct_curr2 => Crypto::DEFAULT_PCT_CURR1,
                        :pct_curr3 => Crypto::DEFAULT_PCT_CURR1)
                        
      pie.create_stable_coin(:pct_curr1 => StableCoin::DEFAULT_PCT_CURR1,
                             :pct_curr2 => StableCoin::DEFAULT_PCT_CURR1,
                             :pct_curr3 => StableCoin::DEFAULT_PCT_CURR1)
    end
  end
end
