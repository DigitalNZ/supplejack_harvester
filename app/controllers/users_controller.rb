# frozen_string_literal: true

class UsersController < ApplicationController
  before_action :authenticate_admin!
  before_action :find_user, only: %i[show edit update destroy]

  def index
    @users = User.order(username: :desc).page(params[:page])
  end

  def show; end

  def edit
    @user = User.find(params[:id])
  end

  def update
    if @user.update(user_params)
      redirect_to user_path(@user), notice: 'User updated successfully'
    else
      flash.alert = 'There was an issue updating the user'
      render :edit
    end
  end

  def destroy
    if @user.destroy
      redirect_to users_path, notice: 'User removed successfully'
    else
      flash.alert = 'There was an issue deleting the user'
      redirect_to users_path
    end
  end

  private

  def find_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:username, :role, :enforce_two_factor)
  end
end
