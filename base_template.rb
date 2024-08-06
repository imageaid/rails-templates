gem "friendly_id"
gem "mission_control-jobs"
gem "pagy"
gem "solid_cache"
gem "solid_errors"
gem "solid_queue"

gem_group :development do
  gem "annotate"
  gem "erb_lint"
  gem "hotwire-livereload"
  gem "letter_opener_web", "~> 2.0"
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

# setup the importmaps and pin some base JS packages
rails_command "importmap:install"
run 'bin/importmap pin "@hotwired/turbo-rails"'
run 'bin/importmap pin "@hotwired/stimulus"'
run 'bin/importmap pin "alpinejs"'

# setup CSS
rails_command "tailwindcss:install"

# storage, text, errors, cache and queues
rails_command "active_storage:install"
rails_command "action_text:install"
rails_command "generate solid_errors:install"
rails_command "generate solid_queue:install"
rails_command "solid_cache:install:migrations"

append_to_file "config/importmap.rb", <<-CODE
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/services", under: "services"
CODE

environment "config.active_job.queue_adapter = :solid_queue", env: "production"
environment "config.mission_control.jobs.adapters = [ :solid_queue ]", env: "production"
environment "config.active_job.queue_adapter = :solid_queue", env: "development"
environment "config.mission_control.jobs.adapters = [ :solid_queue ]", env: "development"

# not going with foreman/Procfile for SolidQueue for now
# append_to_file "Procfile.dev", <<-CODE
# queue: bin/rails solid_queue:start
# CODE

# using the puma plugin for SolidQueue atm
append_to_file "config/puma.rb", <<-CODE
if Rails.env.production?
  # Allow solid_queue to be restarted with the `bin/rails restart` command.
  plugin :solid_queue
end
CODE

generate(:scaffold, "user", "first_name:string:index", "last_name:string:index", "name:string", "email:string:uniq", "role:integer", "password_digest:string", "slug:string:uniq")
inject_into_class("app/models/user.rb", "User", "  extend FriendlyId\n  friendly_id :name, use: :slugged\n\n  has_secure_password\n  generates_token_for :password_reset, expires_in: 15.minutes { password_salt&.last(10) }\n  generates_token_for :email_confirmation, expires_in: 24.hours { email }\n\n  normalizes :email, with: -> email { email.strip.downcase }\n\n  enum role: { guest: 0, admin: 1 }\n\n  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }\n")

# copy the base session, registration and password related views and files
directory "app", force: true
copy_file "./public/icon-192x192.png"
copy_file "./public/icon-512x512.png"
copy_file "./public/offline.html"
copy_file "./public/offline.webp"

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

append_to_file ".rubocop.yml", <<-CODE
AllCops:
  Exclude:
    - '**/db/migrate/*'
    - '**/Gemfile.lock'
    - '**/Rakefile'
    - '**/rails'
    - '**/vendor/**/*'
    - '**/spec_helper.rb'
    - 'node_modules/**/*'
    - 'bin/*'

# custom rules
Layout/ElseAlignment:
  Enabled: false

Layout/TrailingEmptyLines:
  Enabled: false

Layout/InitialIndentation:
  Enabled: false

Lint/UselessAssignment:
  Enabled: false

Layout/EndAlignment:
  Enabled: true
  EnforcedStyleAlignWith: keyword
CODE

create_file ".better-html.yml", ""
append_to_file ".better-html.yml", <<-CODE
---
allow_single_quoted_attributes: false
allow_unquoted_attributes: false
CODE

create_file ".erb-lint.yml", ""
append_to_file ".erb-lint.yml", <<-CODE
---
#exclude:
#  - "**/app/views/**/*"

EnableDefaultLinters: true
linters:
  ErbSafety:
    enabled: true
    better_html_config: .better-html.yml
  Rubocop:
    enabled: true
    rubocop_config:
      inherit_from:
        - .rubocop.yml
CODE

after_bundle do
  # Make sure Linux is in the Gemfile.lock for deploying
  run "bundle lock --add-platform x86_64-linux"

  # init the git repo
  git :init
  git add: "."
  git commit: %Q{ -m 'Initial commit' }
end
