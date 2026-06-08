class User < ApplicationRecord
  has_secure_password

  has_many :conversations, foreign_key: :assigned_agent_id, dependent: :nullify

  ROLES = %w[loan_advocate admin].freeze
  AVAILABILITY_STATUSES = %w[online busy offline].freeze

  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }
  validates :availability_status, inclusion: { in: AVAILABILITY_STATUSES }

  before_save { email.downcase! }
  before_create { self.availability_status ||= "offline" }

  scope :online, -> { where(availability_status: "online") }
  scope :loan_advocates, -> { where(role: "loan_advocate") }
  scope :available_agents, -> { loan_advocates.online }

  def loan_advocate?
    role == "loan_advocate"
  end

  def admin?
    role == "admin"
  end

  def online?
    availability_status == "online"
  end
end
