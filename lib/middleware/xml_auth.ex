defmodule ExOnvif.Middleware.XmlAuth do
  @moduledoc false

  @behaviour Tesla.Middleware

  import XmlBuilder

  alias ExOnvif.Request

  @nonce_bytesize 16

  @security_header_namespaces [
    "xmlns:wsse":
      "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd",
    "xmlns:wsu":
      "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
  ]

  @standard_namespaces [
    "xmlns:s": "http://www.w3.org/2003/05/soap-envelope"
  ]

  @impl Tesla.Middleware
  def call(env, next, opts) do
    body = inject_xml_auth_header(env, opts)
    env |> Tesla.put_body(body) |> Tesla.run(next)
  end

  defp inject_xml_auth_header(env, opts) do
    request =
      case generate_xml_auth_header(opts) do
        nil ->
          Request.add_namespaces(env.body, @standard_namespaces)

        auth_header ->
          env.body
          |> Request.add_namespaces(@standard_namespaces)
          |> Request.add_namespaces(@security_header_namespaces)
          |> Request.put_header(:auth, auth_header)
      end

    Request.encode(request)
  end

  defp generate_xml_auth_header(device: device) do
    created_at =
      DateTime.utc_now()
      |> DateTime.add(device.time_diff_from_system_secs)
      |> DateTime.to_iso8601()

    nonce_bytes = :rand.bytes(@nonce_bytesize)
    nonce = Base.encode64(nonce_bytes)
    digest = :sha |> :crypto.hash(nonce_bytes <> created_at <> device.password) |> Base.encode64()

    element(
      :"wsse:Security",
      %{"s:mustUnderstand" => "1"},
      [
        element(
          :"wsse:UsernameToken",
          [
            element(:"wsse:Username", device.username),
            element(
              :"wsse:Password",
              %{
                "Type" =>
                  "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest"
              },
              digest
            ),
            element(
              :"wsse:Nonce",
              %{
                "EncodingType" =>
                  "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary"
              },
              nonce
            ),
            element(:"wsu:Created", created_at)
          ]
        )
      ]
    )
  end

  defp generate_xml_auth_header(_uri), do: nil
end
