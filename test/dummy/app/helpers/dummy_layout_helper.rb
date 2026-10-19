# frozen_string_literal: true

module DummyLayoutHelper
  def dummy_document_attributes
    attributes = { "data-theme" => "rounded", lang: I18n.locale.to_s }
    attributes.merge!(recording_studio_locale_attributes) if respond_to?(:recording_studio_locale_attributes)
    return attributes unless respond_to?(:flat_pack_copy_data)

    attributes[:data] = (attributes[:data] || {}).merge(flat_pack_copy_data)
    attributes
  end
end
