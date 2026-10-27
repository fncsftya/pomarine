--  Drawings and descriptions of the gallery (examples/src/gallery.ads), which has the general controls on one
--  sheet: as it opens, after it is used, in the dark theme and at twice the density, and what an assistive
--  technology is told of it. A change to any widget, to the layout or to the theme shows in these first.
--  See Goldens.

package Gallery_Tests is

   procedure Opens;
   procedure Used;
   procedure Dark;
   procedure Dense;
   procedure Described;
   procedure Context_Open;
   procedure Scrolled_Sheet;
   procedure Number_Invalid;
   procedure Select_Open;
   procedure Popover_Open;
   procedure Dialog_Open;
   procedure Tooltip_Shown;
   --  What opens over the screen: a select's own menu, a popover, a modal dialog, a tooltip that shows itself.

end Gallery_Tests;
