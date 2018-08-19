require 'json'

def alfred_single
  puts yield
rescue RuntimeError => e
  puts "Error: #{e}"
end

def alfred_items
  puts_items(yield)
rescue RuntimeError => e
  puts_exception_as_items(e)
end

private

def puts_items(items)
  result = {
    items: items
  }
  puts result.to_json
end

def puts_exception_as_items(exception)
  result = {
    items: [
      {
        title: "Error: #{exception}",
        valid: false
      }
    ]
  }
  puts result.to_json
end
