# frozen_string_literal: true

class PwaController < ApplicationController
  skip_forgery_protection
  skip_before_action :authenticate_user!, except: [ :subscribe ]
  skip_before_action :set_foods

  def service_worker
    render template: "pwa/service-worker", layout: false, content_type: "application/javascript"
  end

  def manifest
    render template: "pwa/manifest", layout: false, content_type: "application/json"
  end

  def subscribe
    device = current_user.registered_devices.find_or_initialize_by(endpoint: params.dig(:worker, :endpoint))
    if device.new_record?
      device.p256dh = params.dig(:worker, :keys, :p256dh)
      device.auth = params.dig(:worker, :keys, :auth)
      device.save
    end
    head :ok
  end
end
