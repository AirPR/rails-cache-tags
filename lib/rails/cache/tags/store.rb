# coding: utf-8

module Rails
  module Cache
    module Tags
      module Store
        # patched +new+ method
        def new(*args, &block) #:nodoc:
          unless acts_like?(:cached_tags)
            extend ClassMethods
            include InstanceMethods

            alias_method_chain :read_entry, :tags
            alias_method_chain :write_entry, :tags
          end

          super
        end

        module ClassMethods #:nodoc:all:
          def acts_like_cached_tags?
          end
        end

        module InstanceMethods
          # Increment the version of tags, so all entries referring to the tags become invalid
          def delete_tag *names
            tags = Rails::Cache::Tag.build_tags(names)

            tags.each { |tag| tag.increment(self) } unless tags.empty?
          end
          alias delete_by_tag  delete_tag
          alias delete_by_tags delete_tag
          alias expire_tag     delete_tag

          protected
          def read_entry_with_tags(key, options) #:nodoc
            entry = read_entry_without_tags(key, options)

            if entry && entry.tags.present?
              current_versions = fetch_tags(entry.tags.keys)
              saved_versions   = entry.tags.values

              if current_versions != saved_versions
                delete_entry(key, options)

                return nil
              end
            end

            entry
          end # def read_entry_with_tags

          def write_entry_with_tags(key, entry, options) #:nodoc:
            tags = Rails::Cache::Tag.build_tags Array.wrap(options[:tags]).flatten.compact

            if entry && tags.present?
              current_versions = fetch_tags(tags) # => [1, 2, 3]
              entry.tags = Hash[tags.zip(current_versions).map { |tag, v| [tag.name, v || tag.increment(self)] }]
            end

            write_entry_without_tags(key, entry, options)
          end # def write_entry_without_tags

          private
          # fetch tags versions from store
          # fetch ['user:1', 'post:2', 'country:2'] => [3, 4, nil]
          def fetch_tags(names) #:nodoc:
            tags = Rails::Cache::Tag.build_tags names
            keys = tags.map(&:to_key)
            stored = read_multi(*keys)

            # we should save order
            keys.collect { |k| stored[k] }
          end
        end
      end # module Store
    end # module Tags
  end # module Cache
end # module Rails