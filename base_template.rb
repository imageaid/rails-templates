gem "friendly_id"
gem "mission_control-jobs"
gem "pagy"
gem "solid_cache"
gem "solid_errors"
gem "solid_queue"

gem_group :development do
  gem "annotate"
  gem "hotwire-livereload"
  gem "rails_services"
end

file ".rubocop.yml", <<-CODE
  # Omakase Ruby styling for Rails
  inherit_gem:
    rubocop-rails-omakase: rubocop.yml
  # Your own specialized rules go here
CODE

append_to_file ".gitignore", <<-CODE

# ignore Procfile.dev and IDE specific
.byebug_history
yarn-error.log
yarn-debug.log*
.yarn-integrity
.DS_Store
.idea
.env
.nvmrc
*~
./.overmind.sock
Procfile.*
CODE

rails_command "active_storage:install"
rails_command "generate solid_errors:install"
rails_command "generate solid_queue:install"
rails_command "solid_cache:install:migrations"
rails_command "tailwindcss:install"
rails_command "importmap:install"

environment "config.active_job.queue_adapter = :solid_queue", env: "production"
environment "config.active_job.queue_adapter = :solid_queue", env: "development"

append_to_file "Procfile.dev", <<-CODE
queue: bin/rails solid_queue:start
CODE

append_to_file "config/puma.rb", <<-CODE
if Rails.env.production?
  # Allow solid_cache to be restarted with the `bin/rails restart` command.
  plugin :solid_cache
end
CODE

generate(:scaffold, "user", "first_name:string:index", "last_name:string:index", "name:string", "email:string:uniq", "role:integer", "password_digest:string", "slug:string:uniq")
inject_into_class("app/models/user.rb", "User", "  extend FriendlyId\n  friendly_id :name, use: :slugged\n\n  has_secure_password\n  generates_token_for :password_reset, expires_in: 15.minutes { password_salt&.last(10) }\n  generates_token_for :email_confirmation, expires_in: 24.hours { email }\n\n  normalizes :email, with: -> email { email.strip.downcase }\n\n  enum role: { guest: 0, admin: 1 }\n\n  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }\n")
# this (generate the controllers) 
# generate(:controller, "welcome", "index")
# generate(:controller, "registrations", "new create")
# generate(:controller, "sessions", "new create destroy")
# generate(:controller, "passwords", "edit update")
# generate(:controller, "password_resets", "new create edit update")

# or this ... just copy the base session, registration and password related views and files
directory "app", force: true 

# routes
route 'root to: "welcome#index"'
route "resource :session, only: [ :new, :create, :destroy ]"
route "resource :login, only: [ :new, :show, :create, :destroy ]"
route "resource :registration, only: [ :new, :create ]"
route "resource :password, only: [ :edit, :update ]"
route "resource :password_reset, only: [ :new, :create, :edit, :update ]"

route <<-CODE
  mount SolidErrors::Engine, at: "/solid_errors"
  mount MissionControl::Jobs::Engine, at: "/jobs"
CODE

rails_command "generate annotate:install"
rails_command "generate friendly_id"
rails_command "db:create"
rails_command "db:migrate"

inject_into_class("app/controllers/application_controller.rb", "ApplicationController", "  include Pagy::Backend\n")
inject_into_module("app/helpers/application_helper.rb", "ApplicationHelper", "  include Pagy::Frontend\n")

initializer "pagy.rb", <<-CODE
Pagy::DEFAULT[:items] = 10 # items per page
Pagy::DEFAULT[:size]  = [1, 4, 4, 1] # nav bar links
# Better user experience handled automatically
# require 'pagy/extras/overflow'
# Pagy::DEFAULT[:overflow] = :last_page
# When you are done setting your own default freeze it, so it will not get changed accidentally
Pagy::DEFAULT.freeze
CODE
initializer "solid_errors.rb", <<-CODE
# Set authentication credentials for Solid Errors
# Rails.application.config.solid_errors.username = Rails.application.credentials.solid_errors.username
# Rails.application.config.solid_errors.password = Rails.application.credentials.solid_errors.password

Rails.application.config.solid_errors.send_emails = true
Rails.application.config.solid_errors.email_from = "errors@localhost"
Rails.application.config.solid_errors.email_to = "devs@localhost"
CODE

rails_command "bundle binstubs rubocop"

after_bundle do
  rails_command "action_text:install"  

  git :init
  git add: "."
  git commit: %Q{ -m 'Initial commit' }
end
