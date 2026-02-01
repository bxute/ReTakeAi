require 'xcodeproj'

project_path = 'ReTakeAi.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Find the Features group
features_group = project.main_group['ReTakeAi']['Features']

# Create AudioProcessorTest group if it doesn't exist
audio_test_group = features_group.new_group('AudioProcessorTest', 'ReTakeAi/Features/AudioProcessorTest')

# Add the files
view_file = audio_test_group.new_file('ReTakeAi/Features/AudioProcessorTest/AudioProcessorTestView.swift')
viewmodel_file = audio_test_group.new_file('ReTakeAi/Features/AudioProcessorTest/AudioProcessorTestViewModel.swift')

# Add files to target
target.add_file_references([view_file, viewmodel_file])

# Save the project
project.save

puts "Files added successfully!"
