module VPS
  module Plugins
    module Mail
      def self.configure_plugin(plugin)
        plugin.configurator_class = Configurator
        plugin.for_entity(Entities::Mail)
        plugin.add_command(Email, :single)
        plugin.add_collaboration(Entities::Contact)
      end

      class Configurator < PluginSupport::Configurator
        def read_area_configuration(area, hash)
          {
            from: hash['from'] || nil
          }
        end
      end

      def self.commands_for(area, entity)
        if entity.is_a?(Entities::Contact)
          {
            title: 'Write an e-mail in Mail',
            arg: "mail email #{entity.id}",
            icon: {
              path: "icons/mail.png"
            }
          }
        else
          raise "Unsupported entity class for collaboration: #{entity.class}"
        end
      end

      class Email
        include PluginSupport

        def self.option_parser
          OptionParser.new do |parser|
            parser.banner = 'Prepare an email to the specified contact'
            parser.separator 'Usage: mail email <contactId>'
            parser.separator ''
            parser.separator 'Where <contactId> is the ID of the contact to write a mail to'
          end
        end

        def can_run?
          is_entity_present?(Entities::Contact)
        end

        def run(runner = Jxa::Runner.new('mail'))
          contact = Contacts::load_entity(@context)
          address_line = "#{contact.name} <#{contact.email}>"
          from = @context.focus['mail'][:from]
          runner.execute('create-email', address_line, from)
          nil
        end
      end
    end
  end
end