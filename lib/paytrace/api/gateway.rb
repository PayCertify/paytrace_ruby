require 'faraday'
require 'paytrace/api/response'
require 'paytrace/exceptions'

module PayTrace
  module API
    # Helper for sending requests
    class Gateway
      # :nodoc:
      attr_accessor :configuration
      @@debug = false
      @@last_request = nil
      @@last_response = nil
      @@last_response_object = nil
      @@next_response = nil
      @@raise_exceptions = true
      # :doc:

      # Creates a new gateway object, optionally using a supplied connection object
      def initialize(configuration = nil)
        @configuration = configuration || PayTrace.configuration
      end

      # Sets or clears a debug flag to enable testing
      def self.debug=(enable)
        @@debug = enable
      end

      # Clears debug data
      def self.reset_trace
        @@last_request = nil
        @@last_response = nil
        @@last_response_object = nil
        @@next_response = nil
      end

      # Returns the last request sent (as raw text)
      def self.last_request
        @@last_request
      end

      # Returns the last response received (as raw text)
      def self.last_response
        @@last_response
      end

      # Returns the last response object received
      def self.last_response_object
        @@last_response_object
      end

      # Use this to set the raw text of the next response; only used when debug is true
      def self.next_response=(next_response)
        @@next_response = next_response
      end

      # Sets or clears a flag to raise exceptions on receiving server errors
      def self.raise_exceptions=(raise_exceptions)
        @@raise_exceptions = raise_exceptions
      end

      # Helper method to abstract away a common use pattern. Creates a request object, sets parameters, creates a gateway object, sends the request, and returns the response.
      #
      # Arguments:
      #
      # * *param_names* -- the array of parameter names to be set from *arguments*
      # * *arguments* -- the arguments to be set in the request
      def self.send_request(method, params, required = [], optional = [], configuration=nil)
        request = Request.new
        request.set_param(:method, method)
        request.set_params(params, required, optional)
        yield request if block_given?

        gateway = Gateway.new(configuration)
        gateway.send_request(request)
      end

      # Sends a request object
      def send_request(request)
        @@last_request = request.to_parms_string if @@debug
        unless (@@debug && @@next_response)
          res = @configuration.connection.post @configuration.url, parmlist: request.to_parms_string
          raw_response = res.body
        else
          raw_response = @@next_response
        end

        @@last_response = raw_response
        response = PayTrace::API::Response.new(raw_response)
        @@last_response_object = response

        @@next_response = nil # just to be sure

        if @@raise_exceptions && response.has_errors?
          raise PayTrace::Exceptions::ErrorResponse.new(response)
        else
          response
        end
      end
    end
  end
end
