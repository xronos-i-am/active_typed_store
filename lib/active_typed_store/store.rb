# frozen_string_literal: true

module ActiveTypedStore
  module Store

    JSON_NOT_SERIALIZED_TYPES = [
      ActiveModel::Type::Date,
      ActiveModel::Type::DateTime,
      ActiveModel::Type::Time,
    ].freeze

    def typed_store(store_attribute, attrs)
      store_accessor store_attribute, attrs.keys

      attrs.each do |key, value_klass|
        key = key.to_s
        define_method("#{key}?") do
          read_store_attribute(store_attribute, key).present?
        end

        _setter_for_typed_store(store_attribute, key, value_klass)
        _getter_for_typed_store(key, value_klass)
      end
    end

    def _setter_for_typed_store(store_attribute, key, value_klass)
      if value_klass.name.start_with?('ActiveModel::Type::')
        define_method("#{key}=") do |value|
          v = value_klass.new.cast(value)
          v = v.presence unless v.is_a?(FalseClass)
          write_store_attribute(store_attribute, key, v)
          self[store_attribute].delete(key) if v.nil?
        end
      else
        define_method("#{key}=") do |value|
          v = value.nil? ? nil : value_klass[value]
          v = v.presence unless v.is_a?(FalseClass)
          write_store_attribute(store_attribute, key, v)
          self[store_attribute].delete(key) if v.nil?
        end
      end
    end

    def _getter_for_typed_store(key, value_klass)
      if JSON_NOT_SERIALIZED_TYPES.include?(value_klass)
        define_method(key) do
          val = super()
          value_klass.new.cast(val) unless val.nil?
        end
      elsif value_klass.is_a?(Dry::Types::Default)
        define_method(key) do
          val = super()
          # value_klass.value возвращает default
          # value_klass[nil] для optional типов возвращает не default-значение, а nil
          val.nil? ? value_klass.value : val
        end
      end
    end

  end
end
