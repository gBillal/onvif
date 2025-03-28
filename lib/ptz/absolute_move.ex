defmodule Onvif.PTZ.AbsoluteMove do
  @moduledoc """
  Operation to move pan,tilt or zoom to a absolute destination.

  The speed argument is optional. If an x/y speed value is given it is up to the device to either use the x value as absolute resoluting speed vector
  or to map x and y to the component speed. If the speed argument is omitted, the default speed set by the PTZConfiguration will be used.
  """

  import XmlBuilder

  require Logger

  alias Onvif.PTZ.Schemas.AbsoluteMove

  def soap_action(), do: "http://www.onvif.org/ver20/ptz/wsdl/AbsoluteMove"

  @spec request(Device.t(), AbsoluteMove.t()) :: :ok | {:error, map()}
  def request(device, args), do: Onvif.PTZ.request(device, args, __MODULE__)

  def request_body(%AbsoluteMove{} = continuous_move),
    do: element(:"s:Body", [AbsoluteMove.to_xml(continuous_move)])

  def response(_xml_response_body), do: :ok
end
