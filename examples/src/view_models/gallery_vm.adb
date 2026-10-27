package body Gallery_VM is
   package VM renames Pomarine.View_Models;
   use type VM.Version_Number;

   overriding function Parts_Version (Self : Model) return VM.Version_Number is
     (VM.Version (Self.Text) + VM.Version_Number (Tasks.Version (Self.Items)));

   function Clicks (Self : Model) return Natural is (Self.Taps);
   function Summary (Self : Model) return String is
     ((if Self.Taps = 1 then "Clicked once" else "Clicked" & Self.Taps'Image & " times"));
   function Progress (Self : Model) return Float is
     (Float (Natural'Min (Self.Taps, Full_At)) / Float (Full_At));

   function Name (Self : Model) return String is (VM.Get (Self.Text));
   function Greeting (Self : Model) return String is
     (if Name (Self) = "" then "Hello, stranger!" else "Hello, " & Name (Self) & "!");

   procedure Set_Name (Self : in out Model; Text : String) is
   begin
      VM.Set (Self.Text, Text);
   end Set_Name;

   function Notify (Self : Model) return Boolean is (Self.Ticked);

   procedure Set_Notify (Self : in out Model; To : Boolean) is
   begin
      if Self.Ticked /= To then
         Self.Ticked := To;
         Mark_Changed (Self);
      end if;
   end Set_Notify;

   function Compact (Self : Model) return Boolean is (Self.Dense);
   function Size (Self : Model) return Positive is (Self.Picked);
   function Is_Size (Self : Model; Index : Positive) return Boolean is (Self.Picked = Index);

   function Count (Self : Model) return Natural is (Tasks.Count (Self.Items));
   function Selected_Item (Self : Model) return Natural is (Self.Choice);
   function Selected (Self : Model) return Natural is (Tasks.Find (Self.Items, Self.Choice));
   function Rows (Self : in out Model) return not null access Tasks.Task_List is
     (Self.Items'Unchecked_Access);
   function Row_Model (Self : in out Model) return not null access Pomarine.Models.List_Model'Class is
     (Self.Items'Unchecked_Access);

   procedure Select_Item (Self : in out Model; Id : Natural) is
   begin
      if Self.Choice /= Id then
         Self.Choice := Id;
         Mark_Changed (Self);
      end if;
   end Select_Item;

   procedure Select_Row (Self : in out Model; Row : Natural) is
   begin
      Select_Item (Self, (if Row = 0 then 0 else Tasks.Row_Id (Self.Items, Row)));
   end Select_Row;

   procedure Seed (Self : in out Model) is
   begin
      Tasks.Add (Self.Items, "Apples");
      Tasks.Add (Self.Items, "Bananas");
      Tasks.Add (Self.Items, "Cherries");
      Tasks.Add (Self.Items, "Damsons");
   end Seed;

   overriding function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean is
     (case What is
         when Click_Me        => Index = 0 and then Self.Taps < Natural'Last,
         when Reset           => Index = 0 and then Self.Taps > 0,
         when Toggle_Compact  => Index = 0,
         when Pick_Size       => Index in 1 .. Size_Count,
         when Remove_Chosen   => Index = 0 and then Selected (Self) > 0);

   overriding procedure Perform (Self : in out Model; What : Command; Index : Natural := 0) is
   begin
      case What is
         when Click_Me       => Self.Taps := @ + 1;
         when Reset          => Self.Taps := 0;
         when Toggle_Compact => Self.Dense := not @;
         when Pick_Size      => Self.Picked := Index;
         when Remove_Chosen  =>
            Tasks.Delete (Self.Items, Selected (Self));
            Self.Choice := 0;
      end case;
   end Perform;
end Gallery_VM;
