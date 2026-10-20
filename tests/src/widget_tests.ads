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
   procedure Toolbar_Assist;
   --  The button at the right of the toolbar: off until allowed and while the
   --  text is blank, its click an Assist event, left out when it is not wanted.
   procedure Caret_Only;
   procedure Hiding;
   procedure Removing;
   procedure Window_Frame;

end Widget_Tests;
