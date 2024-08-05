import "@hotwired/turbo-rails"

import "trix"
import "@rails/actiontext"

import "./controllers"
import "./services/worker"

require("@rails/activestorage").start()

import Alpine from 'alpinejs'
window.Alpine = Alpine
Alpine.start()

// this is necessary so that when Turbo morphs the dom, existing Alpine elements are reinitialized
document.addEventListener("turbo:morph", () => {
  document.querySelectorAll('[x-data]').forEach((el) => {
    Alpine.initTree(el)
  })
})
