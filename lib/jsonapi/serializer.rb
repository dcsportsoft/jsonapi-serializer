require 'fast_jsonapi'

module JSONAPI
  module Serializer
    # TODO: Move and cleanup the old implementation...
    def self.included(base)
      base.class_eval do
        include FastJsonapi::ObjectSerializer
      end
    end
  end

  module PolymorphicSerializer
    def self.included(base)
      base.class_eval do
        include FastJsonapi::ObjectSerializer

        def initialize(resource, options={})
          @resource = resource

          process_options(options)
        end

        def hash_for_collection
          serializable_hash = {}

          data = []
          included = []
          @resource.each do |record|
            serializer = serializer_for(record)
            serializer_includes = @includes & Array(serializer.relationships_to_serialize&.keys)

            data << serializer.record_hash(record, @fieldsets[self.class.record_type.to_sym], serializer_includes, @params)
            included.concat serializer.get_included_records(record, @includes, @known_included_objects, @fieldsets, @params) if serializer_includes.present?
          end

          serializable_hash[:data] = data
          serializable_hash[:included] = included if @includes.present?
          serializable_hash[:meta] = @meta if @meta.present?
          serializable_hash[:links] = @links if @links.present?
          serializable_hash
        end

        def hash_for_one_record
          serializable_hash = { data: nil }
          serializable_hash[:meta] = @meta if @meta.present?
          serializable_hash[:links] = @links if @links.present?

          return serializable_hash unless @resource

          serializer = serializer_for(@resource)
          serializer_includes = @includes & Array(serializer.relationships_to_serialize&.keys)

          serializable_hash[:data] = serializer.record_hash(@resource, @fieldsets[self.class.record_type.to_sym], serializer_includes, @params)
          serializable_hash[:included] = serializer.get_included_records(@resource, @includes, @known_included_objects, @fieldsets, @params) if serializer_includes.present?
          serializable_hash
        end

        def process_options(options)
          @fieldsets = deep_symbolize(options[:fields].presence || {})
          @params = {}

          return if options.blank?

          @known_included_objects = Set.new
          @meta = options[:meta]
          @links = options[:links]
          @is_collection = options[:is_collection]
          @params = options[:params] || {}
          raise ArgumentError, '`params` option passed to serializer must be a hash' unless @params.is_a?(Hash)

          if options[:include].present?
            @includes = options[:include].reject(&:blank?).map(&:to_sym)
            validate_includes!
          end
        end

        def validate_includes!
          return if @includes.blank?

          parsed_includes = self.class.parse_includes_list(@includes)
          records = self.class.is_collection?(@resource, @is_collection) ? @resource : [@resource]

          serializers = records.map { |record| serializer_for(record) }.uniq
          serializers.each do |serializer|
            next unless serializer.relationships_to_serialize

            parsed_includes.each_key do |include_item|
              relationship_to_include = serializer.relationships_to_serialize[include_item]
              relationship_to_include.static_serializer if relationship_to_include # called for a side-effect to check for a known serializer class.
            end
          end
        end

        def serializer_for(record)
          raise NotImplementedError
        end
      end
    end
  end
end
