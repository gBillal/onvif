defmodule Onvif.PTZ.Schemas.AbsoluteMove do
  @moduledoc """
  Module describing absolute move schema
  """

  use Ecto.Schema

  import Ecto.Changeset
  import XmlBuilder

  alias Onvif.PTZ.Schemas.PTZSpeed

  @type t :: %__MODULE__{}

  @primary_key false
  embedded_schema do
    field(:profile_token, :string)
    embeds_one(:position, PTZSpeed)
    embeds_one(:velocity, PTZSpeed)
  end

  def to_struct(parsed) do
    %__MODULE__{}
    |> changeset(parsed)
    |> apply_action(:validate)
  end

  def changeset(absolute_move, attrs) do
    absolute_move
    |> cast(attrs, [:profile_token])
    |> validate_required([:profile_token])
    |> cast_embed(:position, with: &PTZSpeed.changeset/2, required: true)
    |> cast_embed(:velocity, with: &PTZSpeed.changeset/2)
  end

  def to_xml(struct) do
    element(
      :"tptz:AbsoluteMove",
      [
        element(:"tptz:ProfileToken", struct.profile_token),
        element(:"tptz:Position", PTZSpeed.to_xml(struct.position)),
        element(:"tptz:Velocity", PTZSpeed.to_xml(struct.velocity))
      ]
    )
  end
end
