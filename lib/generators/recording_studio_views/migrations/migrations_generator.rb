# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module RecordingStudioViews
  module Generators
    class MigrationsGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Copy RecordingStudioViews migrations to your application"

      class_option :skip_existing, type: :boolean, default: true,
                                   desc: "Skip migrations that already exist (based on name, ignoring timestamp)"
      class_option :partitioned, type: :boolean, default: false,
                                 desc: "Install monthly partitioned raw view logs"

      def copy_migrations
        say "Installing #{options[:partitioned] ? 'partitioned' : 'ordinary'} view log migrations:", :green
        copy_named_migration("create_recording_studio_views_view_logs", view_logs_body)
        copy_engine_migration("create_recording_studio_views_view_receipts.rb")
        copy_engine_migration("create_recording_studio_views_daily_view_summaries.rb")
        copy_engine_migration("add_ip_and_user_agent_to_recording_studio_views_view_logs.rb")
        say "\nRun 'bin/rails db:migrate' to apply the migrations.", :green
        say partition_note, :yellow if options[:partitioned]
      end

      private

      def view_logs_body
        <<~RUBY
          class CreateRecordingStudioViewsViewLogs < ActiveRecord::Migration[8.1]
            def up
              RecordingStudioViews::Schema.create_view_logs!(partitioned: #{options[:partitioned]}, connection: connection)
            end

            def down
              drop_table RecordingStudioViews::Schema::VIEW_LOGS, if_exists: true, force: :cascade
            end
          end
        RUBY
      end

      def partition_note
        "Schedule RecordingStudioLogs::PartitionMaintenanceJob. " \
          "Registration follows the installed table, not an initializer flag."
      end

      def copy_named_migration(migration_name, contents)
        if options[:skip_existing] && migration_exists?("#{migration_name}.rb")
          say "  skip  #{migration_name} (already exists)", :yellow
          return
        end

        destination_path = File.join("db/migrate", "#{next_migration_number}_#{migration_name}.rb")
        create_file destination_path, contents
        sleep 0.1
      end

      def copy_engine_migration(filename)
        source_path = File.join(engine_migrate_path, filename)
        unless File.exist?(source_path)
          matching = Dir.glob(File.join(engine_migrate_path, "*_#{filename}"))
          source_path = matching.first
        end
        return say("  skip  #{filename} (missing)", :yellow) if source_path.blank?

        migration_name = File.basename(source_path).sub(/^\d+_/, "")
        if options[:skip_existing] && migration_exists?(migration_name)
          say "  skip  #{migration_name} (already exists)", :yellow
          return
        end

        destination_path = File.join("db/migrate", "#{next_migration_number}_#{migration_name}")
        create_file destination_path, File.read(source_path)
        sleep 0.1
      end

      def engine_migrate_path
        File.expand_path("../../../../db/migrate", __dir__)
      end

      def migration_exists?(migration_name)
        Dir.glob(File.join(destination_root, "db/migrate", "*_#{migration_name}")).any?
      end

      def next_migration_number
        ActiveRecord::Migration.next_migration_number(
          Time.now.utc.strftime("%Y%m%d%H%M%S")
        )
      end
    end
  end
end
