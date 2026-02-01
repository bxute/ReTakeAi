#!/usr/bin/env python3
import re
import uuid

def generate_xcode_uuid():
    """Generate a 24-character uppercase hex string for Xcode"""
    return uuid.uuid4().hex.upper()[:24]

def add_files_to_pbxproj(pbxproj_path):
    with open(pbxproj_path, 'r') as f:
        content = f.read()
    
    # Generate UUIDs for new entries
    view_file_ref_uuid = generate_xcode_uuid()
    viewmodel_file_ref_uuid = generate_xcode_uuid()
    view_build_file_uuid = generate_xcode_uuid()
    viewmodel_build_file_uuid = generate_xcode_uuid()
    group_uuid = generate_xcode_uuid()
    
    print(f"View File Ref UUID: {view_file_ref_uuid}")
    print(f"ViewModel File Ref UUID: {viewmodel_file_ref_uuid}")
    print(f"Group UUID: {group_uuid}")
    
    # 1. Add PBXBuildFile entries (for compilation)
    build_file_section = re.search(r'/\* Begin PBXBuildFile section \*/', content)
    if build_file_section:
        insert_pos = build_file_section.end()
        build_entries = f"""
		{view_build_file_uuid} /* AudioProcessorTestView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {view_file_ref_uuid} /* AudioProcessorTestView.swift */; }};
		{viewmodel_build_file_uuid} /* AudioProcessorTestViewModel.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {viewmodel_file_ref_uuid} /* AudioProcessorTestViewModel.swift */; }};"""
        content = content[:insert_pos] + build_entries + content[insert_pos:]
    
    # 2. Add PBXFileReference entries
    file_ref_section = re.search(r'/\* Begin PBXFileReference section \*/', content)
    if file_ref_section:
        insert_pos = file_ref_section.end()
        file_entries = f"""
		{view_file_ref_uuid} /* AudioProcessorTestView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AudioProcessorTestView.swift; sourceTree = "<group>"; }};
		{viewmodel_file_ref_uuid} /* AudioProcessorTestViewModel.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AudioProcessorTestViewModel.swift; sourceTree = "<group>"; }};"""
        content = content[:insert_pos] + file_entries + content[insert_pos:]
    
    # 3. Add PBXGroup for AudioProcessorTest folder
    # First, find the Features group
    features_group_match = re.search(r'([A-F0-9]{24}) /\* Features \*/ = \{[^}]+children = \([^)]+\);', content)
    if features_group_match:
        features_group_uuid = features_group_match.group(1)
        # Add our new group to Features children
        children_match = re.search(r'(' + features_group_uuid + r' /\* Features \*/ = \{[^}]+children = \()([^)]+)(\);)', content)
        if children_match:
            existing_children = children_match.group(2)
            new_children = existing_children.rstrip() + f"\n				{group_uuid} /* AudioProcessorTest */,"
            content = content.replace(children_match.group(2), new_children)
    
    # Add the AudioProcessorTest group definition
    group_section = re.search(r'/\* Begin PBXGroup section \*/', content)
    if group_section:
        insert_pos = group_section.end()
        group_entry = f"""
		{group_uuid} /* AudioProcessorTest */ = {{
			isa = PBXGroup;
			children = (
				{view_file_ref_uuid} /* AudioProcessorTestView.swift */,
				{viewmodel_file_ref_uuid} /* AudioProcessorTestViewModel.swift */,
			);
			path = AudioProcessorTest;
			sourceTree = "<group>";
		}};"""
        content = content[:insert_pos] + group_entry + content[insert_pos:]
    
    # 4. Add to PBXSourcesBuildPhase (so files are compiled)
    sources_phase_match = re.search(r'([A-F0-9]{24}) /\* Sources \*/ = \{[^}]+files = \([^)]+\);', content)
    if sources_phase_match:
        sources_uuid = sources_phase_match.group(1)
        files_match = re.search(r'(' + sources_uuid + r' /\* Sources \*/ = \{[^}]+files = \()([^)]+)(\);)', content)
        if files_match:
            existing_files = files_match.group(2)
            new_files = existing_files.rstrip() + f"\n				{view_build_file_uuid} /* AudioProcessorTestView.swift in Sources */,\n				{viewmodel_build_file_uuid} /* AudioProcessorTestViewModel.swift in Sources */,"
            content = content.replace(files_match.group(2), new_files)
    
    # Write back
    with open(pbxproj_path, 'w') as f:
        f.write(content)
    
    print("✅ Files added to Xcode project successfully!")

if __name__ == "__main__":
    add_files_to_pbxproj('ReTakeAi.xcodeproj/project.pbxproj')
