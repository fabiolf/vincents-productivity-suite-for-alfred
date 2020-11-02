module VPS
  module Plugins
    # Plugin for the note-keeping app Bear.
    #
    # *Warning*: I'm not using Bear myself anymore, so I'm not guaranteeing this plugin is going
    # to work perfectly!
    module Bear
      include Plugin

      class BearConfigurator < Configurator
        include NoteSupport::Configurator

        def process_area_configuration(area, hash)
          config = {
            #tag: hash['tag'] || area[:name],
            tag: hash['tag'],
            projecttag: hash['projecttag'],
            token: hash['token'] || 'TOKEN_NOT_CONFIGURED'
          }
          process_templates(config, hash)
          config
        end
      end

      class BearNoteRepository < Repository
        def supported_entity_type
          EntityType::Note
        end

        def find_all(context, runner = Xcall.instance)
          tag = context.configuration[:tag]
          token = context.configuration[:token]
          term = context.arguments.join(' ').url_encode
          callback = "bear://x-callback-url/search?show_window=no&token=#{token}"
          callback += "&tag=#{tag}" unless tag.nil?
          callback += "&term=#{term}" unless term.empty?
          output = runner.execute(callback)
          if output.nil? || output.empty?
            return []
          end
          JSON.parse(output['notes']).map do |record|
            EntityType::Note.new do |note|
              note.id = record['identifier']
              note.title = record['title']
            end
          end
        end

        def load_instance(context, runner = Xcall.instance, jxa_runner = JxaRunner.new('Bear'))
          # puts "BearNoteRepo load_instance"
          if context.environment['NOTE_ID'].nil?
            id = context.arguments[0]
            return nil if id.nil?
            token = context.configuration[:token]
            jxa_runner.execute('activate')
            callback = "bear://x-callback-url/open-note?id=#{id.url_encode}&show_window=no&token=#{token}"
            record = runner.execute(callback)
            EntityType::Note.new do |note|
              note.id = id
              note.title = record['title'] || nil
            end
          else
            EntityType::Note.from_env(context.environment)
          end
        end

        def create_or_find(context, note, runner = Xcall.instance, jxa_runner = JxaRunner.new('Bear'))
          # puts "create or find note"
          token = context.configuration[:token]
          title = note.title.url_encode
          #trimming the text here to avoid the double new lines between the text and the tags
          text = note.text.strip.url_encode
          tags = note.tags.map { |t| t.url_encode }.join(',')
          callback = "bear://x-callback-url/create?title=#{title}&tags=#{tags}&token=#{token}"
          output = runner.execute(callback)
          note.id = output['identifier']
          if !text.empty?
            callback = "bear://x-callback-url/add-text?id=#{note.id}&mode=prepend&text=#{text}&new_line=no"
            output = runner.execute(callback)
          end
          jxa_runner.execute('activate')
          note
        end
      end

      class BearProjectRepository < Repository
        def supported_entity_type
          EntityType::Project
        end

        def find_all(context, runner = Xcall.instance)
          # puts "project find_all"
          projecttag = context.configuration[:projecttag]
          # puts "projecttag [#{projecttag}]"
          token = context.configuration[:token]
          # puts "token [#{token}]"
          term = context.arguments.join(' ').url_encode
          # puts "term [#{term}]"
          callback = "bear://x-callback-url/search?show_window=no&token=#{token}"
          callback += "&tag=#{projecttag}" unless projecttag.nil?
          callback += "&term=#{term}" unless term.empty?
          # puts "callback [#{callback}]"
          output = runner.execute(callback)
          # puts "output [#{output}]"
          if output.nil? || output.empty?
            return []
          end
          JSON.parse(output['notes']).map do |record|
            EntityType::Project.new do |project|
              project.id = record['identifier']
              project.name = record['title']
              project.note = record['identifier'] #don't know if I need this
            end
          end
        end

        def load_instance(context, runner = Xcall.instance, jxa_runner = JxaRunner.new('Bear'))
          puts "BearProjectRepository load_instance"
          if context.environment['PROJECT_ID'].nil?
            id = context.arguments[0]
            return nil if id.nil?
            token = context.configuration[:token]
            jxa_runner.execute('activate')
            callback = "bear://x-callback-url/open-note?id=#{id.url_encode}&show_window=no&token=#{token}"
            record = runner.execute(callback)
            EntityType::Note.new do |note|
              note.id = id
              note.title = record['title'] || nil
            end
          else
            EntityType::Note.from_env(context.environment)
          end
        end

        def create_note_for_project(context, project, runner = Xcall.instance, jxa_runner = JxaRunner.new('Bear'))
          token = context.configuration[:token]
          # title = note.title.url_encode
          # #trimming the text here to avoid the double new lines between the text and the tags
          # text = note.text.strip.url_encode
          # tags = note.tags.map { |t| t.url_encode }.join(',')
          # callback = "bear://x-callback-url/create?title=#{title}&tags=#{tags}&token=#{token}"
          # output = runner.execute(callback)
          # note.id = output['identifier']
          # if !text.empty?
          #   callback = "bear://x-callback-url/add-text?id=#{note.id}&mode=prepend&text=#{text}&new_line=no"
          #   output = runner.execute(callback)
          # end
          # jxa_runner.execute('activate')
          puts "project create_or_find"
          project
        end

      end

      class List < EntityTypeCommand
        include NoteSupport::List
      end

      module BearNote
        def supported_entity_type
          EntityType::Note
        end

        def run(context, runner = Xcall.instance, jxa_runner = JxaRunner.new('Bear'))
          # puts "BearNote run"
          # note = if self.is_a?(VPS::Plugin::EntityInstanceCommand) || self.is_a?(VPS::Plugin::CollaborationCommand)
          note = if self.is_a?(VPS::Plugin::EntityInstanceCommand)
                   # puts "EntityInstanceCommand"
                   context.load_instance
                 else
                   # puts "not EntityInstanceCommand"
                   create_note(context)
                 end
          token = context.configuration[:token]
          callback = "bear://x-callback-url/open-note?id=#{note.id.url_encode}&token=#{token}"
          runner.execute(callback)
          jxa_runner.execute('activate')
          "Opened note '#{note.title}' in Bear"
        end
      end

      class Open < EntityInstanceCommand
        include BearNote

        def option_parser
          OptionParser.new do |parser|
            parser.banner = 'Open in Bear'
            parser.separator 'Usage: note open <noteId>'
            parser.separator ''
            parser.separator 'Where <noteID> is the ID of the note to open'
          end
        end
      end

      class Create < EntityTypeCommand
        include NoteSupport::PlainTemplateNote, BearNote
      end

      class Today < EntityTypeCommand
        include NoteSupport::TodayTemplateNote, BearNote
      end

      class ListProject < EntityTypeCommand
        def name
          'list'
        end

        def supported_entity_type
          EntityType::Project
        end

        def option_parser
          OptionParser.new do |parser|
            parser.banner = 'List all available projects in this area'
            parser.separator 'Usage: project list'
          end
        end

        def run(context)
          context.find_all.map do |project|
            {
                uid: project.id,
                title: project.name,
                subtitle: if context.triggered_as_snippet?
                            "Paste '#{project.name}' in the frontmost application"
                          else
                            "Select an action for '#{project.name}'"
                          end,
                arg: project.name,
                autocomplete: project.name,
                variables: project.to_env
            }
          end
        end
      end

      class CreateProject < EntityTypeCommand
        def name
          'create'
        end

        def supported_entity_type
          EntityType::Project
        end

        def option_parser
          OptionParser.new do |parser|
            parser.banner = 'Create a new project in Bear'
            parser.separator 'Usage: project create <projectName>'
            parser.separator ''
            parser.separator 'Where <projectName> is the name of the project to create'
          end
        end

        #TODO method to create a project based on the Project Template
      end

      #class responsible for the 'open' command under 'project'
      class OpenProject < EntityInstanceCommand
        def name
          'open'
        end
        include NoteSupport::ProjectTemplateNote, BearNote
      end

      #class responsible for the 'note' command under 'project'
      class NoteForProject < CollaborationCommand
        def name
          'note'
        end
        def supported_entity_type
          EntityType::Project
        end
        def option_parser
          OptionParser.new do |parser|
            parser.banner = 'Create a new note for this project'
            parser.separator 'Usage: project note <projectId>'
            parser.separator ''
            parser.separator 'Where <projectId> is the ID of the project to create a note for'
          end
        end

        def create_note(context)
          # puts "1b"
          template_context = create_template_context(context)
          # puts "1.5"
          # filename_template = template(context, :filename)
          # puts "2"
          note = EntityType::Note.new do |n|
            # puts "before n.title"
            n.title = template(context, :title).render_template(template_context).strip
            # puts "before n.id"
            # n.id = if filename_template.nil?
                     n.title
                   # else
                   #   filename_template.render_template(template_context).strip
                   # end
            n.id = Zaru.sanitize!(n.id)
            n.text = template(context, :text).render_template(template_context)
            n.tags = template(context, :tags)
                         .map { |t| t.render_template(template_context).strip }
          end
          # puts "before create_or_find"
          context.create_or_find(note, EntityType::Project)
          # puts "after create_or_find"
        end
        include NoteSupport::PlainTemplateNote, BearNote
      end

      class Contact < CollaborationCommand
        include NoteSupport::ContactTemplateNote, BearNote
      end

      class Event < CollaborationCommand
        include NoteSupport::EventTemplateNote, BearNote
      end
    end
  end
end
