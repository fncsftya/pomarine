with Pomarine.UI.Contexts;
with Options_VM;

--  How the tests see Options_VM through Pomarine.UI.
package Options_UI is

   package Options is new Pomarine.UI.Contexts (Options_VM.Commands, Options_VM.Model);

   package Caption is new Options.Read_Text (Options_VM.Caption);
   package Light_Adapter is new Options.Read_Flag (Options_VM.Light);
   package Dark_Adapter is new Options.Read_Flag (Options_VM.Dark);
   package Sync_Adapter is new Options.Read_Flag (Options_VM.Sync);
   package Running_Adapter is new Options.Read_Flag (Options_VM.Running);
   package Idle_Adapter is new Options.Read_Flag (Options_VM.Idle);
   package Title_Adapter is new Options.Indexed_Text (Options_VM.Card_Title);
   package Card_Adapter is new Options.Indexed_Flag (Options_VM.Has_Card);

   package Editable_Fraction is new Options.Edit_Fraction (Options_VM.Fraction, Options_VM.Advance);

   package Fraction_Adapter is new Options.Read_Fraction (Options_VM.Fraction);

   Light    : constant Options.Flag_Property := Light_Adapter.Property;
   Dark     : constant Options.Flag_Property := Dark_Adapter.Property;
   Sync     : constant Options.Flag_Property := Sync_Adapter.Property;
   Running  : constant Options.Flag_Property := Running_Adapter.Property;
   Idle     : constant Options.Flag_Property := Idle_Adapter.Property;
   Title    : constant Options.Text_Property := Title_Adapter.Property;
   Has_Card : constant Options.Flag_Property := Card_Adapter.Property;
   Fraction : constant Options.Fraction_Property := Fraction_Adapter.Property;

end Options_UI;
