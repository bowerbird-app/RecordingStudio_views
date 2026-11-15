# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

bootstrap_owner_access = lambda do |recording, actor|
  current_role = RecordingStudioAccessible.role_for(actor: actor, recording: recording)
  next if current_role == :admin

  result = RecordingStudioAccessible.bootstrap_owner_access!(
    recording: recording,
    actor: actor
  )
  raise "Failed to bootstrap owner access: #{result.error}" if result.failure?
end

find_or_record_child = lambda do |recordable, root_recording, parent_recording|
  RecordingStudio::Recording.kept.find_by(
    root_recording: root_recording,
    parent_recording: parent_recording,
    recordable: recordable
  ) || RecordingStudio.record!(
    action: "created",
    recordable: recordable,
    root_recording: root_recording,
    parent_recording: parent_recording
  ).recording
end

# Create the admin user
user = User.find_or_create_by!(email: "admin@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

# Create the workspace recordables
workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
accessible_workspace = Workspace.find_or_create_by!(name: "Client Workspace")
private_workspace = Workspace.find_or_create_by!(name: "Private Workspace")
folder = Folder.find_or_create_by!(name: "Product Docs")
page = Page.find_or_create_by!(title: "Getting Started")
client_page = Page.find_or_create_by!(title: "Client Brief")

previous_actor = Current.actor
Current.actor = user

begin
  # Create the root recording. root_recording_for only finds one.
  root_recording = RecordingStudio.create_root_recording!(workspace, actor: user)
  accessible_root_recording = RecordingStudio.create_root_recording!(accessible_workspace, actor: user)
  private_root_recording = RecordingStudio.create_root_recording!(private_workspace, actor: user)

  # Accessible grants must exist before child writes. authorize_write
  # checks :edit on the root; Access rows themselves use AccessCreationContext.
  # A persisted user may create a root when root_recording is nil.
  bootstrap_owner_access.call(root_recording, user)
  bootstrap_owner_access.call(accessible_root_recording, user)

  admin_root = AdminRoot.find_or_create_by!(name: "Admin")
  admin_root_recording = RecordingStudio.create_root_recording!(admin_root, actor: user)
  bootstrap_owner_access.call(admin_root_recording, user)

  folder_recording = find_or_record_child.call(folder, root_recording, root_recording)

  find_or_record_child.call(page, root_recording, folder_recording)
  find_or_record_child.call(client_page, accessible_root_recording, accessible_root_recording)
ensure
  Current.actor = previous_actor
end

puts "Seeded: admin@admin.com / Password"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Workspace '#{accessible_workspace.name}' with root recording ##{accessible_root_recording.id}"
puts "Seeded: Workspace '#{private_workspace.name}' with root recording ##{private_root_recording.id}"
puts "Seeded: Folder '#{folder.name}' and page '#{page.title}'"
puts "Seeded: Page '#{client_page.title}' under '#{accessible_workspace.name}'"
