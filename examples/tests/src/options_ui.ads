with Pomarine.UI.Contexts;
with Options_VM;

--  How the tests see Options_VM through Pomarine.UI.

package Options_UI is

   package Options is new Pomarine.UI.Contexts (Options_VM.Commands, Options_VM.Model);

   Caption           : constant Options.Text_Property := Options.Showing (Options_VM.Caption'Access);
   Light             : constant Options.Flag_Property := Options.Showing (Options_VM.Light'Access);
   Dark              : constant Options.Flag_Property := Options.Showing (Options_VM.Dark'Access);
   Sync              : constant Options.Flag_Property := Options.Showing (Options_VM.Sync'Access);
   Running           : constant Options.Flag_Property := Options.Showing (Options_VM.Running'Access);
   Idle              : constant Options.Flag_Property := Options.Showing (Options_VM.Idle'Access);
   Title             : constant Options.Text_Property := Options.Showing (Options_VM.Card_Title'Access);
   Has_Card          : constant Options.Flag_Property := Options.Showing (Options_VM.Has_Card'Access);
   Editable_Fraction : constant Options.Fraction_Property :=
     Options.Editing (Options_VM.Fraction'Access, Options_VM.Advance'Access);
   Fraction          : constant Options.Fraction_Property := Options.Showing (Options_VM.Fraction'Access);

end Options_UI;
