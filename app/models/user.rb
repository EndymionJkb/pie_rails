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
         
  DEFAULT_E = 34
  DEFAULT_S = 33
  DEFAULT_G = 33
  
  has_one :setting
  
  def ensure_setting
    if setting.nil?
      setting = self.create_setting(:e_priority => 33, :s_priority => 33, :g_priority => 33)
    end
  end
end
