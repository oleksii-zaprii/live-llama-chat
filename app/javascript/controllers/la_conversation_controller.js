import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["messages", "textarea"]
  static values = {
    conversationId: Number,
    sendMessageUrl: String
  }

  connect() {
    this.scrollToBottom()

    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      { channel: "LaConversationChannel", conversation_id: this.conversationIdValue },
      { received: (data) => this.received(data) }
    )
  }

  disconnect() {
    this.subscription?.unsubscribe()
    this.consumer?.disconnect()
  }

  received(data) {
    if (data.type === "message") {
      this.appendMessage(data.message)
    }
  }

  submitMessage(event) {
    event.preventDefault()

    const body = this.textareaTarget.value.trim()
    if (!body) return

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    const submitButton = this.element.querySelector('button[type="submit"]')
    if (submitButton) submitButton.disabled = true

    fetch(this.sendMessageUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": csrfToken,
        Accept: "application/json"
      },
      credentials: "same-origin",
      body: new URLSearchParams({ body })
    })
      .then((response) => {
        if (response.ok) {
          this.textareaTarget.value = ""
          this.textareaTarget.style.height = "auto"
        }
      })
      .finally(() => {
        if (submitButton) submitButton.disabled = false
      })
  }

  keydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.submitMessage(event)
    }
  }

  resizeTextarea() {
    this.textareaTarget.style.height = "auto"
    this.textareaTarget.style.height = `${Math.min(this.textareaTarget.scrollHeight, 120)}px`
  }

  appendMessage(msg) {
    if (document.getElementById(`message-${msg.id}`)) return

    const div = document.createElement("div")
    div.id = `message-${msg.id}`
    div.className = `la-message la-message--${msg.sender_type}`
    div.innerHTML = `
      <div class="la-message-bubble">
        <span class="la-message-sender">${this.senderLabel(msg.sender_type)}</span>
        <p class="la-message-body">${this.escapeHtml(msg.body)}</p>
        <span class="la-message-time">${this.formatTime(msg.created_at)}</span>
      </div>
    `

    this.messagesTarget.appendChild(div)
    this.scrollToBottom()
  }

  scrollToBottom() {
    if (this.hasMessagesTarget) {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    }
  }

  senderLabel(type) {
    return { customer: "Customer", ai: "AI Assistant", agent: "You" }[type] || type
  }

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }

  formatTime(iso) {
    return new Date(iso).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
  }
}
