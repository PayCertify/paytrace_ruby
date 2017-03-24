module PayTrace
  module API
    # An object representing an API request to be sent using a PayTrace::API::Gateway object
    class Request
      # :nodoc:
      attr_reader :params, :field_delim, :value_delim, :discretionary_data
      # :doc:

      # Initializes a new Request object
      def initialize(configuration=nil)
        @field_delim = "|"
        @multi_field_delim = "+"
        @value_delim = "~"
        @multi_value_delim = "="
        configuration ||= PayTrace.configuration
        @params= {
          user_name: [configuration.user_name],
          password: [configuration.password],
          terms: ["Y"]
        }

        @discretionary_data = {}
      end

      # Returns the formatted URL that this request will send
      def to_parms_string()
        raw_request = @params.map do |k,items|
          items.map do |item|
            "#{PayTrace::API.fields[k]}#{@value_delim}#{item}"
          end
        end.join(@field_delim) << @field_delim

        if @discretionary_data.any?
          raw_request << @discretionary_data.map do |k,v|
            "#{k}#{@value_delim}#{v}"
          end.join(@field_delim) << @field_delim
        end

        raw_request
      end

      # Sets discretionary data keys and values
      # * *:key* -- the name of the setting
      # * *:value* -- the value of the setting
      #
      # _Note:_ you can bulk-set discretionary data by simply passing in a hash as the "key"
      def set_discretionary(key, value = nil)
        if key.is_a?(Hash)
          ddata_hash = key
          ddata_hash.keys.each do |inner_key|
            inner_value = ddata_hash[inner_key]
            @discretionary_data[inner_key] = inner_value unless inner_value.nil?
          end
        elsif key.is_a?(Symbol)
          @discretionary_data[key] = value unless value.nil?
        end
      end

      # :nodoc:
      def valid_param?(key, value)
        if key == :discretionary_data
          value.is_a?(Hash) || value.nil? # any discretionary data that's a hash or nil should be passed
        else
          PayTrace::API.fields.has_key?(key) || value.nil? || value.respond_to?(:set_request)
        end
      end

      def validate_param!(k, v)
        raise PayTrace::Exceptions::ValidationError.new("Unknown field '#{k}' (value: #{v})") unless valid_param?(k,v)
      end
      # :doc:

      # Sets multiple parameters with the same name using the custom delimiter
      # * *param_name* -- the name of the "top level" setting
      # * *items* -- a hash of "second level" settings
      def set_multivalue(param_name, items = {})
        result = (items.map do |k,v|
          validate_param!(k, v)
          "#{PayTrace::API.fields[k]}#{@multi_value_delim}#{v}"
        end.join(@multi_field_delim))

        set_param(param_name, result)

        result
      end

      # Sets a single request parameters
      # * *key* -- the name of the setting
      # * *value* -- the value of the setting
      #
      # _Note:_ you can pass in an object that responds to *set_request* as the *value*, and this will invoke *set_request* on it, with this request object as the parameter. Also, any value named *:discretionary_data* that is set will be set in the discretionary hash, not the regular params hash.
      def set_param(key, value = nil)
        validate_param!(key, value)

        if value.respond_to?(:set_request)
          value.set_request(self)
        elsif key == :discretionary_data
          set_discretionary(value)
        elsif value != nil
          @params[key] ||= []

          @params[key] << value
        end
      end

      # Sets multiple parameters at once
      # * *:params* -- the hash or object to fetch the parameters from
      # * *:required* -- an array of required key names to extract from the params object
      #
      # _Note:_ the values in *:keys* can also include arrays of two values (techincally, a tuple). The sub-array contains the name of the field that will be used in the request, and the name of the field in the params. This allows more succinct parameter names; e.g. *:address* instead of *:billing_address*. Example:
      #
      #   #
      #   # note the nested array; this will send the field :billing_address,
      #   # but uses the argument :address as the argument name
      #   #
      #   set_params([
      #       :foo,
      #       [:billing_address, :address]
      #     ], params)
      def set_params(params, required = [], optional = [])
        required_remaining, params_remaining = Request.process_param_list(required, params) do |request_variable, arg_name, value|
          set_param(request_variable, value)
        end

        # if we're missing *required* parameters, fail...
        raise PayTrace::Exceptions::ValidationError.new("Missing the following required parameters: #{required_remaining.to_s}") if required_remaining.any?

        optional_remaining, params_remaining = Request.process_param_list(optional, params_remaining) do |request_variable, arg_name, value|
          set_param(request_variable, value)
        end

        # if we have any EXTRA parameters, fail...
        raise PayTrace::Exceptions::ValidationError.new("The following parameters are unknown: #{params_remaining.to_s}") if params_remaining && params_remaining.any?
      end

      # takes a list of permitted keys and a params hash, and returns any missing or extra params, optionally
      # calling a supplied block once per key
      def self.process_param_list(key_list, params, &block)
        if params.is_a?(Hash)
          accessor = :[]
          track_params = true
        else
          accessor = :send
          track_params = false
        end
        params_remaining = params.dup if track_params

        remaining = key_list.dup
        key_list.each do |key|
          request_variable, arg_name = key # de-alias the name, if it's aliased
          arg_name ||= request_variable # just use the same name for both, if not

          value = params.send(accessor, arg_name) # this allows us to treat hashes and objects the same
          yield request_variable, arg_name, value if block_given?
          remaining.delete(key) if value
          params_remaining.delete(arg_name) if track_params
        end

        return (remaining.map {|req,arg| arg || req}), (track_params ? params_remaining : nil)
      end
    end
  end
end
