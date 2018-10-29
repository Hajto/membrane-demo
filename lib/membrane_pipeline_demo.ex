defmodule MembraneMP3Demo.Pipeline do
  use Membrane.Pipeline

  @moduledoc """
  Sample Membrane pipeline that will play an `.mp3` file.
  """

  @doc """
  In order to play `.mp3` file we need to read it first.

  In membrane every entry point to data flow is called `Source`. Since we want to play a `file`, we will use `File.Source`.

  Next problem that arises is the fact that we are reading MPEG Layer 3 frames not raw audio. To deal with that we need to use `Filter` called decoder. It takes `.mp3` frames and yields RAW audio data.

  There is one tiny problem here though. Decoder returns `%Raw{format: :s24le}` data, but PortAudio (module that actually talks with the audio driver of your computer) wants `%Raw{format: :s16le, sample_rate: 48000, channels: 2}`.

  That's where `SWResample.Converter` comes into play. It will consume data that doesn't suite our needs and will yield data in format we want.
  """
  def handle_init(path_to_mp3) do
    children = [
      # Stream from file
      file_src: %Membrane.Element.File.Source{location: path_to_mp3},
      # Decode frames
      decoder: Membrane.Element.Mad.Decoder,
      # Convert Raw :s24le to Raw :s16le
      converter: %Membrane.Element.FFmpeg.SWResample.Converter{
        source_caps: %Membrane.Caps.Audio.Raw{
          format: :s32le, sample_rate: 44_100, channels: 2
        }
      },
      # Stream data into PortAudio to play it on speakers.
      # sink: Membrane.Element.PortAudio.Sink,
      sink: %Membrane.Element.File.Sink{location: "result.mp3"},
      encoder: Membrane.Element.Lame.Encoder
    ]

    # Map that describes how we want data to flow
    # It is formated as such
    # {:child, :output_pad} => {:another_child, :input_pad}

    links = %{
      {:file_src, :source} => {:decoder, :sink},
      {:decoder, :source} => {:converter, :sink},
      {:converter, :source} => {:encoder, :sink},
      {:encoder, :source} => {:sink, :sink},
    }

    spec = %Membrane.Pipeline.Spec{
      children: children,
      links: links
    }

    {{:ok, spec}, %{}}
  end
end