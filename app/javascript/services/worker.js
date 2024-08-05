async function registerServiceWorker() {
  if (!navigator.serviceWorker) return

  try {
    await navigator.serviceWorker.register('/service-worker.js')
  } catch(error) {
    console.error('Failed to register service worker:', error)
  }
}

async function requestNotificationPermission() {
  const permissionResult = await Notification.requestPermission();
  if (Notification.permission === "granted") {
    allowButton.style.display = 'none';
    return true
  }
}

async function startServiceWorker() {
  const vapidPublicKey = document.head.querySelector("meta[name='vapid_public_key']").getAttribute("content")
  console.log(vapidPublicKey)
  await registerServiceWorker()

  if (await requestNotificationPermission()) {
    const subscription = await getPushSubscription(vapidPublicKey)
    await sendSubscriptionToServer(subscription)
  }
}

async function getPushSubscription(vapidPublicKey) {
  const registration = await navigator.serviceWorker.getRegistration()
  if (!registration) return null

  const subscription = await registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: vapidPublicKey
  })
  return subscription
}

async function sendSubscriptionToServer(subscription) {
  return fetch("/notifications/subscribe",{
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-CSRF-Token": document.head.querySelector("meta[name=csrf-token]").getAttribute("content")
    },
    body: JSON.stringify({ worker: subscription.toJSON() })
  })
}

async function serviceWorkerUpdate() {
  const registration = await navigator.serviceWorker.ready;

  registration.addEventListener("updatefound", event => {
    const newSW = registration.installing;
    newSW.addEventListener("statechange", event => {
      if (newSW.state == "installed") {
        // New service worker is installed, but waiting activation
      }
    });
  })
}

registerServiceWorker()

const allowButton = document.getElementById('allow-notifications');
const allowAlert = document.getElementById('allow-notifications-alert');

if (typeof Notification !== "undefined") {
  if (Notification.permission === "granted") {
    allowAlert.style.display = 'none';
    startServiceWorker()
  } else if (Notification.permission === "denied") {
    allowAlert.style.display = 'none';
  } else {
    allowAlert.style.display = 'block';
  }

  allowButton.addEventListener('click', async () => {
    if (await requestNotificationPermission()) {
      startServiceWorker()
    }
  })
}