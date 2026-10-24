--  Tests that a widget's setter, given what the widget already has, changes
--  nothing: a binding calls setters every time a view-model's version moves,
--  and must not make the window draw again for it. See Goldens.
package Setter_Tests is

   procedure Idempotent;

end Setter_Tests;
