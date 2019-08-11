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

    ##
    # Returns the manager for a specified entity name in an area
    def entity_manager_for(area, entity_name)
      Registry.entity_managers_for(entity_name).select do |plugin|
        area.has_key?(plugin.name)
      end.first
    end

    ##
    # Returns the manager for a specified entity name in an area
    def entity_manager_for_class(area, entity_class)
      entity_name = entity_class.name.split('::').last.downcase
      entity_manager_for(area, entity_name)
    end

    ##
    # Returns all entity managers that are enabled within an area
    def entity_managers(area)
      Registry.entity_managers.select do |plugin|
        area.has_key?(plugin.name)
      end
    end

    ##
    # Returns all collaborators. Possible types are +:project+
    def collaborators(area, entity_class)
      Registry.collaborators(entity_class).select do |plugin|
        area.has_key?(plugin.name)
      end
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
        # The area and paste plugins are added to every area, so that:
        # - these commands are always available
        # - no overriding configuration can be provided
        area['area'] = {}
        area['paste'] = {}
        entity_classes = [Entities::Area, Entities::Paste]
        config.each_pair do |plugin_key, plugin_config|
          plugin = Registry::plugins[plugin_key]
          if plugin.nil?
            unless ['key', 'name', 'root'].include?(plugin_key)
              $stderr.puts "WARNING: no area plugin found for key '#{plugin_key}'. Please check your configuration!"
            end
            next
          end
          entity_class = plugin.entity_class
          unless entity_class.nil?
            if entity_classes.include? entity_class
              $stderr.puts "WARNING: the area #{name} has multiple managers for entity class #{entity_class}. Skipping plugin #{plugin_key}"
              next
            end
          end
          area[plugin.name] = plugin.plugin_module.read_area_configuration(area, plugin_config || {})
        end
        @areas[key] = area
      end
    end

    def extract_actions(hash)
      @actions = {}
      hash['actions'].each_pair do |key, config|
        plugin = Registry::plugins[key]
        if plugin.nil? || plugin.action_class.nil?
          $stderr.puts "WARNING: no action plugin found for key '#{key}'. Please check your configuration!"
          next
        end
        @actions[key] = plugin.plugin_module.read_action_configuration(config || {})
      end
    end
  end
end