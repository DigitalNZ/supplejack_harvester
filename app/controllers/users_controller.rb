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
      redirect_to user_path(@user), notice: t('.success')
    else
      flash.alert = t('.failure')
      render :edit
    end
  end

  def destroy
    if @user.destroy
      redirect_to users_path, notice: t('.success')
    else
      flash.alert = t('.failure')
      redirect_to users_path
    end
  end

  private

  def find_user
    @user = User.find(params[:id])
  end

  def user_params
    # In case you use this method, make sure that the user is an admin
    # brakeman warns against having :role as a permitted attribute
    params.expect(user: %i[username role enforce_two_factor])
  end
end
