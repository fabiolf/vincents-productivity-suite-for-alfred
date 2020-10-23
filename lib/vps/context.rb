module VPS
  class Context
    attr_reader :configuration, :arguments, :environment

    def initialize(configuration, arguments, environment)
      @configuration = configuration
      @arguments = arguments
      @environment = environment
    end
  end

  class CommandContext < Context
    def initialize(configuration, arguments, environment, entity_type_contexts = {})
      super(configuration, arguments, environment)
      @entity_type_contexts = entity_type_contexts
      @entity_instance = nil
    end

    def triggered_as_snippet?
      environment['TRIGGERED_AS_SNIPPET'] == 'true'
    end

    # Methods below are from BaseRepository, without context. Here we ensure the correct context is passed.

    ##
    # @return [VPS::EntityTypes::BaseType]+
    def find_all(entity_type = @entity_type_contexts.keys.first)
      entity_type_context = @entity_type_contexts[entity_type]
      entity_type_context[:repository].find_all(entity_type_context[:context])
    end

    ##
    # @return [VPS::EntityTypes::BaseType]
    def load
      entity_type_context = @entity_type_contexts[@entity_type_contexts.keys.first]
      @entity_instance ||= entity_type_context[:repository].load(entity_type_context[:context])
    end

    ##
    # @param instance [VPS::EntityTypes::BaseType]
    def create_or_find(instance, entity_type = @entity_type_contexts.keys.first)
      entity_type_context = @entity_type_contexts[entity_type]
      entity_type_context[:repository].create_or_find(entity_type_context[:context], instance)
    end
  end

  class SystemContext
    attr_reader :configuration, :area, :state, :arguments

    def initialize(configuration, state, arguments)
      @configuration = configuration
      @state = state
      @area = @state.focus
      @arguments = arguments
    end
  end
end