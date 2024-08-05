# frozen_string_literal: true

class PasswordResetsController < ApplicationController
  before_action :set_user_by_token, only: [:edit, :update]

  def new
    @user = Current.user || User.new
  end

  def create
    user = User.find_by(email: params[:user][:email])
    if user
      PasswordMailer.reset(user, user.generate_token_for(:password_reset)).deliver_now
      redirect_to root_path, notice: "Password reset instructions have been sent via email."
    else
      redirect_to new_password_reset_path, alert: "No user found with that email."
    end
  end

  def edit

  end

  def update
    if @user.update(password_params)
      redirect_to new_session_path, notice: "Password updated. Sign in to continue."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

    def set_user_by_token
      @user = User.find_by_token_for(:password_reset, params[:token])
      redirect_to new_password_reset_path, alert: "Invalid token." unless @user.present?
    end

    def password_params
      params.require(:user)
            .permit(:password, :password_confirmation)
    end
end
