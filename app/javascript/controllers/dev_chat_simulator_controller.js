import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["messages", "status", "input", "textarea", "sendButton", "startForm"]
  static values = {
    cableUrl: { type: String, default: "/cable" }
  }

  connect() {
    this.sessionToken = localStorage.getItem("dev_chat_session_token")
    if (this.sessionToken) {
      this.restoreSession()
    }
  }

  disconnect() {
    this.subscription?.unsubscribe()
    this.consumer?.disconnect()
  }

  startChat(event) {
    event.preventDefault()

    const formData = new FormData(this.startFormTarget)
    fetch("/api/conversations", {
      method: "POST",
      headers: { Accept: "application/json", "Content-Type": "application/json" },
      body: JSON.stringify({
        customer_name: formData.get("customer_name"),
        customer_email: formData.get("customer_email")
      })
    })
      .then((response) => response.json())
      .then((data) => {
        this.sessionToken = data.session_token
        localStorage.setItem("dev_chat_session_token", this.sessionToken)
        this.connectCable()
        this.syncFromServer()
        if (this.hasStartFormTarget) this.startFormTarget.style.display = "none"
        if (this.hasInputTarget) this.inputTarget.style.display = "block"
      })
  }

  restoreSession() {
    this.connectCable()
    this.syncFromServer()
    if (this.hasStartFormTarget) this.startFormTarget.style.display = "none"
    if (this.hasInputTarget) this.inputTarget.style.display = "block"
  }

  resetSession() {
    localStorage.removeItem("dev_chat_session_token")
    this.sessionToken = null
    this.subscription?.unsubscribe()
    this.consumer?.disconnect()
    if (this.hasMessagesTarget) this.messagesTarget.innerHTML = ""
    if (this.hasStartFormTarget) {
      this.startFormTarget.style.display = "block"
      this.startFormTarget.reset()
    }
    if (this.hasInputTarget) this.inputTarget.style.display = "none"
    if (this.hasStatusTarget) this.statusTarget.textContent = "Not connected"
  }

  connectCable() {
    this.subscription?.unsubscribe()
    this.consumer?.disconnect()

    this.consumer = createConsumer(this.cableUrlValue)
    this.subscription = this.consumer.subscriptions.create(
      { channel: "ConversationChannel", session_token: this.sessionToken },
      {
        connected: () => {
          if (this.hasStatusTarget) {
            this.statusTarget.textContent = "Connected — listening for replies"
          }
        },
        rejected: () => {
          if (this.hasStatusTarget) {
            this.statusTarget.textContent = "Connection rejected — click Reset Session and try again"
          }
        },
        received: (data) => this.received(data)
      }
    )
  }

  syncFromServer() {
    fetch(`/api/conversations/${this.sessionToken}/messages`, {
      headers: { Accept: "application/json" }
    })
      .then((response) => response.json())
      .then((data) => {
        if (data.error) {
          this.resetSession()
          return
        }

        if (this.hasMessagesTarget) this.messagesTarget.innerHTML = ""
        data.messages.forEach((message) => this.appendMessage(message))
        this.updateStatus(data.status)
      })
  }

  sendMessage(event) {
    event.preventDefault()

    const body = this.textareaTarget.value.trim()
    if (!body || !this.sessionToken) return

    const sendButton = this.element.querySelector('button[type="submit"]')
    if (sendButton) sendButton.disabled = true

    fetch(`/api/conversations/${this.sessionToken}/messages`, {
      method: "POST",
      headers: { Accept: "application/json", "Content-Type": "application/json" },
      body: JSON.stringify({ body })
    })
      .then((response) => response.json())
      .then((data) => {
        if (data.error) {
          if (this.hasStatusTarget) this.statusTarget.textContent = data.error
          return
        }

        this.textareaTarget.value = ""
        this.syncFromServer()
      })
      .finally(() => {
        if (sendButton) sendButton.disabled = false
      })
  }

  received(data) {
    if (data.type === "message" && data.message) {
      this.appendMessage(data.message)
      if (data.conversation_status) {
        this.updateStatus(data.conversation_status)
      }
    } else if (data.type === "session_closed" || data.type === "session_timeout") {
      if (this.hasStatusTarget) this.statusTarget.textContent = data.message
      this.appendSystemMessage(data.message)
    }
  }

  updateStatus(status) {
    if (this.hasStatusTarget && status) {
      this.statusTarget.textContent = `Connected — ${status.replaceAll("_", " ")}`
    }
  }

  appendMessage(msg) {
    if (document.getElementById(`message-${msg.id}`)) return

    const div = document.createElement("div")
    div.id = `message-${msg.id}`
    div.className = `dev-chat-message dev-chat-message--${msg.sender_type}`
    div.innerHTML = `
      <span class="dev-chat-sender">${this.senderLabel(msg.sender_type)}</span>
      <p class="dev-chat-body">${this.escapeHtml(msg.body)}</p>
    `
    this.messagesTarget.appendChild(div)
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  appendSystemMessage(text) {
    const div = document.createElement("div")
    div.className = "dev-chat-system"
    div.textContent = text
    this.messagesTarget.appendChild(div)
  }

  senderLabel(type) {
    return { customer: "You", ai: "AI Assistant", agent: "Loan Advocate" }[type] || type
  }

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
