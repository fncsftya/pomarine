--  What the person has asked of every application in the system's
--  settings, that a window's look and movement are to follow: less
--  movement, more contrast, less see-through. Looked at when asked (it is
--  cheap), not kept.
package Pomarine.System_Settings is

   function Reduce_Motion return Boolean;
   --  Do without movement that is not needed: animation, easing.

   function Increase_Contrast return Boolean;
   --  Make what is drawn easier to tell apart.

   function Reduce_Transparency return Boolean;

end Pomarine.System_Settings;
