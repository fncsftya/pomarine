with Meter_UI;
with Meter_VM;
with Pomarine.Testing;
with Pomarine.UI;
with Pomarine.View_Models;
with Pomarine.Widgets;

--  Properties from a model's own subprograms, controls placed in one step, and a model that counts its own changes.

procedure UI_Properties_Test is
   package UI renames Pomarine.UI;
   package Testing renames Pomarine.Testing;
   package Widgets renames Pomarine.Widgets;
   package Meters renames Meter_UI.Meters;
   use type Pomarine.View_Models.Version_Number;

   procedure Observed_Model_Counts_Its_Changes is
      Item    : Meter_VM.Model;
      Before  : Pomarine.View_Models.Version_Number := Meter_VM.Version (Item);
      Refused : Boolean := False;
   begin
      Meter_VM.Execute (Item, Meter_VM.Raise_Level);
      pragma Assert (Meter_VM.Level (Item) = 0.25 and then Meter_VM.Version (Item) /= Before);
      Before := Meter_VM.Version (Item);
      Meter_VM.Set_Armed (Item, True);
      pragma Assert (Meter_VM.Version (Item) /= Before);
      for Step in 1 .. 3 loop
         Meter_VM.Execute (Item, Meter_VM.Raise_Level);
      end loop;
      pragma Assert (not Meter_VM.Can_Execute (Item, Meter_VM.Raise_Level));
      begin
         Meter_VM.Execute (Item, Meter_VM.Raise_Level);
      exception
         when others =>
            Refused := True;
      end;
      pragma Assert (Refused and then Meter_VM.Level (Item) = 1.0);
   end Observed_Model_Counts_Its_Changes;

   procedure Properties_Of_Subprograms is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Meter_VM.Model;
      Screen : UI.View (Tree'Access);
      Window : Testing.Session;
   begin
      pragma Assert (Meters.Is_Writable (Meter_UI.Level_Set) and then not Meters.Is_Writable (Meter_UI.Level_Done));
      pragma Assert (Meters.Is_Settable (Meter_UI.Armed_Flag) and then not Meters.Is_Settable (Meter_UI.Odd_Flag));
      declare
         Bound : constant Meters.Context'Class := Meters.Bind (Screen, Model'Access);
      begin
         UI.Mount
           (Screen,
            UI.Column
              ([Bound.Label (Meter_UI.Row_Label, Index => 2, Tooltip => "The second row"),
                Bound.Label (Meter_UI.Row_Label, Index => 3),
                Bound.Check ("Armed", Meter_UI.Armed_Flag, Name => "Armed", Width => 120.0),
                Bound.Button ("Raise", Meter_VM.Raise_Level, Width => 90.0),
                Bound.Button ("Zero", Meter_UI.Zero_Level, Width => 90.0),
                Bound.Progress (Meter_UI.Level_Done, Height => 8.0)],
               Padding => 8.0,
               Gap     => 8.0));
      end;
      Testing.Open (Window, Tree, 300, 300);
      pragma Assert (Testing.Shows (Window, "text 'Row 2'") and then Testing.Shows (Window, "text 'Row 3'"));
      pragma Assert (Testing.Is_Disabled (Window, "Zero"));

      --  An indexed text and a flag the person sets, both of the model's own subprograms.
      Testing.Click_On (Window, "Armed");
      pragma Assert (Meter_VM.Armed (Model));
      pragma Assert (Testing.Shows (Window, "text 'Row 2 ready'"));

      --  A command of the enumeration turns an action of subprograms on, which does what the model says.
      Testing.Click_On (Window, "Raise");
      pragma Assert (Meter_VM.Level (Model) = 0.25 and then not Testing.Is_Disabled (Window, "Zero"));
      Testing.Click_On (Window, "Zero");
      pragma Assert (Meter_VM.Level (Model) = 0.0 and then Meter_VM.Zeroed (Model) = 1);
      pragma Assert (Testing.Is_Disabled (Window, "Zero"));
   end Properties_Of_Subprograms;
begin
   Observed_Model_Counts_Its_Changes;
   Properties_Of_Subprograms;
end UI_Properties_Test;
