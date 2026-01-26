# frozen_string_literal: true

require File.join(File.dirname(__FILE__), 'jwt/version')
require File.join(File.dirname(__FILE__), 'jwt/base64')
require File.join(File.dirname(__FILE__), 'jwt/json')
require File.join(File.dirname(__FILE__), 'jwt/decode')
require File.join(File.dirname(__FILE__), 'jwt/configuration')
require File.join(File.dirname(__FILE__), 'jwt/encode')
require File.join(File.dirname(__FILE__), 'jwt/error')
require File.join(File.dirname(__FILE__), 'jwt/jwk')
require File.join(File.dirname(__FILE__), 'jwt/claims')
require File.join(File.dirname(__FILE__), 'jwt/encoded_token')
require File.join(File.dirname(__FILE__), 'jwt/token')

# JSON Web Token implementation
#
# Should be up to date with the latest spec:
# https://tools.ietf.org/html/rfc7519
module JWT
  extend ::JWT::Configuration

  module_function

  # Encodes a payload into a JWT.
  #
  # @param payload [Hash] the payload to encode.
  # @param key [String] the key used to sign the JWT.
  # @param algorithm [String] the algorithm used to sign the JWT.
  # @param header_fields [Hash] additional headers to include in the JWT.
  # @return [String] the encoded JWT.
  def encode(payload, key, algorithm = 'HS256', header_fields = {})
    Encode.new(payload: payload,
               key: key,
               algorithm: algorithm,
               headers: header_fields).segments
  end

  # Decodes a JWT to extract the payload and header
  #
  # @param jwt [String] the JWT to decode.
  # @param key [String] the key used to verify the JWT.
  # @param verify [Boolean] whether to verify the JWT signature.
  # @param options [Hash] additional options for decoding.
  # @return [Array<Hash>] the decoded payload and headers.
  def decode(jwt, key = nil, verify = true, options = {}, &keyfinder) # rubocop:disable Style/OptionalBooleanParameter
    Decode.new(jwt, key, verify, configuration.decode.to_h.merge(options), &keyfinder).decode_segments
  end
end
