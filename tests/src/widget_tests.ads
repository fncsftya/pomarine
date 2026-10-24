--  Tests of the widget tree: how it lays out, takes events, keeps track
--  of what has changed, and draws only that. See Goldens.
package Widget_Tests is

   procedure Layout;
   procedure Idle;
   procedure Buttons;
   procedure Focus;
   procedure Damage;
   procedure Retained;
   procedure Resized;
   procedure Tree_Walk;
   procedure Toolbar;
   procedure Toolbar_Tools;
   procedure Toolbar_Editing;
   procedure Toolbar_Fonts;
   --  The buttons the application adds after the style buttons: off without a selection
   --  when they need one, their click or Command and their key a Use_Tool event.
   procedure Links;
   procedure Versions;
   --  Writing another version of a selection, taking it or giving it up, and going
   --  through the versions of a text that has them, by the bar and by the arrow keys.
   procedure Caret_Only;
   procedure Hiding;
   procedure Removing;
   procedure Window_Frame;

end Widget_Tests;
