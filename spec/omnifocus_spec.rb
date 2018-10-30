require 'spec_helper'
require 'omnifocus'

describe OmniFocus, '#projects' do
  context 'when passed a valid configuration' do

    area = {
      omnifocus: {
        folder: 'Foo',
      },
      markdown_notes: {}
    }

    it 'lists all projects in the configured OmniFocus folder in shortcut mode' do
      expected = [
        {
          uid: 'foo',
          title: 'Foo',
          subtitle: "Select an action for 'Foo'",
          arg: 'Foo',
          variables: {
            id: 'foo',
            name: 'Foo'
          },
          autocomplete: 'Foo',
        }
      ]
      projects = OmniFocus::projects(area: area, runner: OmniFocusStubRunner.new)
      expect(projects).to eq(expected)
    end

    it 'lists all projects in the configured OmniFocus folder in snippet mode' do
      expected = [
        {
          uid: 'foo',
          title: 'Foo',
          subtitle: "Paste 'Foo' in the frontmost application",
          arg: 'Foo',
          variables: {
            id: 'foo',
            name: 'Foo'
          },
          autocomplete: 'Foo',
        }
      ]
      projects = OmniFocus::projects(true, area: area, runner: OmniFocusStubRunner.new)
      expect(projects).to eq(expected)
    end

    it 'lists all available actions for a specific project' do
      expected = [
        {
          title: "Open in OmniFocus",
          arg: 'omnifocus://task/foo',
          variables: {
            action: 'open'
          }
        },
        {
          title: "Create note",
          arg: 'Foo',
          variables: {
            action: 'create-markdown-note'
          }
        },
        {
          title: "Search notes",
          arg: 'Foo',
          variables: {
            action: 'search-markdown-notes'
          }
        },
        {
          title: "Paste in frontmost application",
          arg: 'Foo',
          variables: {
            action: 'snippet'
          }
        }
      ]
      actions = OmniFocus::actions({id: 'foo', name: 'Foo'}, area: area)
      expect(actions).to eq(expected)
    end

    it 'can set the focus in OmniFocus to the right folder' do
      stub = OmniFocusStubRunner.new
      omnifocus = OmniFocus.new(stub)
      omnifocus.change(area, {})
      expect(stub.script[:name]).to eq('omnifocus-set-focus')
      expect(stub.script[:arg]).to eq('Foo')
    end
  end
end

class OmniFocusStubRunner
  attr_reader :script

  def execute(script, *args)
    @script = {name: script, arg: args[0]}
    folder = args[0]
    [{
       'id' => folder.downcase,
       'name' => folder
     }]
  end
end