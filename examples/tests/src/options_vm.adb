package body Options_VM is
   package VM renames Pomarine.View_Models;

   overriding function Version (Self : Model) return VM.Version_Number is (VM.Value (Self.Changes));

   overriding function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean is
     (case What is
         when Open_Card => Index in 1 .. Self.Cards,
         when Pick_Light => Index = 0 and then Self.Is_Dark,
         when Pick_Dark => Index = 0 and then not Self.Is_Dark,
         when Toggle_Sync => Index = 0 and then not Self.Locked,
         when Start => Index = 0 and then not Self.Busy,
         when Finish => Index = 0 and then Self.Busy);

   overriding procedure Execute (Self : in out Model; What : Command; Index : Natural := 0) is
   begin
      case What is
         when Pick_Light => Self.Is_Dark := False;
         when Pick_Dark => Self.Is_Dark := True;
         when Toggle_Sync => Self.Synced := not Self.Synced;
         when Start => Self.Busy := True; Self.Done := 0.0;
         when Finish => Self.Busy := False;
         when Open_Card => Self.Last := Index;
      end case;
      VM.Bump (Self.Changes);
   end Execute;

   function Caption (Self : Model) return String is (if Self.Is_Dark then "Dark command" else "Light command");
   function Dark (Self : Model) return Boolean is (Self.Is_Dark);
   function Light (Self : Model) return Boolean is (not Self.Is_Dark);
   function Sync (Self : Model) return Boolean is (Self.Synced);
   function Running (Self : Model) return Boolean is (Self.Busy);
   function Idle (Self : Model) return Boolean is (not Self.Busy);
   function Fraction (Self : Model) return Float is (Self.Done);

   function Card_Count (Self : Model) return Natural is (Self.Cards);
   function Card_Title (Self : Model; Row : Positive) return String is
     ("Card" & Row'Image);
   function Has_Card (Self : Model; Row : Positive) return Boolean is (Row <= Self.Cards);
   function Opened (Self : Model) return Natural is (Self.Last);

   procedure Set_Cards (Self : in out Model; To : Natural) is
   begin
      Self.Cards := To;
      VM.Bump (Self.Changes);
   end Set_Cards;

   procedure Advance (Self : in out Model; To : Float) is
   begin
      Self.Done := To;
      VM.Bump (Self.Changes);
   end Advance;

   procedure Lock_Sync (Self : in out Model) is
   begin
      Self.Locked := True;
      VM.Bump (Self.Changes);
   end Lock_Sync;

end Options_VM;
