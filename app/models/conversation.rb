class Conversation < ApplicationRecord
  belongs_to :assigned_agent, class_name: "User", foreign_key: :assigned_agent_id, optional: true
  has_many :messages, dependent: :destroy

  STATUSES = %w[ai_managed awaiting_agent agent_managed closed].freeze

  # Keywords that immediately trigger human handover (deterministic override before AI)
  HANDOVER_KEYWORDS = %w[
    human representative lawyer agent speak talk person
    supervisor manager escalate escalation help
  ].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :session_token, presence: true, uniqueness: true

  before_validation :generate_session_token, on: :create
  before_create { self.last_activity_at = Time.current }

  scope :ai_managed, -> { where(status: "ai_managed") }
  scope :awaiting_agent, -> { where(status: "awaiting_agent") }
  scope :agent_managed, -> { where(status: "agent_managed") }
  scope :active, -> { where.not(status: "closed") }
  scope :timed_out, -> { where(status: %w[awaiting_agent agent_managed]).where("last_activity_at < ?", 10.minutes.ago) }

  def ai_managed?   = status == "ai_managed"
  def awaiting_agent? = status == "awaiting_agent"
  def agent_managed? = status == "agent_managed"
  def closed?       = status == "closed"

  def touch_activity!
    update_column(:last_activity_at, Time.current)
  end

  def trigger_handover!
    update!(status: "awaiting_agent", assigned_agent_id: nil)
  end

  def accept_by!(agent)
    update!(status: "agent_managed", assigned_agent_id: agent.id)
  end

  def close!
    update!(status: "closed")
  end

  # Deterministic check — runs BEFORE sending to AI
  def self.triggers_handover?(text)
    normalized = text.downcase
    HANDOVER_KEYWORDS.any? { |kw| normalized.include?(kw) }
  end

  private

  def generate_session_token
    self.session_token ||= SecureRandom.urlsafe_base64(32)
  end
end
