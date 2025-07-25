defmodule ExOnvif.Recording do
  @moduledoc """
  Interface for making requests to the Onvif recording service

  http://www.onvif.org/onvif/ver10/recording.wsdl
  """

  import ExOnvif.Utils.ApiClient, only: [recording_request: 4]
  import ExOnvif.Utils.Parser
  import SweetXml
  import XmlBuilder

  alias ExOnvif.Recording.{
    JobConfiguration,
    Recording,
    RecordingConfiguration,
    RecordingJob,
    ServiceCapabilities
  }

  @doc """
  CreateRecording shall create a new recording.

  The new recording shall be created with a track for each supported
  TrackType see Recording Control Spec.

  This method is optional. It shall be available if the Recording/DynamicRecordings capability is TRUE.

  When successfully completed, CreateRecording shall have created three tracks with the following configurations:
    * TrackToken TrackType
    * VIDEO001 Video
    * AUDIO001 Audio
    * META001 Metadata

  All TrackConfigurations shall have the MaximumRetentionTime set to 0 (unlimited), and the Description set to the empty string.
  """
  @spec create_recording(ExOnvif.Device.t(), RecordingConfiguration.t()) ::
          {:ok, String.t()} | {:error, any()}
  def create_recording(device, recording_configuration) do
    body =
      element(:"trc:CreateRecording", [RecordingConfiguration.encode(recording_configuration)])

    recording_request(device, "CreateRecording", body, &parse_create_recording_response/1)
  end

  @doc """
  CreateRecordingJob shall create a new recording job.

  The JobConfiguration returned from CreateRecordingJob shall be identical to the JobConfiguration passed into CreateRecordingJob,
  except for the ReceiverToken and the AutoCreateReceiver. In the returned structure, the ReceiverToken shall be present and valid
  and the AutoCreateReceiver field shall be omitted.
  """
  @spec create_recording_job(ExOnvif.Device.t(), JobConfiguration.t()) ::
          {:ok, RecordingJob.t()} | {:error, any()}
  def create_recording_job(device, job_configuration) do
    body = element(:"trc:CreateRecordingJob", [JobConfiguration.encode(job_configuration)])
    recording_request(device, "CreateRecordingJob", body, &parse_create_recording_job_response/1)
  end

  @doc """
  GetRecordings shall return a description of all the recordings in the device.

  This description shall include a list of all the tracks for each recording.
  """
  @spec get_recordings(ExOnvif.Device.t()) :: {:ok, [Recording.t()]} | {:error, any()}
  def get_recordings(device) do
    body = element(:"trc:GetRecordings")
    recording_request(device, "GetRecordings", body, &parse_recordings_response/1)
  end

  @doc """
  GetRecordingJobs shall return a list of all the recording jobs in the device.
  """
  @spec get_recording_jobs(ExOnvif.Device.t()) :: {:ok, [RecordingJob.t()]} | {:error, any()}
  def get_recording_jobs(device) do
    body = element(:"trc:GetRecordingJobs")
    recording_request(device, "GetRecordingJobs", body, &parse_recording_jobs_response/1)
  end

  @doc """
  Returns the capabilities of the recording service.
  """
  @spec get_service_capabilities(ExOnvif.Device.t()) ::
          {:ok, ServiceCapabilities.t()} | {:error, any()}
  def get_service_capabilities(device) do
    recording_request(
      device,
      "GetServiceCapabilities",
      :"trc:GetServiceCapabilities",
      &parse_service_capabilities_response/1
    )
  end

  defp parse_recordings_response(xml_response_body) do
    xml_response_body
    |> parse(namespace_conformant: true, quiet: true)
    |> xpath(
      ~x"//s:Envelope/s:Body/trc:GetRecordingsResponse/trc:RecordingItem"el
      |> add_namespace("s", "http://www.w3.org/2003/05/soap-envelope")
      |> add_namespace("trc", "http://www.onvif.org/ver10/recording/wsdl")
      |> add_namespace("tt", "http://www.onvif.org/ver10/schema")
    )
    |> parse_map_reduce(Recording)
  end

  defp parse_recording_jobs_response(xml_response_body) do
    xml_response_body
    |> parse(namespace_conformant: true, quiet: true)
    |> xpath(
      ~x"//s:Envelope/s:Body/trc:GetRecordingJobsResponse/trc:JobItem"el
      |> add_namespace("s", "http://www.w3.org/2003/05/soap-envelope")
      |> add_namespace("trc", "http://www.onvif.org/ver10/recording/wsdl")
      |> add_namespace("tt", "http://www.onvif.org/ver10/schema")
    )
    |> parse_map_reduce(RecordingJob)
  end

  defp parse_create_recording_response(xml_response_body) do
    recording_token =
      xml_response_body
      |> parse(namespace_conformant: true, quiet: true)
      |> xpath(
        ~x"//s:Envelope/s:Body/trc:CreateRecordingResponse/trc:RecordingToken/text()"s
        |> add_namespace("s", "http://www.w3.org/2003/05/soap-envelope")
        |> add_namespace("trc", "http://www.onvif.org/ver10/recording/wsdl")
      )

    {:ok, recording_token}
  end

  defp parse_create_recording_job_response(xml_response_body) do
    xml_response_body
    |> parse(namespace_conformant: true, quiet: true)
    |> xpath(
      ~x"//s:Envelope/s:Body/trc:CreateRecordingJobResponse"e
      |> add_namespace("s", "http://www.w3.org/2003/05/soap-envelope")
      |> add_namespace("trc", "http://www.onvif.org/ver10/recording/wsdl")
    )
    |> RecordingJob.parse()
    |> RecordingJob.to_struct()
  end

  defp parse_service_capabilities_response(xml_response_body) do
    xml_response_body
    |> parse(namespace_conformant: true, quiet: true)
    |> xpath(
      ~x"//s:Envelope/s:Body/trc:GetServiceCapabilitiesResponse/trc:Capabilities"e
      |> add_namespace("s", "http://www.w3.org/2003/05/soap-envelope")
      |> add_namespace("trc", "http://www.onvif.org/ver10/recording/wsdl")
    )
    |> ServiceCapabilities.parse()
    |> ServiceCapabilities.to_struct()
  end
end
