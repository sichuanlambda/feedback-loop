import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "content"]
  
  connect() {
    // Set up initial state
    this.showLoadingSkeleton()
  }
  
  switchTab(event) {
    event.preventDefault()
    
    // Remove active class from all tabs
    this.element.querySelectorAll('.detail-tab').forEach(tab => {
      tab.classList.remove('active')
    })
    
    // Add active class to clicked tab
    event.target.classList.add('active')
    
    // Show loading skeleton while new content loads
    this.showLoadingSkeleton()
  }
  
  showLoadingSkeleton() {
    const contentFrame = document.querySelector('#building_detail_content')
    if (contentFrame) {
      contentFrame.innerHTML = `
        <div class="tab-skeleton loading">
          <div class="skeleton-card"></div>
          <div class="skeleton-text"></div>
          <div class="skeleton-text medium"></div>
          <div class="skeleton-text short"></div>
          <div class="skeleton-card"></div>
          <div class="skeleton-text"></div>
          <div class="skeleton-text medium"></div>
        </div>
      `
    }
  }
  
  // Called when turbo frame loads
  frameLoaded() {
    const skeleton = this.element.querySelector('.tab-skeleton')
    if (skeleton) {
      skeleton.classList.remove('loading')
      setTimeout(() => {
        if (skeleton.parentNode) {
          skeleton.parentNode.removeChild(skeleton)
        }
      }, 300)
    }
  }
}