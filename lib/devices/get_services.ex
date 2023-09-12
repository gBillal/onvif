defmodule Onvif.Devices.GetServices do
  # import SweetXml
  import XmlBuilder

  alias Onvif.Device

  def soap_action, do: "http://www.onvif.org/ver10/device/wsdl/GetServices"

  @spec request(Device.t()) :: {:ok, any} | {:error, map()}
  def request(device), do: Onvif.Devices.request(device, __MODULE__)

  def request_body do
    element(:"s:Body", [element(:"tds:GetServices", [element(:"tds:IncludeCapability", "true")])])
  end

  def response(xml_response_body) do
    xml_response_body
  end
end
