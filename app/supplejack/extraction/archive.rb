# frozen_string_literal: true

require 'minitar'

module Extraction
  class Archive
    def self.gzipped?(gz_file_path)
      File.open(gz_file_path, 'rb') do |file|
        magic_number = file.read(2).unpack('C2')
        return magic_number == [0x1F, 0x8B]
      end
    end

    def self.extract_from_gz(gz_path)
      Zlib::GzipReader.open(gz_path, &:read)
    end

    def self.top_level_entry?(full_name)
      count = full_name.count('/')
      return true if count.zero?
      return true if count == 1 && full_name[-1] == '/'

      false
    end

    def self.list_top_level_entries(input)
      top_level_entries = []
      input.each do |entry|
        full_name = entry.full_name
        top_level_entries << full_name if Archive.top_level_entry?(full_name)
      end

      top_level_entries
    end

    def self.body(extracted_file_path)
      body = if Archive.gzipped?(extracted_file_path)
               Archive.extract_from_gz(extracted_file_path)
             else
               File.read(extracted_file_path)
             end

      File.delete(extracted_file_path)
      body
    end
  end
end
