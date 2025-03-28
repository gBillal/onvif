defmodule Onvif.Devices.Schemas.NetworkProtocol do
  @moduledoc """
  A module describing a network protocol.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import SweetXml

  @required [:name, :enabled, :port]

  @type t :: %__MODULE__{}

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field(:name, Ecto.Enum, values: [http: "HTTP", https: "HTTPS", rtsp: "RTSP"])
    field(:enabled, :boolean)
    field(:port, :integer)
  end

  def to_json(%__MODULE__{} = schema) do
    Jason.encode(schema)
  end

  def to_struct(parsed) do
    %__MODULE__{}
    |> changeset(parsed)
    |> validate_required(@required)
    |> apply_action(:validate)
  end

  def changeset(module, attrs) do
    module
    |> cast(attrs, @required)
    |> validate_required(@required)
  end

  def parse(doc) do
    # Some Axis cameras return something like
    # ...
    # <tds:NetworkProtocols>
    #     <tt:Name>HTTP</tt:Name>
    #     <tt:Enabled>true</tt:Enabled>
    #     <tt:Port>80</tt:Port>
    #     <tt:Port>0</tt:Port>
    # </tds:NetworkProtocols>
    # ...
    # If parsed with: ~x"./tt:Port/text()"s this will return 800
    xmap(doc,
      name: ~x"./tt:Name/text()"s,
      enabled: ~x"./tt:Enabled/text()"s,
      port: ~x"./tt:Port/text()" |> transform_by(&List.to_string/1)
    )
  end
end
