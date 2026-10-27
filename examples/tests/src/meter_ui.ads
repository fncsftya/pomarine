with Meter_VM;
with Pomarine.UI.Contexts;

--  Meter_VM through Pomarine.UI, every property made of the model's own subprograms.

package Meter_UI is
   package Meters is new Pomarine.UI.Contexts (Meter_VM.Commands, Meter_VM.Model);

   Level_Done : constant Meters.Fraction_Property := Meters.Showing (Meter_VM.Level'Access);
   Level_Set  : constant Meters.Fraction_Property := Meters.Editing (Meter_VM.Level'Access, Meter_VM.Set_Level'Access);
   Row_Label  : constant Meters.Text_Property := Meters.Showing (Meter_VM.Row_Text'Access);
   Armed_Flag : constant Meters.Flag_Property := Meters.Editing (Meter_VM.Armed'Access, Meter_VM.Set_Armed'Access);
   Odd_Flag   : constant Meters.Flag_Property := Meters.Showing (Meter_VM.Is_Row_Odd'Access);
   Zero_Level : constant Meters.Action_Property := Meters.Doing (Meter_VM.Can_Zero'Access, Meter_VM.Zero'Access);
end Meter_UI;
