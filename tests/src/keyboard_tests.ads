--  Tests of working a window from the keyboard alone: the focus going
--  round by Tab, and what each widget does with the keys it is given. See
--  Goldens.
package Keyboard_Tests is

   procedure Tab_Order;
   procedure Operating_Widgets;
   procedure Off_Until_Asked;
   procedure Ring_By_Keyboard_Only;
   procedure Click_Leaves_Focus;
   procedure Scoped_Tab;
   procedure Grip_Keys;

end Keyboard_Tests;
