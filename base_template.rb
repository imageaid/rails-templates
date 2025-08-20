gem "friendly_id"
gem "mission_control-jobs"
gem "pagy"
gem "solid_errors", github: "imageaid/solid_errors", branch: "main"

gem_group :development do
  gem "annotaterb"
  gem "erb_lint"
  gem "hotwire-spark"
  gem "letter_opener_web"
  gem "rails_services"
end

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

environment "config.active_job.queue_adapter = :solid_queue", env: "production"
environment "config.mission_control.jobs.adapters = [ :solid_queue ]", env: "production"
environment "config.active_job.queue_adapter = :solid_queue", env: "development"
environment "config.mission_control.jobs.adapters = [ :solid_queue ]", env: "development"

if File.exist?("Procfile.dev")
  append_to_file "Procfile.dev", <<-CODE
    worker: bin/jobs
  CODE
else
  create_file "Procfile.dev", ""
  append_to_file "Procfile.dev", <<-CODE
    web: bin/rails s -p 3000 -b 0.0.0.0
    css: bin/rails tailwindcss:watch
    worker: bin/jobs
  CODE
end

rails_command "css:install:tailwind"
rails_command "generate authentication"
rails_command "generate migration AddFieldsToUsers first_name:string:index last_name:string:index name:string role:integer slug:string:uniq"
inject_into_class("app/models/user.rb", "User", "  extend FriendlyId\n  friendly_id :name, use: :slugged\n\n  generates_token_for :password_reset, expires_in: 15.minutes { password_salt&.last(10) }\n  generates_token_for :email_confirmation, expires_in: 24.hours { email }\n\n  normalizes :email_address, with: -> email { email.strip.downcase }\n\n  enum role: { guest: 0, admin: 1 }\n\n  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }\n")

rails_command "generate annotate_rb:install"
rails_command "generate friendly_id"
rails_command "db:prepare"

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
CODE

append_to_file ".rubocop.yml", <<-CODE
# Omakase Ruby styling for Rails
inherit_gem:
  rubocop-rails-omakase: rubocop.yml
# Your own specialized rules go here
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

  # routes
  route 'root to: "welcome#index"'
  route "resource :session, only: [ :new, :create, :destroy ]"
  route "resource :login, only: [ :new, :show, :create, :destroy ]"
  route "resource :registration, only: [ :new, :create ]"
  route "resource :password, only: [ :edit, :update ]"
  route "resource :password_reset, only: [ :new, :create, :edit, :update ]"
  route 'get "/offline", to: "pwa#offline", as: :pwa_offline'
  route 'get "service-worker" => "pwa#service_worker", as: :pwa_service_worker'
  route 'get "manifest" => "pwa#manifest", as: :pwa_manifest'
  route 'post "/notifications/subscribe", to: "pwa#subscribe"'

  route <<-CODE
    mount SolidErrors::Engine, at: "/solid_errors"
    mount MissionControl::Jobs::Engine, at: "/jobs"
  CODE

  # setup CSS
  rails_command "tailwindcss:install"
  rails_command "active_storage:install"
  rails_command "action_text:install"
  rails_command "generate solid_errors:install"
  rails_command "generate solid_queue:install"
  rails_command "solid_cache:install:migrations"

  append_to_file "config/importmap.rb", <<-CODE
  pin_all_from "app/javascript/controllers", under: "controllers"
  pin_all_from "app/javascript/services", under: "services"
  CODE

  # copy the base icons, session, registration and password related views and files
  directory "public", force: true
  directory "app", force: true

  # init the git repo
  git :init
  git add: "."
  git commit: %Q{ -m 'Initial commit' }
end
