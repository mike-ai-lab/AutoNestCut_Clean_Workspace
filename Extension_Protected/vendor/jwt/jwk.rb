# frozen_string_literal: true

require File.join(File.dirname(__FILE__), 'jwk/key_finder')
require File.join(File.dirname(__FILE__), 'jwk/set')

module JWT
  # JSON Web Key (JWK)
  module JWK
    class << self
      def create_from(key, params = nil, options = {})
        if key.is_a?(Hash)
          jwk_kty = key[:kty] || key['kty']
          raise JWT::JWKError, 'Key type (kty) not provided' unless jwk_kty

          return mappings.fetch(jwk_kty.to_s) do |kty|
            raise JWT::JWKError, "Key type #{kty} not supported"
          end.new(key, params, options)
        end

        mappings.fetch(key.class) do |klass|
          raise JWT::JWKError, "Cannot create JWK from a #{klass.name}"
        end.new(key, params, options)
      end

      def classes
        @mappings = nil # reset the cached mappings
        @classes ||= []
      end

      alias new create_from
      alias import create_from

      private

      def mappings
        @mappings ||= generate_mappings
      end

      def generate_mappings
        classes.each_with_object({}) do |klass, hash|
          next unless klass.const_defined?('KTYS')

          Array(klass::KTYS).each do |kty|
            hash[kty] = klass
          end
        end
      end
    end
  end
end

require File.join(File.dirname(__FILE__), 'jwk/key_base')
require File.join(File.dirname(__FILE__), 'jwk/ec')
require File.join(File.dirname(__FILE__), 'jwk/rsa')
require File.join(File.dirname(__FILE__), 'jwk/hmac')
