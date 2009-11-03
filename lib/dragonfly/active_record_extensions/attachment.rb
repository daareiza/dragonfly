module Dragonfly
  module ActiveRecordExtensions
    
    class PendingUID; def to_s; 'PENDING'; end; end
    
    class Attachment
      
      def initialize(app, parent_model, attribute_name)
        @app, @parent_model, @attribute_name = app, parent_model, attribute_name
      end
      
      def assign(value)
        if value.nil?
          self.uid = nil
          reset_magic_attributes
        else
          self.temp_object = app.create_object(value)
          self.uid = PendingUID.new
          set_magic_attributes
        end
        value
      end

      def destroy!
        app.datastore.destroy(previous_uid) if previous_uid
      rescue DataStorage::DataNotFound => e
        app.log.warn("*** WARNING ***: tried to destroy data with uid #{previous_uid}, but got error: #{e}")
      end
      
      def fetch
        temp_object
      end
      
      def save!
        if changed?
          destroy!
          self.uid = app.datastore.store(temp_object)
        end
      end
      
      def size
        temp_object.size
      end
      
      def to_value
        self if been_assigned?
      end
      
      def url(*args)
        unless uid.nil? || uid.is_a?(PendingUID)
          app.url_for(uid, *args)
        end
      end
      
      private
      
      def been_assigned?
        uid
      end
      
      def been_persisted?
        uid && !uid.is_a?(PendingUID)
      end
      
      def changed?
        parent_model.send("#{attribute_name}_uid_changed?")
      end
      
      def uid=(uid)
        parent_model.send("#{attribute_name}_uid=", uid)
      end
      
      def uid
        parent_model.send("#{attribute_name}_uid")
      end
      
      def previous_uid
        parent_model.send("#{attribute_name}_uid_was")
      end
      
      attr_reader :app, :parent_model, :attribute_name
      
      attr_writer :temp_object
      
      def analyser
        app.analyser
      end
      
      def temp_object
        if @temp_object
          @temp_object
        elsif been_persisted?
          @temp_object = app.datastore.retrieve(uid)
        end
      end
      
      def magic_attributes
        parent_model.class.column_names.select { |name|
          name =~ /^#{attribute_name}_(.+)$/ &&
            analyser.respond_to?($1)
        }
      end
      
      def set_magic_attributes
        magic_attributes.each do |attribute|
          analyser_method = attribute.sub("#{attribute_name}_", '')
          parent_model.send("#{attribute}=", analyser.send(analyser_method, temp_object))
        end
      end
      
      def reset_magic_attributes
        magic_attributes.each{|attribute| parent_model.send("#{attribute}=", nil) }
      end
      
    end
  end
end