# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :recoverable, :rememberable, :validatable, :invitable,
         :two_factor_authenticatable, :lockable,
         otp_secret_encryption_key: ENV.fetch('OTP_ENCRYPTION_KEY', nil)

  enum :role, { harvester: 0, admin: 1 }

  validates :username, length: { minimum: 2 }

  # last_edited_by
  has_many(
    :pipelines, foreign_key: 'last_edited_by_id', inverse_of: :last_edited_by, dependent: :nullify
  )
  has_many(
    :extraction_definitions, foreign_key: 'last_edited_by_id', inverse_of: :last_edited_by, dependent: :nullify
  )
  has_many(
    :transformation_definitions, foreign_key: 'last_edited_by_id', inverse_of: :last_edited_by, dependent: :nullify
  )

  # Scoping method for access to automations
  def accessible_automations
    # Admins can access all automations
    return Automation.all if admin?
    
    # For regular users, scope based on the organization's data access policies
    # If there's no specific relationship, we return all automations but leave the method
    # in place so that access control can be refined in the future
    Automation.all
  end
end
