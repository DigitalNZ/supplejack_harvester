# frozen_string_literal: true

class DestinationsController < ApplicationController
  before_action :find_destination, only: %i[show edit update destroy]

  def index
    @destinations = Destination.order(:name).page(params[:page])
  end

  def show; end

  def new
    @destination = Destination.new
  end

  # A connectivity check with someone waiting on the answer, so it does not get the minute a
  # harvest's requests are allowed: a destination that has not answered in fifteen seconds
  # has failed the check, and holding the request open for longer tells them nothing more.
  def test
    test_url = "#{destination_params['url']}/harvester/users?api_key=#{destination_params['api_key']}"

    render json: { status: Faraday.new(request: { timeout: 15 }).get(test_url).status }
  end

  def edit; end

  def create
    @destination = Destination.new(destination_params)

    if @destination.save
      redirect_to destinations_path, notice: t('.success')
    else
      flash.alert = t('.failure')
      render :new
    end
  end

  def update
    if @destination.update(destination_params)
      flash.notice = t('.success')

      redirect_to destinations_path
    else
      flash.alert = t('.failure')

      render 'edit'
    end
  end

  def destroy
    if @destination.destroy
      redirect_to destinations_path, notice: t('.success')
    else
      flash.alert = t('.failure')

      redirect_to destination_path(@destination)
    end
  end

  private

  def find_destination
    @destination = Destination.find(params[:id])
  end

  def destination_params
    params.expect(destination: %i[name url api_key])
  end
end
