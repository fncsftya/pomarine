package body Meter_VM is
   overriding
   function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean
   is (case What is
         when Raise_Level => Index = 0 and then Self.Height < 1.0);

   overriding
   procedure Perform (Self : in out Model; What : Command; Index : Natural := 0) is
      pragma Unreferenced (Index);
   begin
      case What is
         when Raise_Level =>
            Self.Height := Float'Min (1.0, Self.Height + 0.25);
      end case;
   end Perform;

   function Level (Self : Model) return Float
   is (Self.Height);

   procedure Set_Level (Self : in out Model; To : Float) is
   begin
      Self.Height := To;
      Mark_Changed (Self);
   end Set_Level;

   function Row_Text (Self : Model; Index : Positive) return String
   is ("Row" & Index'Image & (if Self.Ready then " ready" else ""));

   function Armed (Self : Model) return Boolean
   is (Self.Ready);

   procedure Set_Armed (Self : in out Model; To : Boolean) is
   begin
      Self.Ready := To;
      Mark_Changed (Self);
   end Set_Armed;

   function Is_Row_Odd (Self : Model; Index : Positive) return Boolean
   is (Index mod 2 = 1 and then Self.Height >= 0.0);

   function Can_Zero (Self : Model) return Boolean
   is (Self.Height > 0.0);

   procedure Zero (Self : in out Model) is
   begin
      Self.Height := 0.0;
      Self.Zeros := Self.Zeros + 1;
      Mark_Changed (Self);
   end Zero;

   function Zeroed (Self : Model) return Natural
   is (Self.Zeros);
end Meter_VM;
