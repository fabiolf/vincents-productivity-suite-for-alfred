module VPS
  module Plugins
    module Obsidian
      def self.configure_plugin(plugin)
        plugin.configurator_class = Configurator
        plugin.for_entity(Entities::Note)
        plugin.add_command(Root, :single)
        plugin.add_command(List, :list)
        plugin.add_command(Commands, :list)
        plugin.add_command(Edit, :single)
        plugin.add_command(View, :single)
        plugin.add_command(Plain, :single)
        plugin.add_command(Project, :single)
        plugin.add_command(Contact, :single)
        plugin.add_command(Event, :single)
        plugin.add_command(Today, :list)
        plugin.add_collaboration(Entities::Project)
        plugin.add_collaboration(Entities::Contact)
        plugin.add_collaboration(Entities::Event)
      end

      class Configurator < PluginSupport::Configurator
        def read_area_configuration(area, hash)
          config = {
            root: File.join(area[:root], hash['path'] || 'Notes'),
            vault: hash['vault'] || area[:name],
            templates: {}
          }
          %w(default plain contact event project today).each do |set|
            templates = if hash['templates'] && hash['templates'][set]
                          hash['templates'][set]
                        else
                          {}
                        end
            config[:templates][set.to_sym] = {
              filename: templates['filename'] || nil,
              title: templates['title'] || nil,
              text: templates['text'] || nil,
              tags: templates['tags'] || nil
            }
          end
          config[:templates][:default][:filename] ||= nil
          config[:templates][:default][:title] ||= '{{input}}'
          config[:templates][:default][:text] ||= ''
          config[:templates][:default][:tags] ||= []
          config
        end
      end

      def self.load_entity(context)
        Entities::Note.from_id(context.arguments.join(' '))
      end

      def self.commands_for(area, entity)
        if entity.is_a?(Entities::Project)
          {
            title: 'Create a note in Obsidian',
            arg: "note project #{entity.id}",
            icon: {
              path: "icons/obsidian.png"
            }
          }
        elsif entity.is_a?(Entities::Contact)
          {
            title: 'Create a note in Obsidian',
            arg: "note contact #{entity.id}",
            icon: {
              path: "icons/obsidian.png"
            }
          }
        elsif entity.is_a?(Entities::Event)
          {
            title: 'Create a note in Obsidian',
            arg: "note event #{entity.id}",
            icon: {
              path: "icons/obsidian.png"
            }
          }
        else
          raise "Unsupported entity class for collaboration: #{entity.class}"
        end
      end

      class Root
        include PluginSupport

        def self.option_parser
          OptionParser.new do |parser|
            parser.banner = 'Return the root path on disk to the notes'
            parser.separator 'Usage: note root'
          end
        end

        def run
          puts @context.focus['obsidian'][:root]
        end
      end

      class List
        include PluginSupport

        def self.option_parser
          OptionParser.new do |parser|
            parser.banner = 'List all notes in this area'
            parser.separator 'Usage: note list'
          end
        end

        def run
          root = @context.focus['obsidian'][:root]
          notes = Dir.glob("#{root}/**/*.md").sort_by { |p| File.basename(p) }.reverse
          notes.map do |note|
            name = File.basename(note, '.md')
            {
              uid: name,
              title: name,
              subtitle: if triggered_as_snippet?
                          "Paste '#{name}' in the frontmost application"
                        else
                          "Select an action for '#{name}'"
                        end,
              arg: if triggered_as_snippet?
                     "[[#{name}]]"
                   else
                     "#{name}"
                   end,
              autocomplete: name,
            }
          end
        end
      end

      class NoteCommand
        include PluginSupport

        def initialize(context)
          context.arguments = [context.arguments.join(' ')]
          super(context)
        end

        def resolve_note
          note = Obsidian::load_entity(@context)
          root = @context.focus['obsidian'][:root]
          matches = Dir.glob("#{root}/**/#{note.id}.md")
          if matches.empty?
            nil
          else
            path = matches[0]
            filename = path[root.size..]
            return note, filename
          end
        end
      end

      class Commands < NoteCommand

        def self.option_parser
          OptionParser.new do |parser|
            parser.banner = 'List all available commands for the specified note'
            parser.separator 'Usage: note commands <noteId>'
            parser.separator ''
            parser.separator 'Where <noteID> is the ID of the note to act upon'
          end
        end

        def run
          note = Obsidian::load_entity(@context)
          commands = []
          commands << {
            title: 'Open in Obsidian',
            arg: "note edit #{note.id}",
            icon: {
              path: "icons/obsidian.png"
            }
          }
          commands << {
            title: 'Open in Marked 2',
            arg: "note view #{note.id}",
            icon: {
              path: "icons/marked.png"
            }
          }
          commands += @context.collaborator_commands(note)
        end
      end

      class Edit < NoteCommand

        def self.option_parser
          OptionParser.new do |parser|
            parser.banner = 'Opens the specified note in Obsidian for editing'
            parser.separator 'Usage: note edit <noteId>'
            parser.separator ''
            parser.separator 'Where <noteID> is the ID of the note edit'
          end
        end

        def run(runner = Shell::SystemRunner.new)
          note, path = resolve_note
          if path.nil?
            "Note with ID '#{note.id}' not found"
          else
            vault = @context.focus['obsidian'][:vault]
            callback = "obsidian://open?vault=#{vault.url_encode}&file=#{path.url_encode}"
            runner.execute('open', callback)
            #"Opened the note with ID '#{note.id}' in Obsidian"
            ''
          end
        end
      end

      class View < NoteCommand

        def self.option_parser
          OptionParser.new do |parser|
            parser.banner = 'Opens the specified note in Marked for viewing'
            parser.separator 'Usage: note view <noteId>'
            parser.separator ''
            parser.separator 'Where <noteID> is the ID of the note view'
          end
        end

        def run(runner = Shell::SystemRunner.new)
          note, path = resolve_note
          if path.nil?
            "Note with ID '#{note.id}' not found"
          else
            callback = "x-marked://open?file=#{path.url_encode}"
            runner.execute('open', callback)
            nil # No output here, as Obsidian has its own notification
          end
        end
      end

      class Plain
        include PluginSupport

        def self.option_parser
          OptionParser.new do |parser|
            parser.banner = 'Create a new, empty note, optionally with a title'
            parser.separator 'Usage: note plain [title]'
          end
        end

        def initialize(context)
          super(context)
          @template_set = template_set
        end

        def template_set
          :plain
        end

        def run(shell_runner = Shell::SystemRunner.new, jxa_runner = Jxa::Runner.new('obsidian'))
          context = create_context
          title = template(:title).render_template(context).strip
          filename_template = template(:filename)
          filename = if filename_template.nil?
                       title
                     else
                       filename_template.render_template(context).strip
                     end
          content = template(:text).render_template(context)
          tags = template(:tags)
                   .map { |t| t.render_template(context).strip }
                   .map { |t| "##{t}" }
                   .join(' ')
          text = "# #{title}\n"
          text += "\n#{content}" unless content.empty?
          text += "#{tags}" unless tags.empty?

          filename = Zaru.sanitize!(filename + ".md")
          path = File.join(@context.focus['obsidian'][:root], filename)
          vault = @context.focus['obsidian'][:vault]
          unless File.exist?(path)
            File.open(path, 'w') do |file|
              file.puts text
            end
            # Focus on Obsidian and give it some time, so that it can find the new file
            jxa_runner.execute('activate')
            sleep(0.5)
          end
          callback = "obsidian://open?vault=#{vault.url_encode}&file=#{filename.url_encode}"
          shell_runner.execute('open', callback)
          nil # No output here, as Obsidian has its own notification
        end

        def create_context
          query = @context.arguments.join(' ')
          date = DateTime.now
          {
            'year' => date.strftime('%Y'),
            'month' => date.strftime('%m'),
            'week' => date.strftime('%V'),
            'day' => date.strftime('%d'),
            'query' => query,
            'input' => query
          }
        end

        def template(sym)
          templates = @context.focus['obsidian'][:templates]
          templates[template_set][sym] || templates[:default][sym]
        end
      end

      class Project < Plain
        def self.option_parser
          OptionParser.new do |parser|
            parser.banner = 'Create a new note for a project'
            parser.separator 'Usage: note project <projectId>'
            parser.separator ''
            parser.separator 'Where <projectId> is the ID of the project to create a note for'
          end
        end

        def template_set
          :project
        end

        def can_run?
          is_entity_present?(Entities::Project) && is_entity_manager_available?(Entities::Project)
        end

        def run
          @project = @context.load_entity(Entities::Project)
          @custom_config = @project.config['obsidian'] || {}
          super
        end

        def template(sym)
          @custom_config[sym.to_s] || super(sym)
        end

        def create_context
          context = super
          context['input'] = @project.name
          context['name'] = @project.name
          context
        end
      end

      class Contact < Plain
        def self.option_parser
          OptionParser.new do |parser|
            parser.banner = 'Create a new note for a contact'
            parser.separator 'Usage: note contact <contactId>'
            parser.separator ''
            parser.separator 'Where <contactId> is the ID of the contact to create a note for'
          end
        end

        def template_set
          :contact
        end

        def can_run?
          is_entity_present?(Entities::Contact) && is_entity_manager_available?(Entities::Contact)
        end

        def run
          @contact = @context.load_entity(Entities::Contact)
          super
        end

        def create_context
          context = super
          context['input'] = @contact.name
          context['name'] = @contact.name
          context
        end
      end

      class Event < Plain
        def self.option_parser
          OptionParser.new do |parser|
            parser.banner = 'Create a new note for an event'
            parser.separator 'Usage: note event <eventId>'
            parser.separator ''
            parser.separator 'Where <eventId> is the ID of the event to create a note for'
          end
        end

        def template_set
          :event
        end

        def can_run?
          is_entity_present?(Entities::Event) && is_entity_manager_available?(Entities::Event)
        end

        def run
          @event = @context.load_entity(Entities::Event)
          super
        end

        def create_context
          context = super
          context['input'] = @event.title
          context['title'] = @event.title
          context['names'] = @event.people
          context
        end
      end

      class Today < Plain
        def self.option_parser
          OptionParser.new do |parser|
            parser.banner = 'Create or open today\'s note'
            parser.separator 'Usage: note today'
          end
        end

        def template_set
          :today
        end

        def can_run?
          is_entity_manager_available?(Entities::Event)
        end
      end
    end
  end
end