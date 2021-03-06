module VPS

  # Runs a command. Before a command can be executed, its context first has to configured.
  # This context depends on the type of command that's going to run.
  class CommandRunner
    def initialize(configuration, state, arguments, environment)
      @configuration = configuration
      @state = state
      @area = @state.focus
      @arguments = arguments
      @environment = environment
      entity_type_name = @arguments.shift
      command_name = @arguments.shift
      @command = resolve_command(entity_type_name, command_name)
      @command = resolve_command(entity_type_name, command_name)
      if @command.nil?
        raise "Invalid command '#{command_name}' for command group '#{entity_type_name}'"
      end
    end

    def help_available?
      !@command.option_parser.nil?
    end

    # @return [OptionParser]
    def help
      @command.option_parser
    end

    # Sets up the command context and executes the command
    # @return void
    def execute
      command_context = create_context
      if @command.is_a?(VPS::Plugin::EntityInstanceCommand) || @command.is_a?(VPS::Plugin::CollaborationCommand)
        instance = command_context.load_instance
        if instance.nil?
          raise "Aborting. Could not load entity instance. Did you specify an identifier?"
        end
      end
      @command.run(command_context)
    end

    private

    def create_context
      if @command.is_a?(VPS::Plugin::SystemCommand)
        SystemContext.new(@configuration, @state, @arguments)
      else
        # Set up the repositories and their contexts for use by the command
        entity_types = [@command.supported_entity_type]
        if @command.is_a?(VPS::Plugin::CollaborationCommand)
          entity_types << @command.collaboration_entity_type
        end
        entity_type_contexts = entity_types.map do |entity_type|
          repository = resolve_repository(entity_type)
          plugin = Registry.instance.for_repository(repository)
          context = RepositoryContext.new(@area, plugin.name, @arguments, @environment)
          [entity_type, {repository: repository, context: context}]
        end.to_h
        # Now create the command context
        plugin = Registry.instance.for_command(@command)
        CommandContext.new(@area, plugin.name, @arguments, @environment, entity_type_contexts)
      end
    end

    def resolve_command(entity_type_name, command_name)
      @area.keys
        .filter_map { |name| Registry.instance.plugins[name] }
        .map { |plugin| plugin.commands }
        .flatten
        .select { |command| command.supported_entity_type.entity_type_name == entity_type_name }
        .select { |command| command.name == command_name }
        .first
    end

    def resolve_repository(entity_type)
      @area.keys
        .filter_map { |name| Registry.instance.plugins[name] }
        .map { |plugin| plugin.repositories }
        .flatten
        .select { |repository| repository.supported_entity_type == entity_type }
        .first
    end
  end
end