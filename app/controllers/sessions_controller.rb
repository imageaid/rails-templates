# frozen_string_literal: true

class SessionsController < ApplicationController

  def new

  end

  def create
    user = User.authenticate_by(email: params[:email], password: params[:password])
    if user
      login(user)
      redirect_to root_path, notice: "You have been logged in."
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unauthorized
    end
  end

  def destroy
    logout(current_user)
    redirect_to root_path, notice: "You have been logged out."
  end
end
