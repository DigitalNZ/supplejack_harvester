# frozen_string_literal: true

class TwoFactorSetupsController < ApplicationController
  skip_before_action :setup_two_factor_authentication

  def show
    current_user.update(otp_secret: User.generate_otp_secret) if current_user.otp_secret.nil?
  end

  def create
    if current_user.validate_and_consume_otp!(user_params[:otp_attempt])
      current_user.update(otp_required_for_login: true, two_factor_setup: true)

      redirect_to root_path, notice: t('.success')
    else
      flash.alert = t('.failure')
      render :show
    end
  end

  def destroy
    return redirect_back_or_to(root_path, alert: t('.mandatory')) if current_user.enforce_two_factor?

    if current_user.update(otp_required_for_login: false, otp_secret: nil, two_factor_setup: false)
      flash.notice = t('.success')
    else
      flash.alert = t('.failure')
    end

    redirect_to edit_profile_path
  end

  private

  def user_params
    params.expect(user: [:otp_attempt])
  end
end
