# Media Player Example App

This directory contains an application that uses media and scenic to
create a media player.

## USAGE

The media player uses a file reader or a network reader. To use the file
reader, you'll need to have an accessible file. Here's an example command line:

    present_view mediaplayer_skia /data/vid.ogv

Paths must be absolute (start with a '/'). Here's an example using the network
reader:

    present_view mediaplayer_skia http://example.com/vid.ogv

The app responds to mouse clicks, touch and the keyboard. Scenic
requires a touch to focus the keyboard. Touching anywhere but the progress bar
toggles between play and pause. Touching the progress bar does a seek to that
point. The space bar toggles between play and pause. 'q' quits.
