module VPS
  class Configuration

    DEFAULT_FILE = File.join(Dir.home, '.vpsrc').freeze

    def self.load(path)
      unless File.readable?(path)
        $stderr.puts 'ERROR: cannot read configuration file'
        $stderr.puts
        $stderr.puts 'VPS requires a configuration file at ' #{path}'"
        raise 'Configuration file missing or unreadable'
      end
      Configuration.new(path)
    end

    def initialize(path)
      hash = YAML.load_file(path)
      extract_areas(hash)
      extract_actions(hash)
    end

    def include_area?(name)
      @areas.has_key? name
    end

    def area(name)
      @areas[name]
    end

    def areas
      @areas.values
    end

    def actions
      @actions
    end

    private

    def extract_areas(hash)
      @areas = {}
      hash['areas'].each_pair do |key, config|
        config = config || {}
        name = config['name'] || key.capitalize
        root = if config['root']
                 File.expand_path(config['root'])
               else
                 File.join(Dir.home, name)
               end
        area = {
          key: key,
          name: name,
          root: root
        }
        config.each_pair do |plugin_key, plugin_config|
          plugin = Registry::plugins[plugin_key.to_sym]
          if plugin.nil?
            $stderr.puts "WARNING: no area plugin found for key '#{plugin_key}'. Please check your configuration!"
            next
          end
          area[plugin_key.to_sym] = plugin[:module].read_area_configuration(area, plugin_config)
        end
        @areas[key] = area
      end
    end

    def extract_actions(hash)
      @actions = {}
      hash['actions'].each_pair do |name, config|
        config = config || {}
        key = name.to_sym
        plugin = Registry::plugins[key]
        if plugin.nil? || plugin[:action].nil?
          $stderr.puts "WARNING: no action plugin found for key '#{key}'. Please check your configuration!"
          next
        end
        @actions[key] = plugin[:module].read_action_configuration(config)
      end
    end
  end
end