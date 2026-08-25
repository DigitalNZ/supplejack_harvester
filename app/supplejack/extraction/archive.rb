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

    # The bodies of a tar file's entries, gunzipping gzipped ones. For tars saved
    # raw as a single page file, which are unpacked at read time rather than on disk.
    def self.entry_bodies_from_file(file_path)
      bytes = File.binread(file_path)
      return [] unless tar?(bytes)

      Minitar::Input.open(StringIO.new(bytes)) { |input| file_entry_bodies(input) }
    end

    def self.file_entry_bodies(input)
      input.enum_for(:each).filter_map { |entry| entry_body(entry.read) if entry.file? }
    end

    def self.tar?(bytes)
      bytes.to_s.byteslice(257, 5) == 'ustar'
    end

    def self.entry_body(content)
      return Zlib.gunzip(content) if content.to_s.byteslice(0, 2).unpack('C2') == [0x1F, 0x8B]

      content
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
