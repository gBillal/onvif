defmodule ExOnvif.RecordingTest do
  use ExUnit.Case, async: true

  @moduletag capture_log: true

  alias ExOnvif.Recording.{
    JobConfiguration,
    RecordingConfiguration,
    RecordingJob,
    ServiceCapabilities
  }

  test "create recording" do
    xml_response = File.read!("test/fixtures/create_recording.xml")

    device = ExOnvif.Factory.device()

    Mimic.expect(Tesla, :request, fn _client, _opts ->
      {:ok, %{status: 200, body: xml_response}}
    end)

    {:ok, response_uri} =
      ExOnvif.Recording.create_recording(device, %RecordingConfiguration{
        content: "test",
        maximum_retention_time: "PT1H",
        source: %RecordingConfiguration.Source{
          name: "test"
        }
      })

    assert response_uri == "SD_DISK_20200422_123501_A2388AB3"
  end

  test "create recording job" do
    xml_response = File.read!("test/fixtures/create_recording_job.xml")

    device = ExOnvif.Factory.device()

    Mimic.expect(Tesla, :request, fn _client, _opts ->
      {:ok, %{status: 200, body: xml_response}}
    end)

    assert {:ok, response} =
             ExOnvif.Recording.create_recording_job(device, %JobConfiguration{
               recording_token: "SD_DISK_20241120_211729_9C896594",
               priority: 9,
               mode: :active
             })

    assert %RecordingJob{
             job_token: "SD_DISK_20241120_211729_9C896594",
             job_configuration: %JobConfiguration{
               recording_token: "SD_DISK_20241120_211729_9C896594",
               priority: 9,
               mode: :active
             }
           } = response
  end

  test "get recordings" do
    xml_response = File.read!("test/fixtures/get_recordings.xml")

    device = ExOnvif.Factory.device()

    Mimic.expect(Tesla, :request, fn _client, _opts ->
      {:ok, %{status: 200, body: xml_response}}
    end)

    {:ok, response} = ExOnvif.Recording.get_recordings(device)

    assert Enum.map(response, & &1.recording_token) == [
             "SD_DISK_20200422_123501_A2388AB3",
             "SD_DISK_20200422_132613_45A883F5",
             "SD_DISK_20200422_132655_67086B52"
           ]
  end

  test "get recording jobs" do
    xml_response = File.read!("test/fixtures/get_recording_jobs.xml")

    device = ExOnvif.Factory.device()

    Mimic.expect(Tesla, :request, fn _client, _opts ->
      {:ok, %{status: 200, body: xml_response}}
    end)

    {:ok, response} = ExOnvif.Recording.get_recording_jobs(device)

    assert hd(response).job_token == "SD_DISK_20241120_211729_9C896594"
  end

  test "get service capabilities" do
    xml_response = File.read!("test/fixtures/get_recording_service_capabilities.xml")

    device = ExOnvif.Factory.device()

    Mimic.expect(Tesla, :request, fn _client, _opts ->
      {:ok, %{status: 200, body: xml_response}}
    end)

    {:ok, response} = ExOnvif.Recording.get_service_capabilities(device)

    assert response == %ServiceCapabilities{
             dynamic_tracks: false,
             dynamic_recordings: false,
             encoding: ["G711", "G726", "AAC", "H264", "JPEG", "H265"],
             max_rate: 16384.0,
             max_total_rate: 16384.0,
             max_recordings: 1.0,
             max_recording_jobs: 1.0,
             options: true,
             metadata_recording: false,
             supported_export_file_formats: [],
             event_recording: false,
             before_event_limit: nil,
             after_event_limit: nil,
             supported_target_formats: [],
             encryption_entry_limit: nil,
             supported_encryption_modes: []
           }
  end
end
