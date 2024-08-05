class ApplicationController < ActionController::Base
  
  private

    def authenticate_user!
      redirect_to new_session_path, alert: "Please sign in to perform those actions." unless signed_in?
    end

    def current_user
      Current.user || authenticate_user_from_session
    end
    helper_method :current_user

    def authenticate_user_from_session
      User.find_by(id: session[:user_id])
    end

    def signed_in?
      current_user.present?
    end
    helper_method :signed_in?

    def login(user, from_link: false)
      Current.user = user
      reset_session
      user.touch :last_sign_in_at if from_link
      session[:user_id] = user.id
    end

    def logout(_user)
      reset_session
      Current.user = nil
    end
end
