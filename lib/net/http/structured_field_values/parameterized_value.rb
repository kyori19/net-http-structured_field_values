# frozen_string_literal: true

require 'net/http'

module Net
  class HTTP
    module StructuredFieldValues
      # ParameterizedValue represents a value with parameters.
      class ParameterizedValue
        attr_reader :value, :parameters

        def initialize(value, parameters)
          @value = value
          @parameters = parameters
        end

        def ==(other)
          value == other.value && parameters == other.parameters
        end
      end
    end
  end
end
