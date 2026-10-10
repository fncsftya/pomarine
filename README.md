# Pomarine

A MacOS-only GUI library.

It has no pictures of its own: an application gives each `Pomarine.Icons.Icon`
a file (`Pomarine.Icons.Set_File`) in a folder of its own (`Set_Directory`), and
widgets are told which icon to show. The few the widgets draw themselves
(`Check`, `Close`, `Minimize`, `Chevron_Down`, `Chevron_Up`) are looked for
as `check.svg` and so on, unless given other files.
