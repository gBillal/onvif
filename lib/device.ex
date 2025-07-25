defmodule ExOnvif.Device do
  @moduledoc """
  A Device is an abstraction of a physical piece of hardware.

  Setting up a device is done most easily by passing in the results
  of an ExOnvif.Discovery.Probe and credentials that can be used to
  perform ONVIF operations on the physical device.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ExOnvif.Device
  alias ExOnvif.Devices.Service
  alias ExOnvif.Devices.SystemDateAndTime
  alias ExOnvif.Discovery.Probe

  @required [:address]
  @optional [
    :username,
    :password,
    :scopes,
    :manufacturer,
    :model,
    :firmware_version,
    :serial_number,
    :hardware_id,
    :ntp,
    :media_ver10_service_path,
    :media_ver20_service_path,
    :recording_ver10_service_path,
    :replay_ver10_service_path,
    :search_ver10_service_path,
    :ptz_ver20_service_path,
    :analytics_ver20_service_path,
    :event_ver10_service_path,
    :auth_type,
    :time_diff_from_system_secs,
    :port,
    :device_service_path
  ]

  @type t :: %__MODULE__{}

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field :username, :string
    field :password, :string
    field :address, :string
    field :scopes, {:array, :string}, default: []
    field :manufacturer, :string
    field :model, :string
    field :firmware_version, :string
    field :serial_number, :string
    field :hardware_id, :string
    field :ntp, :string
    field :media_ver10_service_path, :string
    field :media_ver20_service_path, :string
    field :recording_ver10_service_path, :string
    field :replay_ver10_service_path, :string
    field :search_ver10_service_path, :string
    field :ptz_ver20_service_path, :string
    field :analytics_ver20_service_path, :string
    field :event_ver10_service_path, :string
    embeds_one :system_date_time, SystemDateAndTime
    embeds_many :services, Service

    field :auth_type, Ecto.Enum,
      default: :xml_auth,
      values: [:xml_auth, :digest_auth, :basic_auth, :no_auth]

    field :time_diff_from_system_secs, :integer, default: 0
    field :port, :integer, default: 80
    field :device_service_path, :string, default: "/onvif/device_service"
  end

  @doc """
  Returns a `{:ok, Device.t()}` if the map can be properly parsed into a struct
  or `{:error, Ecto.Changeset.t()}` if not.
  """
  @spec to_struct(map()) :: {:ok, Device.t()} | {:error, Ecto.Changeset.t()}
  def to_struct(parsed) when is_map(parsed) do
    %__MODULE__{}
    |> changeset(parsed)
    |> apply_action(:validate)
  end

  @doc """
  Utility function to encode a `Device.t()` struct into a json string.

  It returns an `{:error, Ecto.Changeset.t()}` if the struct is not valid.
  """
  @spec to_json(Device.t()) ::
          {:ok, String.t()}
          | {:error, Ecto.Changeset}
          | {:error, Jason.EncodeError.t() | Exception.t()}
  def to_json(%__MODULE__{} = schema) do
    case changeset(schema) do
      %{valid?: true} = device -> Jason.encode(device)
      change -> {:error, change}
    end
  end

  @spec changeset(Device.t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = device, attrs \\ %{}) do
    device
    |> cast(attrs, @required ++ @optional)
    |> cast_embed(:system_date_time, with: &SystemDateAndTime.changeset/2)
    |> cast_embed(:services, with: &Service.changeset/2)
    |> validate_required(@required)
  end

  @doc """
  Returns a `Device.t()` struct populated with the bare requirements for making a request to an Onvif
  enabled device.

    `address` is a http address with the form `http://ip:port`

    `username` is the onvif enabled username

    `password` is the password for the username

  As this is an override for the init() function, your mileage may vary here, and some manual struct
  updates may be required for the onvif requests to succeed. It is recommended to check calls on an
  authentication required endpoint and swap out auth_type for the one that works.
  """
  @spec new(String.t(), String.t(), String.t()) :: {:ok, __MODULE__.t()}
  def new(address, username, password) do
    with device <- %__MODULE__{address: address, username: username, password: password},
         {:ok, device_with_datetime} <- get_date_time(device),
         {:ok, updated_device} <- guess_auth(device_with_datetime),
         {:ok, updated_device} <- get_services(updated_device) do
      {:ok, set_media_service_path(updated_device)}
    end
  end

  @doc """
  Returns a `{:ok, Device.t()}` tuple with device struct prepopulated with data required to make an Onvif API
  request.

    `probe_match` is a valid `Probe.t()` struct for an Onvif compliant device.

    `username` is an Onvif enabled username. Some manufacturers allow the admin credentials
    to serve this purpose, but generally you need to enable Onvif for a user in the
    device's web GUI or create dedicated credentials for ExOnvif.

    `password` is the password for the username above.

    `prefer_https?` will try requests via a probed https address if present. May run into SSL
    errors so http is generally preferred.

    `prefer_ipv6?` will try requests via a probed ipv6 address if present.

  `init` will attempt to make requests for the device's system datetime, an authenticated request
  for device information, and an authenticated request for services to determine what the device's
  system can provide. As this makes several HTTP/HTTPS requests, there are several points of
  failure which will return as `{:error, reason}`.

  If `init` fails a device can be initialized with `new/3`, providing the address (in form `http://ip:port`),
  the username and the password. Then override any other field with a struct update because the
  init helpers haven't filled in any service paths, scopes, or an auth best guess.
  """
  @spec init(ExOnvif.Discovery.Probe.t(), String.t(), String.t(), boolean, boolean) ::
          {:error, any()}
          | {:ok, __MODULE__.t()}
  def init(
        %Probe{} = probe_match,
        username,
        password,
        prefer_https? \\ false,
        prefer_ipv6? \\ false
      ) do
    with {:ok, device} <-
           device_from_probe_match(probe_match, username, password, prefer_https?, prefer_ipv6?),
         {:ok, device_with_datetime} <- get_date_time(device),
         {:ok, updated_device} <- guess_auth(device_with_datetime),
         {:ok, updated_device} <- get_services(updated_device) do
      {:ok, set_media_service_path(updated_device)}
    end
  end

  defp device_from_probe_match(
         %Probe{} = probe_match,
         username,
         password,
         prefer_https?,
         prefer_ipv6?
       ) do
    uri =
      probe_match.address
      |> get_address(prefer_ipv6?, prefer_https?)
      |> URI.parse()
      |> Map.put(:path, "")

    device = %Device{
      username: username,
      password: password,
      address: URI.to_string(uri),
      port: uri.port,
      scopes: probe_match.scopes
    }

    {:ok, device}
  end

  defp get_address(addresses, prefer_ipv6?, prefer_https?) do
    # Preference for the ipv6 and https follow the below order
    # ipv6 and https
    # ipv6 and http
    # ipv4 and https
    # ipv4 and http
    ipv6_addresses =
      Enum.filter(addresses, fn address ->
        result =
          address
          |> URI.parse()
          |> then(& &1.host)
          |> :binary.bin_to_list()
          |> :inet.parse_ipv6strict_address()

        case result do
          {:ok, _} ->
            cond do
              prefer_https? -> String.contains?(address, "https://")
              true -> true
            end

          {:error, _} ->
            false
        end
      end)

    ipv4_addresses =
      Enum.filter(addresses, fn address ->
        result =
          address
          |> URI.parse()
          |> then(& &1.host)
          |> :binary.bin_to_list()
          |> :inet.parse_ipv4strict_address()

        case result do
          {:ok, _} ->
            cond do
              prefer_https? -> String.contains?(address, "https://")
              true -> true
            end

          {:error, _} ->
            false
        end
      end)

    cond do
      prefer_ipv6? and Enum.count(ipv6_addresses) != 0 -> Enum.at(ipv6_addresses, 0)
      Enum.count(ipv4_addresses) != 0 -> Enum.at(ipv4_addresses, 0)
      true -> Enum.at(addresses, 0)
    end
  end

  defp get_date_time(device) do
    with {:ok, res} <- ExOnvif.Devices.get_system_date_and_time(device) do
      updated_device = %{
        device
        | time_diff_from_system_secs: res.current_diff,
          ntp: res.date_time_type,
          system_date_time: res
      }

      {:ok, updated_device}
    end
  end

  defp guess_auth(device, auth_types \\ [:xml_auth, :digest_auth, :basic_auth, :no_auth]) do
    if Enum.count(auth_types) == 0 do
      {:error, "Invalid credentials"}
    else
      [auth_type | rest] = auth_types

      guess_device = %{device | auth_type: auth_type}

      case get_device_information(guess_device) do
        {:ok, %Device{} = updated_device} -> {:ok, %{updated_device | auth_type: auth_type}}
        {:error, _res} -> guess_auth(device, rest)
      end
    end
  end

  defp get_device_information(device) do
    with {:ok, res} <- ExOnvif.Devices.get_device_information(device) do
      {:ok,
       %{
         device
         | manufacturer: res.manufacturer,
           model: res.model,
           serial_number: res.serial_number,
           hardware_id: res.hardware_id,
           firmware_version: res.firmware_version
       }}
    end
  end

  defp get_services(device) do
    with {:ok, services} <- ExOnvif.Devices.get_services(device) do
      {:ok, Map.put(device, :services, services)}
    end
  end

  defp set_media_service_path(device) do
    device
    |> Map.put(:media_ver10_service_path, get_media_ver10_service_path(device.services))
    |> Map.put(:media_ver20_service_path, get_media_ver20_service_path(device.services))
    |> Map.put(:recording_ver10_service_path, get_recoding_ver10_service_path(device.services))
    |> Map.put(:replay_ver10_service_path, get_replay_ver10_service_path(device.services))
    |> Map.put(:search_ver10_service_path, get_search_ver10_service_path(device.services))
    |> Map.put(:ptz_ver20_service_path, get_ptz_ver20_service_path(device.services))
    |> Map.put(:event_ver10_service_path, get_event_ver10_service_path(device.services))
    |> Map.put(:analytics_ver20_service_path, get_analytics_ver20_service_path(device.services))
  end

  defp get_media_ver20_service_path(services) do
    case Enum.find(services, &String.contains?(&1.namespace, "ver20/media")) do
      nil -> nil
      %Service{} = service -> service.xaddr |> URI.parse() |> Map.get(:path)
    end
  end

  defp get_media_ver10_service_path(services) do
    case Enum.find(services, &String.contains?(&1.namespace, "ver10/media")) do
      nil -> nil
      %Service{} = service -> service.xaddr |> URI.parse() |> Map.get(:path)
    end
  end

  defp get_recoding_ver10_service_path(services) do
    case Enum.find(services, &String.contains?(&1.namespace, "/recording")) do
      nil -> nil
      %Service{} = service -> service.xaddr |> URI.parse() |> Map.get(:path)
    end
  end

  defp get_replay_ver10_service_path(services) do
    case Enum.find(services, &String.contains?(&1.namespace, "/replay")) do
      nil -> nil
      %Service{} = service -> service.xaddr |> URI.parse() |> Map.get(:path)
    end
  end

  defp get_search_ver10_service_path(services) do
    case Enum.find(services, &String.contains?(&1.namespace, "/search")) do
      nil -> nil
      %Service{} = service -> service.xaddr |> URI.parse() |> Map.get(:path)
    end
  end

  defp get_ptz_ver20_service_path(services) do
    case Enum.find(services, &String.contains?(&1.namespace, "/ptz")) do
      nil -> nil
      %Service{} = service -> service.xaddr |> URI.parse() |> Map.get(:path)
    end
  end

  defp get_event_ver10_service_path(services) do
    case Enum.find(services, &String.contains?(&1.namespace, "/event")) do
      nil -> nil
      %Service{} = service -> service.xaddr |> URI.parse() |> Map.get(:path)
    end
  end

  defp get_analytics_ver20_service_path(services) do
    case Enum.find(services, &String.contains?(&1.namespace, "ver20/analytics")) do
      nil -> nil
      %Service{} = service -> service.xaddr |> URI.parse() |> Map.get(:path)
    end
  end
end
