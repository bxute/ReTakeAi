require 'xcodeproj'

project = Xcodeproj::Project.open('ReTakeAi.xcodeproj')

puts "=== Main Group Structure ==="
puts "Main group class: #{project.main_group.class}"
puts "Main group children count: #{project.main_group.groups.count}"

project.main_group.groups.each do |group|
  puts "\nGroup: #{group.display_name} (#{group.class})"
  puts "  Path: #{group.path}"
  puts "  Source tree: #{group.source_tree}"
end

puts "\n=== Targets ==="
project.targets.each do |target|
  puts "Target: #{target.name}"
  puts "  Source files count: #{target.source_build_phase.files.count}"
end
