--  UI components: widgets built on the graphics layers (SDL3 for drawing
--  and input, Typeset for text, Yoga for layout), for the application to
--  assemble into windows.
--
--  Start with Pomarine.UI.Run_Window for a window, Pomarine.UI.Contexts
--  for model-bound controls, and Pomarine.View_Models for commands and
--  change tracking. Pomarine.Models supplies rows to lists. For offscreen
--  interaction tests, see the separate Pomarine.Testing crate.
--
--  The checkout's docs/getting-started.md walks through a complete app;
--  docs/api-guide.md maps common tasks to packages and examples. The API
--  index also contains dependency units such as SDL3 and CoreText.

package Pomarine is

end Pomarine;
