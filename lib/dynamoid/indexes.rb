# encoding: utf-8
module Dynamoid #:nodoc:

  # Builds all indexes present on the model.
  module Indexes
    extend ActiveSupport::Concern

    included do
      class_attribute :indexes
      
      self.indexes = []
    end
    
    module ClassMethods
      def index(name, options = {})
        name = Array(name).collect(&:to_s).sort.collect(&:to_sym)
        raise Dynamoid::Errors::InvalidField, 'A key specified for an index is not a field' unless name.all?{|n| self.attributes.include?(n)}
        self.indexes << name
        create_indexes
      end
      
      def create_indexes
        self.indexes.each do |index|
          self.create_table(index_table_name(index), index_key_name(index)) unless self.table_exists?(index_table_name(index))
        end
      end
      
      def index_table_name(index)
        "#{Dynamoid::Config.namespace}_index_#{index_key_name(index)}"
      end
      
      def index_key_name(index)
        "#{self.to_s.downcase}_#{index.collect(&:to_s).collect(&:pluralize).join('_and_')}"
      end
      
      def key_for_index(index, values = [])
        values = values.collect(&:to_s).sort.join('.')
      end
    end
    
    def key_for_index(index)
      self.class.key_for_index(index, index.collect{|i| self.send(i)})
    end
    
    def save_indexes
      self.class.indexes.each do |index|
        existing = Dynamoid::Adapter.get_item(self.class.index_table_name(index), self.key_for_index(index))
        ids = existing ? existing[:ids] : Set.new
        Dynamoid::Adapter.put_item(self.class.index_table_name(index), {self.class.index_key_name(index).to_sym => self.key_for_index(index), :ids => ids.merge([self.id])})
      end
    end
    
    def delete_indexes
      self.class.indexes.each do |index|
        existing = Dynamoid::Adapter.get_item(self.class.index_table_name(index), self.key_for_index(index))
        next unless existing && existing[:ids]
        Dynamoid::Adapter.put_item(self.class.index_table_name(index), {self.class.index_key_name(index).to_sym => self.key_for_index(index), :ids => existing[:ids] - [self.id]})
      end
    end
  end
  
end