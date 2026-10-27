package body Pomarine.Semantics is

   procedure Set (Item : out Text; To : String) is
      Last : Natural := Natural'Min (To'Length, Text_Capacity);
   begin
      --  Not in the middle of a UTF-8 character: back to where one starts.
      if Last < To'Length then
         while Last > 0 and then Character'Pos (To (To'First + Last)) in 16#80# .. 16#BF# loop
            Last := Last - 1;
         end loop;
      end if;
      Item.Used := Last;
      Item.Chars (1 .. Last) := To (To'First .. To'First + Last - 1);
   end Set;

   procedure Set (Item : out Long_Text; To : String) is
      Last : Natural := Natural'Min (To'Length, Value_Capacity);
   begin
      if Last < To'Length then
         while Last > 0 and then Character'Pos (To (To'First + Last)) in 16#80# .. 16#BF# loop
            Last := Last - 1;
         end loop;
      end if;
      Item.Used := Last;
      Item.Chars (1 .. Last) := To (To'First .. To'First + Last - 1);
   end Set;

   procedure Name_As (Item : in out Description; To : String) is
   begin
      Set (Item.Name, To);
   end Name_As;

   procedure Value_As (Item : in out Description; To : String) is
   begin
      Set (Item.Value, To);
   end Value_As;

   procedure Help_As (Item : in out Description; To : String) is
   begin
      Set (Item.Help, To);
   end Help_As;

   function Image (Item : Role) return String
   is (case Item is
         when Unknown              => "element",
         when Window               => "window",
         when Group                => "group",
         when Label                => "text",
         when Heading              => "heading",
         when Button               => "button",
         when Toggle_Button        => "toggle button",
         when Check_Box            => "check box",
         when Radio_Button         => "radio button",
         when Switch               => "switch",
         when Slider               => "slider",
         when Progress_Indicator   => "progress indicator",
         when Text_Input           => "text field",
         when Multiline_Text_Input => "text area",
         when Menu                 => "menu",
         when Menu_Item            => "menu item",
         when List                 => "list",
         when List_Item            => "list item",
         when Scroll_View          => "scroll area",
         when Image                => "image",
         when Canvas               => "canvas",
         when Dialog               => "dialog",
         when Tooltip              => "tooltip",
         when Status               => "status",
         when Separator            => "separator",
         when Document             => "document",
         when Text_Run             => "text");

end Pomarine.Semantics;
