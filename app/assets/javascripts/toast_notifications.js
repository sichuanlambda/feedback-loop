// Toast Notification System for Achievement Badges
class ToastNotificationManager {
  constructor() {
    this.createToastContainer();
    this.bindEvents();
  }

  createToastContainer() {
    if (document.querySelector('.toast-container')) return;
    
    const container = document.createElement('div');
    container.className = 'toast-container';
    document.body.appendChild(container);
  }

  bindEvents() {
    // Listen for achievement earned events
    document.addEventListener('achievement:earned', (event) => {
      this.showAchievementToast(event.detail);
    });

    // Listen for level up events
    document.addEventListener('level:up', (event) => {
      this.showLevelUpToast(event.detail);
    });
  }

  showAchievementToast(achievement) {
    const toast = this.createToast('achievement', {
      title: '🏆 Achievement Unlocked!',
      message: achievement.name,
      description: achievement.description,
      icon: achievement.icon,
      category: achievement.category,
      points: achievement.points
    });

    this.displayToast(toast);
    this.playAchievementSound();
  }

  showLevelUpToast(levelData) {
    const toast = this.createToast('level-up', {
      title: '⬆️ Level Up!',
      message: `You're now Level ${levelData.level}!`,
      description: `${levelData.points_required - levelData.previous_points} points earned`,
      badge_count: levelData.badge_count
    });

    this.displayToast(toast);
    this.playLevelUpSound();
  }

  createToast(type, data) {
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    
    let iconHtml = '';
    if (data.icon) {
      iconHtml = `<div class="toast-icon">
        <img src="/assets/badges/${data.icon}.svg" alt="${data.name}" onerror="this.style.display='none'">
      </div>`;
    }

    toast.innerHTML = `
      ${iconHtml}
      <div class="toast-content">
        <div class="toast-title">${data.title}</div>
        <div class="toast-message">${data.message}</div>
        ${data.description ? `<div class="toast-description">${data.description}</div>` : ''}
        ${data.points ? `<div class="toast-points">+${data.points} points</div>` : ''}
        ${data.badge_count && data.badge_count > 1 ? `<div class="toast-badge-count">${data.badge_count} badges earned</div>` : ''}
      </div>
      <button class="toast-close" onclick="this.parentElement.remove()" aria-label="Close notification">×</button>
    `;

    return toast;
  }

  displayToast(toast) {
    const container = document.querySelector('.toast-container');
    container.appendChild(toast);

    // Animate in
    requestAnimationFrame(() => {
      toast.classList.add('toast-show');
    });

    // Auto-dismiss after 6 seconds
    setTimeout(() => {
      this.dismissToast(toast);
    }, 6000);
  }

  dismissToast(toast) {
    toast.classList.add('toast-hide');
    setTimeout(() => {
      if (toast.parentElement) {
        toast.parentElement.removeChild(toast);
      }
    }, 300);
  }

  playAchievementSound() {
    // Create achievement sound effect
    if ('AudioContext' in window) {
      try {
        const audioCtx = new AudioContext();
        
        // Create a celebratory sound sequence
        const frequencies = [523, 659, 784, 1047]; // C5, E5, G5, C6
        frequencies.forEach((freq, index) => {
          const oscillator = audioCtx.createOscillator();
          const gainNode = audioCtx.createGain();
          
          oscillator.connect(gainNode);
          gainNode.connect(audioCtx.destination);
          
          oscillator.frequency.setValueAtTime(freq, audioCtx.currentTime);
          oscillator.type = 'sine';
          
          const startTime = audioCtx.currentTime + (index * 0.1);
          gainNode.gain.setValueAtTime(0.3, startTime);
          gainNode.gain.exponentialRampToValueAtTime(0.01, startTime + 0.2);
          
          oscillator.start(startTime);
          oscillator.stop(startTime + 0.2);
        });
      } catch (e) {
        console.log('Audio not available');
      }
    }
  }

  playLevelUpSound() {
    if ('AudioContext' in window) {
      try {
        const audioCtx = new AudioContext();
        
        // Rising fanfare for level up
        const frequencies = [261, 329, 392, 523, 659]; // C4, E4, G4, C5, E5
        frequencies.forEach((freq, index) => {
          const oscillator = audioCtx.createOscillator();
          const gainNode = audioCtx.createGain();
          
          oscillator.connect(gainNode);
          gainNode.connect(audioCtx.destination);
          
          oscillator.frequency.setValueAtTime(freq, audioCtx.currentTime);
          oscillator.type = 'triangle';
          
          const startTime = audioCtx.currentTime + (index * 0.08);
          gainNode.gain.setValueAtTime(0.2, startTime);
          gainNode.gain.exponentialRampToValueAtTime(0.01, startTime + 0.25);
          
          oscillator.start(startTime);
          oscillator.stop(startTime + 0.25);
        });
      } catch (e) {
        console.log('Audio not available');
      }
    }
  }

  // Public method to manually trigger achievement toast (for testing)
  triggerAchievementToast(achievementData) {
    this.showAchievementToast(achievementData);
  }

  // Public method to manually trigger level up toast (for testing)
  triggerLevelUpToast(levelData) {
    this.showLevelUpToast(levelData);
  }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
  window.toastManager = new ToastNotificationManager();
});

// Utility function to trigger achievement notifications from Rails
window.showAchievementNotification = function(achievement) {
  const event = new CustomEvent('achievement:earned', { 
    detail: achievement 
  });
  document.dispatchEvent(event);
};

window.showLevelUpNotification = function(levelData) {
  const event = new CustomEvent('level:up', { 
    detail: levelData 
  });
  document.dispatchEvent(event);
};