# frozen_string_literal: true

require File.join(File.dirname(__FILE__), 'claims/audience')
require File.join(File.dirname(__FILE__), 'claims/crit')
require File.join(File.dirname(__FILE__), 'claims/decode_verifier')
require File.join(File.dirname(__FILE__), 'claims/expiration')
require File.join(File.dirname(__FILE__), 'claims/issued_at')
require File.join(File.dirname(__FILE__), 'claims/issuer')
require File.join(File.dirname(__FILE__), 'claims/jwt_id')
require File.join(File.dirname(__FILE__), 'claims/not_before')
require File.join(File.dirname(__FILE__), 'claims/numeric')
require File.join(File.dirname(__FILE__), 'claims/required')
require File.join(File.dirname(__FILE__), 'claims/subject')
require File.join(File.dirname(__FILE__), 'claims/verifier')

module JWT
  # JWT Claim verifications
  # https://datatracker.ietf.org/doc/html/rfc7519#section-4
  #
  # Verification is supported for the following claims:
  # exp
  # nbf
  # iss
  # iat
  # jti
  # aud
  # sub
  # required
  # numeric
  module Claims
    # Represents a claim verification error
    Error = Struct.new(:message, keyword_init: true)

    class << self
      # Checks if the claims in the JWT payload are valid.
      # @example
      #
      #   ::JWT::Claims.verify_payload!({"exp" => Time.now.to_i + 10}, :exp)
      #   ::JWT::Claims.verify_payload!({"exp" => Time.now.to_i - 10}, exp: { leeway: 11})
      #
      # @param payload [Hash] the JWT payload.
      # @param options [Array] the options for verifying the claims.
      # @return [void]
      # @raise [JWT::DecodeError] if any claim is invalid.
      def verify_payload!(payload, *options)
        Verifier.verify!(VerificationContext.new(payload: payload), *options)
      end

      # Checks if the claims in the JWT payload are valid.
      #
      # @param payload [Hash] the JWT payload.
      # @param options [Array] the options for verifying the claims.
      # @return [Boolean] true if the claims are valid, false otherwise
      def valid_payload?(payload, *options)
        payload_errors(payload, *options).empty?
      end

      # Returns the errors in the claims of the JWT token.
      #
      # @param options [Array] the options for verifying the claims.
      # @return [Array<JWT::Claims::Error>] the errors in the claims of the JWT
      def payload_errors(payload, *options)
        Verifier.errors(VerificationContext.new(payload: payload), *options)
      end
    end
  end
end
