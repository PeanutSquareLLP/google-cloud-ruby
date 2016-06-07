# Copyright 2014 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require "delegate"

module Gcloud
  module Datastore
    class Dataset
      ##
      # LookupResults is a special case Array with additional values.
      # A LookupResults object is returned from Dataset#find_all and
      # contains the entities as well as the Keys that were deferred from
      # the results and the Entities that were missing in the dataset.
      #
      # Please be cautious when treating the QueryResults as an Array.
      # Many common Array methods will return a new Array instance.
      #
      # @example
      #   tasks = datastore.find_all task_key1, task_key2, task_key3
      #   tasks.size #=> 3
      #   tasks.deferred #=> []
      #   tasks.missing #=> []
      #
      # @example Caution, many Array methods will return a new Array instance:
      #   tasks = datastore.find_all task_key1, task_key2, task_key3
      #   tasks.size #=> 3
      #   tasks.deferred #=> []
      #   tasks.missing #=> []
      #   descriptions = tasks.map { |task| task["description"] }
      #   descriptions.size #=> 3
      #   descriptions.deferred #=> NoMethodError
      #   descriptions.missing #=> NoMethodError
      #
      class LookupResults < DelegateClass(::Array)
        ##
        # Keys that were not looked up due to resource constraints.
        attr_accessor :deferred

        ##
        # Entities not found, with only the key populated.
        attr_accessor :missing

        ##
        # @private Create a new LookupResults with an array of values.
        def initialize arr = []
          super arr
        end

        ##
        # Whether there are more results available.
        def next?
          Array(@deferred).any?
        end

        ##
        # Retrieve the next page of results.
        def next
          return nil unless next?
          ensure_service!
          lookup_res = @service.lookup(*Array(@deferred).flatten.map(&:to_grpc),
                                       consistency: @consistency,
                                       transaction: @transaction)
          self.class.from_grpc lookup_res, @service, @consistency
        rescue GRPC::BadStatus => e
          raise Gcloud::Error.from_error(e)
        end

        ##
        # Retrieves all lookup results by repeatedly loading {#next} until
        # {#next?} returns `false`. Calls the given block once for each result,
        # which is passed as the parameter.
        #
        # An Enumerator is returned if no block is given.
        #
        # This method may make several API calls until all lookup results are
        # retrieved. Be sure to use as narrow a search criteria as possible.
        # Please use with caution.
        #
        # @example Iterating each result by passing a block:
        #   gcloud = Gcloud.new
        #   datastore = gcloud.datastore
        #
        #   task_key1 = datastore.key "Task", "sampleTask1"
        #   task_key2 = datastore.key "Task", "sampleTask2"
        #   tasks = datastore.find_all task_key1, task_key2
        #   tasks.all do |task|
        #     puts "Task #{task.key.id} (#cursor)"
        #   end
        #
        # @example Using the enumerator by not passing a block:
        #   gcloud = Gcloud.new
        #   datastore = gcloud.datastore
        #
        #   task_key1 = datastore.key "Task", "sampleTask1"
        #   task_key2 = datastore.key "Task", "sampleTask2"
        #   tasks = datastore.find_all task_key1, task_key2
        #   all_keys = tasks.all.map(&:key).each do |task|
        #     task.key
        #   end
        #
        # @example Limit the number of API calls made:
        #   gcloud = Gcloud.new
        #   datastore = gcloud.datastore
        #
        #   task_key1 = datastore.key "Task", "sampleTask1"
        #   task_key2 = datastore.key "Task", "sampleTask2"
        #   tasks = datastore.find_all task_key1, task_key2
        #   tasks.all(max_api_calls: 10) do |task|
        #     puts "Task #{task.key.id} (#cursor)"
        #   end
        #
        def all max_api_calls: nil
          max_api_calls = max_api_calls.to_i if max_api_calls
          unless block_given?
            return enum_for(:all, max_api_calls: max_api_calls)
          end
          results = self
          loop do
            results.each { |r| yield r }
            if max_api_calls
              max_api_calls -= 1
              break if max_api_calls < 0
            end
            break unless results.next?
            results = results.next
          end
        end

        ##
        # @private New Dataset::LookupResults from a
        # Google::Dataset::V1beta3::LookupResponse object.
        def self.from_grpc lookup_res, service, consistency = nil, tx = nil
          entities = to_gcloud_entities lookup_res.found
          deferred = to_gcloud_keys lookup_res.deferred
          missing  = to_gcloud_entities lookup_res.missing
          new(entities).tap do |lr|
            lr.instance_variable_set :@service,     service
            lr.instance_variable_set :@consistency, consistency
            lr.instance_variable_set :@transaction, tx
            lr.instance_variable_set :@deferred,    deferred
            lr.instance_variable_set :@missing,     missing
          end
        end

        protected

        ##
        # @private Raise an error unless an active connection to the service is
        # available.
        def ensure_service!
          msg = "Must have active connection to datastore service to get next"
          fail msg if @service.nil?
        end

        ##
        # Convenience method to convert GRPC entities to Gcloud entities.
        def self.to_gcloud_entities grpc_entity_results
          # Entities are nested in an object.
          Array(grpc_entity_results).map do |result|
            # TODO: Make this return an EntityResult with cursor...
            Entity.from_grpc result.entity
          end
        end

        ##
        # Convenience method to convert GRPC keys to Gcloud keys.
        def self.to_gcloud_keys grpc_keys
          # Keys are not nested in an object like entities are.
          Array(grpc_keys).map { |key| Key.from_grpc key }
        end
      end
    end
  end
end
