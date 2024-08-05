# frozen_string_literal: true

class RegistrationsController < ApplicationController

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)
    if @user.save
      login(@user)
      SignUpMailer.confirmation(@user).deliver_now
      redirect_to root_path, notice: "User was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

    def registration_params
      params.require(:user).permit(:email, :password, :password_confirmation, :first_name, :last_name, :role)
    end
end
