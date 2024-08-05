class SignUpMailer < ApplicationMailer
  def confirmation(user)
    @user = user
    mail(to: @user.email, subject: "Welcome to our site!")
  end
end
