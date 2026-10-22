# frozen_string_literal: true

module RecordingStudioViews
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioViews

    class << self
      def apply_model_extensions(target)
        apply_extensions(target, extensions_for(:model, extension_keys_for(target)))
      end

      def apply_controller_extensions(target)
        apply_extensions(target, extensions_for(:controller, extension_keys_for(target)))
      end

      private

      def extensions_for(kind, names)
        hooks = RecordingStudioViews.configuration.hooks
        Array(names).flat_map do |name|
          if kind == :model
            hooks.model_extensions_for(name)
          else
            hooks.controller_extensions_for(name)
          end
        end
      end

      def apply_extensions(target, extensions)
        return unless target

        applied = target.instance_variable_get(:@recording_studio_views_applied_extensions) || identity_hash

        extensions.flatten.compact.each do |extension|
          next if applied[extension]

          target.class_eval(&extension)
          applied[extension] = true
        end

        target.instance_variable_set(:@recording_studio_views_applied_extensions, applied)
      end

      def extension_keys_for(target)
        names = [target.name, target.name&.demodulize].compact.uniq
        names.map(&:to_sym)
      end

      def identity_hash
        {}.compare_by_identity
      end
    end

    class << self
      def load_x_config(app)
        return unless app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_views)

        merge_x_config(app.config.x.recording_studio_views)
      end

      def merge_x_config(xcfg)
        return RecordingStudioViews.configuration.merge!(xcfg.to_h) if xcfg.respond_to?(:to_h)
        return unless xcfg.respond_to?(:each_pair)

        hash = {}
        xcfg.each_pair { |key, value| hash[key] = value }
        RecordingStudioViews.configuration.merge!(hash) if hash.any?
      end

      def yaml_config_path(app)
        if app.respond_to?(:paths) && (config_paths = app.paths["config"])
          first = Array(config_paths.respond_to?(:existent) ? config_paths.existent : config_paths).first
          File.join(first, "recording_studio_views.yml") if first
        elsif app.respond_to?(:root) && app.root
          File.join(app.root, "config", "recording_studio_views.yml")
        end
      end
    end

    initializer "recording_studio_views.before_initialize", before: "recording_studio_views.load_config" do |_app|
      RecordingStudioViews.configuration.hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_views.load_config" do |app|
      if app.respond_to?(:config_for)
        path = Engine.yaml_config_path(app)
        if path && File.exist?(path)
          yaml = app.config_for(:recording_studio_views)
          RecordingStudioViews.configuration.merge!(yaml) if yaml.respond_to?(:each)
        end
      end
      Engine.load_x_config(app)
      RecordingStudioViews.configuration.hooks.run(:on_configuration, RecordingStudioViews.configuration)
    end

    initializer "recording_studio_views.after_initialize", after: "recording_studio_views.load_config" do |_app|
      RecordingStudioViews.configuration.hooks.run(:after_initialize, self)
    end

    initializer "recording_studio_views.helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        helper RecordingStudioViews::TrackHelper
      end
      ActiveSupport.on_load(:action_view) do
        include RecordingStudioViews::TrackHelper
      end
    end

    initializer "recording_studio_views.assets" do |app|
      javascripts = root.join("app/assets/javascripts")
      app.config.assets.paths << javascripts if app.config.respond_to?(:assets) && Dir.exist?(javascripts)
    end

    initializer "recording_studio_views.apply_model_extensions" do
      config.to_prepare do
        next unless defined?(ActiveRecord::Base)

        ActiveRecord::Base.descendants.each do |model|
          next if model.abstract_class?

          RecordingStudioViews::Engine.apply_model_extensions(model)
        end
      end
    end

    initializer "recording_studio_views.register_view_log" do
      config.to_prepare { RecordingStudioViews.register_view_log! }
    end

    initializer "recording_studio_views.admin" do
      config.to_prepare do
        next unless defined?(::RecordingStudioAdmin)

        require "recording_studio_views/admin"
        RecordingStudioViews::Admin.register!
      end
    end

    initializer "recording_studio_views.apply_controller_extensions" do
      config.to_prepare do
        next unless defined?(ActionController::Base)

        ActionController::Base.descendants.each do |controller|
          RecordingStudioViews::Engine.apply_controller_extensions(controller)
        end
      end
    end
  end
end
