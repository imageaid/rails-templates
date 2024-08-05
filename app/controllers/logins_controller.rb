# frozen_string_literal: true

class LoginsController < ApplicationController

  def new

  end
  def show
    user = User.find_by_token_for(:magic_login, params[:token])
    login(user, from_link: true) if user.present?
    redirect_to root_path
  end

  def create
    user = User.find_by(email: params[:email])
    LoginMailer.with(user: user).login.deliver_later if user.present?
    redirect_to root_path, notice: "Check your email to login."
  end

  def destroy
    logout(current_user)
    redirect_to root_path
  end
end
