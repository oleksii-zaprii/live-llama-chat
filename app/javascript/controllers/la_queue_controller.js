import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["list", "empty", "badge", "count"]

  connect() {
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      { channel: "LaQueueChannel" },
      { received: (data) => this.handleQueueUpdate(data) }
    )
  }

  disconnect() {
    this.subscription?.unsubscribe()
    this.consumer?.disconnect()
  }

  acceptChat(event) {
    event.preventDefault()
    const button = event.currentTarget
    const url = button.dataset.acceptUrl
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    button.disabled = true
    button.textContent = "Accepting..."

    fetch(url, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": csrfToken,
        Accept: "text/html"
      },
      credentials: "same-origin"
    }).then((response) => {
      if (response.redirected) {
        window.location.href = response.url
      } else {
        button.disabled = false
        button.textContent = "Accept Chat"
      }
    })
  }

  handleQueueUpdate(data) {
    if (data.type !== "queue_update") return

    if (data.action === "add") {
      this.addQueueCard(data)
    } else if (data.action === "remove") {
      this.removeQueueCard(data.conversation_id)
    }
  }

  addQueueCard(data) {
    if (this.hasEmptyTarget) this.emptyTarget.remove()

    if (document.getElementById(`queue-conv-${data.conversation_id}`)) return

    const card = document.createElement("div")
    card.className = "la-queue-card la-queue-card--new"
    card.id = `queue-conv-${data.conversation_id}`
    card.innerHTML = `
      <div class="la-queue-card-header">
        <div class="la-customer-avatar">${this.initial(data.customer_name)}</div>
        <div class="la-customer-info">
          <span class="la-customer-name">${this.escapeHtml(data.customer_name || "Anonymous")}</span>
          <span class="la-customer-email">${this.escapeHtml(data.customer_email || "No email provided")}</span>
        </div>
        <span class="la-status-pill la-status-pill--waiting">Waiting</span>
      </div>
      <div class="la-queue-card-meta">
        <span class="la-wait-time">Just now</span>
      </div>
      <div class="la-queue-card-actions">
        <button type="button" class="la-btn la-btn-sm la-btn-primary" data-action="click->la-queue#acceptChat" data-accept-url="/la/conversations/${data.conversation_id}/accept">Accept Chat</button>
      </div>
    `

    this.listTarget.insertBefore(card, this.listTarget.firstChild)
    setTimeout(() => card.classList.remove("la-queue-card--new"), 50)
    this.updateCounts(1)
  }

  removeQueueCard(conversationId) {
    const card = document.getElementById(`queue-conv-${conversationId}`)
    if (!card) return

    card.style.opacity = "0"
    card.style.transform = "translateX(20px)"
    setTimeout(() => {
      card.remove()
      if (this.listTarget.children.length === 0) {
        this.showEmptyState()
      }
    }, 300)

    this.updateCounts(-1)
  }

  showEmptyState() {
    const empty = document.createElement("div")
    empty.className = "la-empty-state"
    empty.id = "queue-empty"
    empty.dataset.laQueueTarget = "empty"
    empty.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1" stroke="currentColor" class="la-empty-icon">
        <path stroke-linecap="round" stroke-linejoin="round" d="M8.625 9.75a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm0 0H8.25m4.125 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm0 0H12m4.125 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm0 0h-.375m-13.5 3.01c0 1.6 1.123 2.994 2.707 3.227 1.087.16 2.185.283 3.293.369V21l4.184-4.183a1.14 1.14 0 0 1 .778-.332 48.294 48.294 0 0 0 5.83-.498c1.585-.233 2.708-1.626 2.708-3.228V6.741c0-1.602-1.123-2.995-2.707-3.228A48.394 48.394 0 0 0 12 3c-2.392 0-4.744.175-7.043.513C3.373 3.746 2.25 5.14 2.25 6.741v6.018Z" />
      </svg>
      <p>No customers waiting</p>
      <span>New chats will appear here automatically</span>
    `
    this.listTarget.appendChild(empty)
  }

  updateCounts(delta) {
    if (this.hasBadgeTarget) {
      const current = parseInt(this.badgeTarget.textContent || "0", 10)
      this.badgeTarget.textContent = Math.max(0, current + delta)
    }
    if (this.hasCountTarget) {
      const current = parseInt(this.countTarget.textContent || "0", 10)
      this.countTarget.textContent = Math.max(0, current + delta)
    }
  }

  initial(name) {
    return (name || "?")[0].toUpperCase()
  }

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
