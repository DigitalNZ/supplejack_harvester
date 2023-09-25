# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Transformation::TypeChecker do
  describe '#valid?' do
    describe 'allowed types returns true with' do
      it 'NilClass' do
        expect(described_class.new(nil).valid?).to be true
      end

      it 'TrueClass' do
        expect(described_class.new(true).valid?).to be true
      end

      it 'FalseClass' do
        expect(described_class.new(false).valid?).to be true
      end

      it 'Integer' do
        expect(described_class.new(1).valid?).to be true
      end

      it 'Float' do
        expect(described_class.new(0.1).valid?).to be true
      end

      it 'String' do
        expect(described_class.new('String').valid?).to be true
      end

      it 'empty array' do
        expect(described_class.new([]).valid?).to be true
      end

      it 'empty Hash' do
        expect(described_class.new({}).valid?).to be true
      end

      it 'array of nil' do
        expect(described_class.new([nil, nil]).valid?).to be true
      end

      it 'array of TrueClass' do
        expect(described_class.new([true]).valid?).to be true
      end

      it 'array of FalseClass' do
        expect(described_class.new([false]).valid?).to be true
      end

      it 'array of Integer' do
        expect(described_class.new([1, 1]).valid?).to be true
      end

      it 'array of Float' do
        expect(described_class.new([0.1, 0.1]).valid?).to be true
      end

      it 'array of String' do
        expect(described_class.new(%w[String String]).valid?).to be true
      end

      it 'array of Hash with symbol => Integer' do
        expect(described_class.new([{a: 1}]).valid?).to be true
      end

      it 'array of Hash with String => Integer' do
        expect(described_class.new([{'a' => 1}]).valid?).to be true
      end

      it 'Hash of String => TrueClass' do
        expect(described_class.new('1' => true).valid?).to be true
      end

      it 'Hash of String => FalseClass' do
        expect(described_class.new('1' => false).valid?).to be true
      end

      it 'Hash of Integer => nil' do
        expect(described_class.new(1 => nil).valid?).to be true
      end

      it 'Hash of String => Integer' do
        expect(described_class.new('a' => 1).valid?).to be true
      end

      it 'Hash of Symbol => Integer' do
        expect(described_class.new(a: 1).valid?).to be true
      end

      it 'Hash of String => String' do
        expect(described_class.new('A' => 'B').valid?).to be true
      end
    end

    describe 'forbidden types returns false with' do
      it 'Object' do
        expect(described_class.new(Object.new).valid?).to be false
      end

      it 'Array of Object' do
        expect(described_class.new([Object.new]).valid?).to be false
      end

      it 'Array of Hash with String => Array' do
        expect(described_class.new([{'a' => []}]).valid?).to be false
      end

      it 'Object in Hash key' do
        expect(described_class.new(Object.new => 1).valid?).to be false
      end

      it 'Object in Hash value' do
        expect(described_class.new(1 => Object.new).valid?).to be false
      end
    end
  end

  describe '#error' do
    it 'returns nil if there is no errors' do
      check = described_class.new('a')
      check.valid?
      expect(check.error).to be_nil
    end

    it 'returns the error message if there is an error' do
      check = described_class.new(Object.new)
      check.valid?
      expect(check.error).to include 'Field contains a wrong type: Object. The field returned:'
    end
  end
end
