package body Form_VM is
   package VM renames Pomarine.View_Models;
   package U renames Ada.Strings.Unbounded;
   use type VM.Version_Number;

   function Image (Value : Natural) return String is
      Text : constant String := Value'Image;
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Image;

   procedure Note (Self : in out Model; Text : String) is
   begin
      U.Append (Self.Log, (if U.Length (Self.Log) = 0 then "" else " ") & Text);
   end Note;

   overriding function Version (Self : Model) return VM.Version_Number is
     (VM.Value (Self.Changed) + VM.Version (Self.Text));

   function Name_Version (Self : Model) return VM.Version_Number is (VM.Version (Self.Text));

   function Saved_Version (Self : Model) return VM.Version_Number is (VM.Value (Self.Changed));

   procedure Touch (Self : in out Model) is
   begin
      VM.Bump (Self.Changed);
   end Touch;

   function Name (Self : Model) return String is (VM.Get (Self.Text));

   function Normalized (Self : Model; Value : String) return String is
      First : Positive := Value'First;
   begin
      if not Self.Loud then
         return Value;
      end if;
      while First <= Value'Last and then Value (First) = ' ' loop
         First := First + 1;
      end loop;
      return Result : String := Value (First .. Value'Last) do
         for C of Result loop
            if C in 'a' .. 'z' then
               C := Character'Val (Character'Pos (C) - 32);
            end if;
         end loop;
      end return;
   end Normalized;

   procedure Set_Name (Self : in out Model; Value : String) is
   begin
      Note (Self, "set(" & Value & ")");
      if Inside_Set /= null then
         Inside_Set.all;
      end if;
      VM.Set (Self.Text, Normalized (Self, Value));
   end Set_Name;

   procedure Shouting (Self : in out Model; To : Boolean := True) is
   begin
      Self.Loud := To;
   end Shouting;

   function Saved_Count (Self : Model) return Natural is (Self.Saved);
   function Last_Saved (Self : Model) return String is (U.To_String (Self.Last));
   function Status (Self : Model) return String is (Image (Self.Saved) & " saved");
   function Journal (Self : Model) return String is (U.To_String (Self.Log));

   procedure Forget_Journal (Self : in out Model) is
   begin
      Self.Log := U.Null_Unbounded_String;
   end Forget_Journal;

   procedure Change_From_Elsewhere (Self : in out Model; Value : String) is
   begin
      VM.Set (Self.Text, Normalized (Self, Value));
   end Change_From_Elsewhere;

   overriding function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean is
     (Index = 0 and then
        (case What is
           when Save => Name (Self)'Length > 0,
           when Reset => Name (Self)'Length > 0 or else Self.Saved > 0));

   overriding procedure Execute (Self : in out Model; What : Command; Index : Natural := 0) is
      pragma Unreferenced (Index);
   begin
      case What is
         when Save =>
            Note (Self, "save(" & Name (Self) & ")");
            if Inside_Save /= null then
               Inside_Save.all;
            end if;
            Self.Saved := Self.Saved + 1;
            Self.Last := U.To_Unbounded_String (Name (Self));
            VM.Set (Self.Text, "");
         when Reset =>
            Note (Self, "reset");
            Self.Saved := 0;
            Self.Last := U.Null_Unbounded_String;
            VM.Set (Self.Text, "");
      end case;
      VM.Bump (Self.Changed);
   end Execute;

end Form_VM;
