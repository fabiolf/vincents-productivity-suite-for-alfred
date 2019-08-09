module VPS

  ##
  # Registration of all plugins, the commands they support, and so on.
  # Any new plugin needs to be added here.
  module Registry
    PLUGINS = {
      area: {
        manages: :area,
        module: VPS::Area,
        commands: {
          list: {
            class: VPS::Area::List,
            type: :list
          },
          focus: {
            class: VPS::Area::Focus,
            type: :single
          }
        },
      },
      bear: {
        module: VPS::Bear,
        manages: :note,
        commands: {
          plain: {
            class: VPS::Bear::PlainNote,
            type: :single
          },
          project: {
            class: VPS::Bear::ProjectNote,
            type: :single
          },
          contact: {
            class: VPS::Bear::ContactNote,
            type: :single
          }
        },
        collaborates: [:project, :contact]
      },
      bitbar: {
        module: VPS::BitBar,
        action: VPS::BitBar::Refresh
      },
      contacts: {
        manages: :contact,
        module: VPS::Contacts,
        commands: {
          list: {
            class: VPS::Contacts::List,
            type: :list
          },
          open: {
            class: VPS::Contacts::Open,
            type: :single
          },
          email: {
            class: VPS::Contacts::Email,
            type: :single
          },
          commands: {
            class: VPS::Contacts::Commands,
            type: :list
          }
        }
      },
      files: {
        manages: :file,
        module: VPS::Files,
        commands: {
          browse: {
            class: VPS::Files::Browse,
            type: :single
          },
          project: {
            class: VPS::Files::Project,
            type: :single
          }
        },
        collaborates: [:project]
      },
      omnifocus: {
        manages: :project,
        module: VPS::OmniFocus,
        action: VPS::OmniFocus::Focus,
        commands: {
          list: {
            class: VPS::OmniFocus::List,
            type: :list
          },
          open: {
            class: VPS::OmniFocus::Open,
            type: :single
          },
          commands: {
            class: VPS::OmniFocus::Commands,
            type: :list
          }
        }
      },
      wallpaper: {
        module: VPS::Wallpaper,
        action: VPS::Wallpaper::Replace
      }
    }
    private_constant :PLUGINS

    def self.commands
      PLUGINS.select { |_, definition| definition.has_key? :commands }
    end

    def self.plugins
      PLUGINS
    end

    def self.available_managers
      PLUGINS.select do |_, definition|
        definition.has_key?(:manages)
      end
    end

    def self.managers(type)
      PLUGINS.select do |_, definition|
        definition.has_key?(:manages) && definition[:manages] == type
      end
    end

    def self.collaborators(type)
      PLUGINS.select do |_, definition|
        definition.has_key?(:collaborates) && definition[:collaborates].include?(type)
      end
    end
  end
end