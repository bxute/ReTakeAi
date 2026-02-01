require 'xcodeproj'

project = Xcodeproj::Project.open('ReTakeAi.xcodeproj')

puts "=== All Groups and References ==="
def print_tree(item, indent = 0)
  prefix = "  " * indent
  puts "#{prefix}#{item.display_name} (#{item.class.name.split('::').last})"
  if item.respond_to?(:children)
    item.children.each { |child| print_tree(child, indent + 1) }
  elsif item.respond_to?(:groups)
    item.groups.each { |group| print_tree(group, indent + 1) }
  end
end

print_tree(project.main_group)

puts "\n=== File System Synchronized Groups ==="
project.objects.select { |obj| obj.class.name.include?('FileSystemSynchronized') }.each do |obj|
  puts "#{obj.class.name}: #{obj.path}"
end
