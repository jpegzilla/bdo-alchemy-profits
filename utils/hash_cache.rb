# frozen_string_literal: true

class HashCache
  def initialize(cache_file)
    @cache_file = cache_file
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
    read_all&.dig(key)
  end

  def write(data)
    item_map = read_all
    File.open(@cache_file, 'w') do |file|
      new_data = { **item_map, **data }

      file.write new_data.to_json
    end
  end
end
