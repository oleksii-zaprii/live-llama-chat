class Message < ApplicationRecord
  belongs_to :conversation

  SENDER_TYPES = %w[customer ai agent].freeze

  validates :body, presence: true
  validates :sender_type, inclusion: { in: SENDER_TYPES }

  after_create :touch_conversation_activity

  scope :chronological, -> { order(created_at: :asc) }

  def customer? = sender_type == "customer"
  def ai?       = sender_type == "ai"
  def agent?    = sender_type == "agent"

  private

  def touch_conversation_activity
    conversation.touch_activity!
  end
end
