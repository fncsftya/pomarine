package body Pomarine.View_Models is

   package Unbounded renames Ada.Strings.Unbounded;

   procedure Bump (Self : in out Change_Counter) is
   begin
      Self.Count := Self.Count + 1;
   end Bump;

   function Changed (Self : in out Watch; Now : Version_Number) return Boolean is
   begin
      if Self.Begun and then Self.Seen = Now then
         return False;
      end if;
      Self.Begun := True;
      Self.Seen := Now;
      return True;
   end Changed;

   procedure See (Self : in out Watch; Now : Version_Number) is
   begin
      Self.Begun := True;
      Self.Seen := Now;
   end See;

   package body Properties is

      function Get (Self : Property) return Element is (Self.Current);

      function Version (Self : Property) return Version_Number is (Value (Self.Count));

      procedure Set (Self : in out Property; To : Element) is
      begin
         if not (Self.Current = To) then
            Self.Current := To;
            Bump (Self.Count);
         end if;
      end Set;

      procedure Initialize (Self : out Property; To : Element) is
      begin
         Self.Current := To;
         Self.Count := Starting_At (0);
      end Initialize;

   end Properties;

   function Get (Self : Text_Property) return String is (Unbounded.To_String (Self.Current));

   function Version (Self : Text_Property) return Version_Number is (Value (Self.Count));

   procedure Set (Self : in out Text_Property; To : String) is
   begin
      if Unbounded.To_String (Self.Current) /= To then
         Self.Current := Unbounded.To_Unbounded_String (To);
         Bump (Self.Count);
      end if;
   end Set;

end Pomarine.View_Models;
