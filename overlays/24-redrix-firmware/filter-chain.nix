# Native audioconvert graphs: no extra sinks, streams, or asynchronous gain writer.
let
  library = "redrix-cras-dsp";
in
{
  speaker = {
    nodes = [
      {
        type = "ladspa";
        name = "cras";
        plugin = library;
        label = "redrix_cras_dsp";
      }
      {
        type = "ladspa";
        name = "gain";
        plugin = library;
        label = "redrix_speaker_gain";
        control = {
          "Volume Left" = 0;
          "Volume Right" = 0;
        };
      }
    ];
    links = [
      {
        output = "cras:Output Left";
        input = "gain:Input Left";
      }
      {
        output = "cras:Output Right";
        input = "gain:Input Right";
      }
    ];
    inputs = [
      "cras:Input Left"
      "cras:Input Right"
    ];
    outputs = [
      "gain:Output Left"
      "gain:Output Right"
    ];
    # audioconvert forwards node Props to the graph's capture volume controls,
    # even on a capture device. Mute is delivered as zero on these controls.
    "capture.volumes" = [
      {
        control = "gain:Volume Left";
        min = 0;
        max = 100;
        scale = "cubic";
      }
      {
        control = "gain:Volume Right";
        min = 0;
        max = 100;
        scale = "cubic";
      }
    ];
  };
  microphone = {
    nodes = [
      {
        type = "ladspa";
        name = "gain";
        plugin = library;
        label = "redrix_mic_gain";
        control."Volume" = 0;
      }
    ];
    inputs = [ "gain:Input" ];
    outputs = [ "gain:Output" ];
    "capture.volumes" = [
      {
        control = "gain:Volume";
        min = 0;
        max = 100;
        scale = "cubic";
      }
    ];
  };
}
