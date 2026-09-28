# frozen_string_literal: true

module Utils
  class HashCache
    def initialize(cache_file)
      @cache_file = cache_file
      @all_content = read_all
    end

    def read_all
      begin
        file_content = File.read(@cache_file)
        return JSON.parse file_content unless file_content.empty?

        {}
      rescue
        {}
      end
    end

    def read(key)
      @all_content&.dig(key)
    end

    def write(data)
      @all_content.merge!(data)
      File.write(@cache_file, @all_content.to_json)
    end
  end
end
