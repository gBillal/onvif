defmodule ExOnvif.Media.Profile.MetadataConfiguration do
  @moduledoc """
  Optional configuration of the metadata stream.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import SweetXml

  alias ExOnvif.Media.Profile.AnalyticsEngineConfiguration
  alias ExOnvif.Media.Profile.MulticastConfiguration

  @type t :: %__MODULE__{}

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field(:reference_token, :string)
    field(:name, :string)
    field(:use_count, :integer)
    field(:compression_type, :string)
    field(:geo_location, :boolean)
    field(:shape_polygon, :boolean)
    field(:analytics, :boolean)
    field(:session_timeout, :string)

    embeds_one :ptz_status, PtzStatus, primary_key: false, on_replace: :update do
      @derive Jason.Encoder
      field(:status, :boolean)
      field(:position, :boolean)
    end

    embeds_one(:multicast, MulticastConfiguration)
    embeds_one(:analytics_engine_configuration, AnalyticsEngineConfiguration)
  end

  def parse(nil), do: nil
  def parse([]), do: nil

  def parse(doc) do
    xmap(
      doc,
      reference_token: ~x"./@token"s,
      name: ~x"./tt:Name/text()"s,
      use_count: ~x"./tt:UseCount/text()"s,
      compression_type: ~x"./tt:CompressionType/text()"s,
      geo_location: ~x"./@GeoLocation"s,
      shape_polygon: ~x"./tt:ShapePolygon/text()"s,
      analytics: ~x"./tt:Analytics/text()"s,
      session_timeout: ~x"./tt:SessionTimeout/text()"s,
      ptz_status: ~x"./tt:PTZStatus"e |> transform_by(&parse_ptz_status/1),
      multicast: ~x"./tt:Multicast"e |> transform_by(&MulticastConfiguration.parse/1),
      analytics_engine_configuration:
        ~x"./tt:AnalyticsEngineConfiguration"e
        |> transform_by(&AnalyticsEngineConfiguration.parse/1)
    )
  end

  defp parse_ptz_status(nil), do: nil
  defp parse_ptz_status([]), do: nil

  defp parse_ptz_status(doc) do
    xmap(
      doc,
      status: ~x"./tt:Status/text()"s,
      position: ~x"./tt:Position/text()"s
    )
  end

  def to_struct(parsed) do
    %__MODULE__{}
    |> changeset(parsed)
    |> apply_action(:validate)
  end

  def changeset(module, attrs) do
    module
    |> cast(attrs, [
      :reference_token,
      :name,
      :use_count,
      :compression_type,
      :geo_location,
      :shape_polygon,
      :analytics,
      :session_timeout
    ])
    |> cast_embed(:ptz_status, with: &ptz_status_changeset/2)
    |> cast_embed(:multicast)
    |> cast_embed(:analytics_engine_configuration)
  end

  defp ptz_status_changeset(module, attrs) do
    cast(module, attrs, [:status, :position])
  end
end
