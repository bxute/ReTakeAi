#!/usr/bin/env ruby

# Add RNNoise files to Xcode project
# Usage: ruby add_rnnoise_files.rb

require 'xcodeproj'

project_path = 'ReTakeAi.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.first

# Find groups
core_audio_processors = project['ReTakeAi/Core/Audio/Processors']
features_test = project['ReTakeAi/Features/AudioProcessorTest']

# Files to add
files_to_add = [
  {
    path: 'ReTakeAi/Core/Audio/Processors/RNNoiseProcessor.swift',
    group: core_audio_processors,
    description: 'RNNoise Processor'
  },
  {
    path: 'ReTakeAi/Features/AudioProcessorTest/RNNoiseDebugView.swift',
    group: features_test,
    description: 'RNNoise Debug View'
  },
  {
    path: 'ReTakeAi/Features/AudioProcessorTest/RNNoiseDebugViewModel.swift',
    group: features_test,
    description: 'RNNoise Debug ViewModel'
  }
]

puts "Adding RNNoise files to Xcode project..."

files_to_add.each do |file_info|
  file_path = file_info[:path]
  group = file_info[:group]

  if File.exist?(file_path)
    # Check if file is already in project
    existing_file = group.files.find { |f| f.path == File.basename(file_path) }

    if existing_file
      puts "  ⚠️  #{file_info[:description]} already exists in project"
    else
      # Add file reference
      file_ref = group.new_file(file_path)

      # Add to compile sources if it's a Swift file
      if file_path.end_with?('.swift')
        target.add_file_references([file_ref])
      end

      puts "  ✅ Added #{file_info[:description]}"
    end
  else
    puts "  ❌ File not found: #{file_path}"
  end
end

# Save project
project.save

puts "\n✅ Done! RNNoise files added to Xcode project."
puts "\nNext steps:"
puts "1. Open ReTakeAi.xcodeproj in Xcode"
puts "2. Build the project (Cmd+B) to verify no errors"
puts "3. Add navigation to RNNoiseDebugView"
puts "4. Start testing with audio files!"
