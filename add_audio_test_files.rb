require 'xcodeproj'

project_path = 'ReTakeAi.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "Project structure:"
project.main_group.recursive_children.select { |c| c.display_name == 'Features' }.each do |group|
  puts "Found: #{group.display_name} (#{group.class})"
end

# Get the main target
target = project.targets.find { |t| t.name == 'ReTakeAi' }

# Navigate to Features group manually
retake_group = project.main_group.children.find { |g| g.display_name == 'ReTakeAi' }
features_group = retake_group.children.find { |g| g.display_name == 'Features' }

if features_group.nil?
  puts "❌ Could not find Features group"
  exit 1
end

puts "Found Features group: #{features_group.class}"

# Create AudioProcessorTest group
audio_test_group = features_group.new_group('AudioProcessorTest', 'ReTakeAi/Features/AudioProcessorTest')

# Add files
view_file = audio_test_group.new_reference('AudioProcessorTestView.swift')
viewmodel_file = audio_test_group.new_reference('AudioProcessorTestViewModel.swift')

# Add to target build phase
target.source_build_phase.add_file_reference(view_file)
target.source_build_phase.add_file_reference(viewmodel_file)

# Save
project.save

puts "✅ Successfully added AudioProcessorTest files to project!"
puts "   - AudioProcessorTestView.swift"
puts "   - AudioProcessorTestViewModel.swift"
