with Ada.Strings.Bounded;
with Interfaces.C.Strings;
with SDL3.Events;
with System.Address_To_Access_Conversions;

package body SDL3.Dialogs is

   package C renames Interfaces.C;

   package Paths is new Ada.Strings.Bounded.Generic_Bounded_Length (Max_Path);

   protected Answer is
      procedure Ask;
      procedure Give (To : States; Where : String := "");
      procedure Forget;
      function Current return States;
      function Chosen_Path return String;
   private
      Now   : States := Idle;
      Found : Paths.Bounded_String;
   end Answer;

   protected body Answer is
      procedure Ask is
      begin
         Now := Waiting;
         Found := Paths.Null_Bounded_String;
      end Ask;

      procedure Give (To : States; Where : String := "") is
      begin
         Now := To;
         Found := Paths.To_Bounded_String (Where, Ada.Strings.Right);
      end Give;

      procedure Forget is
      begin
         Now := Idle;
         Found := Paths.Null_Bounded_String;
      end Forget;

      function Current return States is (Now);
      function Chosen_Path return String is (Paths.To_String (Found));
   end Answer;

   type Filter is record
      Name    : System.Address;
      Pattern : System.Address;
   end record
     with Convention => C;

   --  The filter outlives the call: the dialog is shown after it.
   Name_Text    : aliased C.char_array (0 .. 63);
   Pattern_Text : aliased C.char_array (0 .. 255);
   The_Filter   : aliased Filter;

   package Pointers is
     new System.Address_To_Access_Conversions (C.Strings.chars_ptr);

   procedure Answered
     (User   : System.Address;
      List   : System.Address;
      Picked : C.int)
     with Convention => C;

   procedure Answered
     (User   : System.Address;
      List   : System.Address;
      Picked : C.int)
   is
      pragma Unreferenced (User, Picked);
      use type C.Strings.chars_ptr;
      use type System.Address;
   begin
      if List = System.Null_Address then
         Answer.Give (Failed);
      elsif Pointers.To_Pointer (List).all = C.Strings.Null_Ptr then
         Answer.Give (Cancelled);
      else
         declare
            Chosen_File : constant String :=
              C.Strings.Value (Pointers.To_Pointer (List).all);
         begin
            if Chosen_File'Length in 1 .. Max_Path then
               Answer.Give (Chosen, Chosen_File);
            else
               Answer.Give (Failed);
            end if;
         end;
      end if;
      SDL3.Events.Wake;
   end Answered;

   procedure Show
     (Callback : System.Address;
      User     : System.Address;
      Over     : System.Address;
      Filters  : System.Address;
      Count    : C.int;
      Where    : System.Address;
      Several  : C.C_bool)
     with Import, Convention => C, External_Name => "SDL_ShowOpenFileDialog";

   procedure Open_File
     (Over       : SDL3.Windows.Window;
      Name       : String;
      Extensions : String)
   is
      Used : C.size_t;
   begin
      Answer.Ask;
      C.To_C (Name, Name_Text, Used);
      C.To_C (Extensions, Pattern_Text, Used);
      The_Filter := (Name_Text'Address, Pattern_Text'Address);
      Show
        (Answered'Address, System.Null_Address, SDL3.Windows.Raw_Handle (Over),
         (if Extensions = "" then System.Null_Address else The_Filter'Address),
         (if Extensions = "" then 0 else 1), System.Null_Address, C.C_bool (False));
   end Open_File;

   procedure Show_Save
     (Callback : System.Address;
      User     : System.Address;
      Over     : System.Address;
      Filters  : System.Address;
      Count    : C.int;
      Where    : System.Address)
     with Import, Convention => C, External_Name => "SDL_ShowSaveFileDialog";

   Suggested_Text : aliased C.char_array (0 .. 255);

   procedure Save_File
     (Over       : SDL3.Windows.Window;
      Name       : String;
      Extensions : String;
      Suggested  : String)
   is
      Used : C.size_t;
   begin
      Answer.Ask;
      C.To_C (Name, Name_Text, Used);
      C.To_C (Extensions, Pattern_Text, Used);
      C.To_C (Suggested, Suggested_Text, Used);
      The_Filter := (Name_Text'Address, Pattern_Text'Address);
      Show_Save
        (Answered'Address, System.Null_Address, SDL3.Windows.Raw_Handle (Over),
         (if Extensions = "" then System.Null_Address else The_Filter'Address),
         (if Extensions = "" then 0 else 1),
         (if Suggested = "" then System.Null_Address else Suggested_Text'Address));
   end Save_File;

   function State return States is (Answer.Current);

   function Path return String is (Answer.Chosen_Path);

   procedure Reset is
   begin
      Answer.Forget;
   end Reset;

end SDL3.Dialogs;
