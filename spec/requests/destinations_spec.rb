# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Destinations' do
  let(:user)        { create(:user) }
  let(:destination) { create(:destination) }

  before do
    sign_in user
  end

  describe 'GET /index' do
    it 'displays a list of destinations' do
      get destinations_path

      expect(response).to have_http_status :ok
    end
  end

  describe 'GET /show' do
    it 'displays a particular destination' do
      get destination_path(destination)

      expect(response).to have_http_status :ok
    end
  end

  describe 'GET /new' do
    it 'displays the new destination form' do
      get new_destination_path

      expect(response).to have_http_status :ok
    end
  end

  describe 'POST /create' do
    context 'with valid attributes' do
      it 'creates a new destination' do
        expect do
          post destinations_path, params: {
            destination: attributes_for(:destination)
          }
        end.to change(Destination, :count).by(1)
      end

      it 'redirects to the destinations page' do
        post destinations_path, params: {
          destination: attributes_for(:destination)
        }

        expect(response).to redirect_to destinations_path
      end
    end

    context 'with invalid attributes' do
      it 'does not create a new destination' do
        expect do
          post destinations_path, params: {
            destination: { name: 'hello' }
          }
        end.not_to change(Destination, :count)
      end
    end
  end

  describe 'DELETE /destroy' do
    let!(:destination) { create(:destination) }

    it 'deletes a destination' do
      expect do
        delete destination_path(destination)
      end.to change(Destination, :count).by(-1)
    end

    it 'redirects to the destinations page' do
      delete destination_path(destination)

      expect(response).to redirect_to destinations_path
    end

    it 'does not delete the destination if something goes wrong' do
      allow_any_instance_of(Destination).to receive(:destroy).and_return(false)

      delete destination_path(destination)

      expect(response).to redirect_to destination_path(destination)
    end
  end

  describe 'PATCH /update' do
    context 'with valid attributes' do
      it 'updates an existing destination' do
        patch destination_path(destination), params: {
          destination: { name: 'Updated Destination' }
        }

        destination.reload

        expect(destination.name).to eq 'Updated Destination'
      end

      it 'redirects to the destinations page' do
        patch destination_path(destination), params: {
          destination: { name: 'Updated Destination' }
        }

        expect(response).to redirect_to destinations_path
      end
    end

    context 'with invalid attributes' do
      it 'does not update an existing destination' do
        patch destination_path(destination), params: {
          destination: { name: nil }
        }

        destination.reload

        expect(destination.name).not_to be_nil
      end
    end
  end

  describe 'POST /test' do
    it 'returns success if the details provided are valid' do
      stub_request(:get, 'http://localhost:5000/harvester/users?api_key=testkey')
        .with(
          headers: {
            'Accept' => '*/*',
            'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'User-Agent' => 'Supplejack Harvester v2.0'
          }
        )
        .to_return(status: 200, body: '', headers: {})

      post test_destinations_path, params: {
        destination: {
          name: 'localhost',
          url: 'http://localhost:5000',
          api_key: 'testkey'
        }
      }

      expect(response.parsed_body['status']).to eq 200
    end

    it 'returns error if the details provided are invalid' do
      stub_request(:get, 'http://localhost:5000/harvester/users?api_key=testkey')
        .with(
          headers: {
            'Accept' => '*/*',
            'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'User-Agent' => 'Supplejack Harvester v2.0'
          }
        )
        .to_return(status: 403, body: '', headers: {})

      post test_destinations_path, params: {
        destination: {
          name: 'localhost',
          url: 'http://localhost:5000',
          api_key: 'testkey'
        }
      }

      expect(response.parsed_body['status']).to eq 403
    end
  end
end
