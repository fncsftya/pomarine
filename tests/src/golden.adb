with Ada.Command_Line;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Animation_Tests;
with Command_Tests;
with Document_Tests;
with Field_Tests;
with Goldens;
with Layout_Tests;
with Keyboard_Tests;
with List_Tests;
with Listener_Tests;
with Painter_Tests;
with Picture_Tests;
with Platform_Tests;
with Semantic_Tests;
with Sheet_Tests;
with Text_Area_Tests;
with Widget_Tests;

--  Draws widgets and text areas by themselves, in various setups, and
--  compares what they draw with golden images: golden [part of a test's
--  name]. See Goldens.
procedure Golden is

   Filter : constant String :=
     (if Ada.Command_Line.Argument_Count > 0
      then Ada.Command_Line.Argument (1) else "");

   type Test_Procedure is access procedure;

   Ran : Natural := 0;

   procedure Run (Name : String; Test : not null Test_Procedure) is
   begin
      if Filter = "" or else Ada.Strings.Fixed.Index (Name, Filter) > 0 then
         Test.all;
         Ran := Ran + 1;
      end if;
   end Run;
begin
   Run ("document-loading", Document_Tests.Loading'Access);
   Run ("document-splicing", Document_Tests.Splicing'Access);
   Run ("document-ids", Document_Tests.Ids'Access);
   Run ("document-kinds", Document_Tests.Kinds'Access);
   Run ("document-steps", Document_Tests.Steps'Access);
   Run ("document-joining-edits", Document_Tests.Joining_Edits'Access);
   Run ("document-units", Document_Tests.Units'Access);
   Run ("document-against-a-string",
        Document_Tests.Against_A_String'Access);
   Run ("document-mapping", Document_Tests.Mapping'Access);

   Run ("layout-lines-after-edits", Document_Tests.Lines_After_Edits'Access);

   Run ("textarea-empty", Text_Area_Tests.Empty'Access);
   Run ("textarea-focused", Text_Area_Tests.Focused'Access);
   Run ("textarea-typing", Text_Area_Tests.Typing'Access);
   Run ("textarea-joining", Text_Area_Tests.Joining'Access);
   Run ("textarea-clusters", Text_Area_Tests.Clusters'Access);
   Run ("textarea-up-down", Text_Area_Tests.Up_And_Down'Access);
   Run ("textarea-end", Text_Area_Tests.Text_End'Access);
   Run ("textarea-scrolled", Text_Area_Tests.Scrolled'Access);
   Run ("textarea-clicked", Text_Area_Tests.Clicked'Access);
   Run ("textarea-escape", Text_Area_Tests.Escape'Access);
   Run ("textarea-zoomed", Text_Area_Tests.Zoomed'Access);
   Run ("textarea-select-keys", Text_Area_Tests.Selecting_Keys'Access);
   Run ("textarea-select-all", Text_Area_Tests.Select_All_And_Type'Access);
   Run ("textarea-paste", Text_Area_Tests.Copy_And_Paste'Access);
   Run ("textarea-cut-undo", Text_Area_Tests.Cut_And_Undo'Access);
   Run ("textarea-undo-typing", Text_Area_Tests.Undo_Typing'Access);
   Run ("textarea-words", Text_Area_Tests.Words'Access);
   Run ("textarea-dragged", Text_Area_Tests.Dragged'Access);
   Run ("textarea-bar", Text_Area_Tests.Scroll_Bar'Access);
   Run ("textarea-inactive-selection",
        Text_Area_Tests.Inactive_Selection'Access);
   Run ("textarea-blink", Text_Area_Tests.Blinking'Access);
   Run ("textarea-composing", Text_Area_Tests.Composing'Access);
   Run ("textarea-two-views", Text_Area_Tests.Two_Views'Access);
   Run ("textarea-long-paragraph", Text_Area_Tests.Long_Paragraph'Access);
   Run ("textarea-caret-box", Text_Area_Tests.Caret_Box_Kept'Access);

   Run ("field-typing", Field_Tests.Typing'Access);
   Run ("field-return", Field_Tests.Returning'Access);
   Run ("field-paste", Field_Tests.Pasting'Access);
   Run ("field-long", Field_Tests.Long_Line'Access);
   Run ("field-click", Field_Tests.Clicking'Access);
   Run ("field-up-down", Field_Tests.Up_And_Down'Access);

   Run ("painters-recording", Painter_Tests.Recording_Kept'Access);
   Run ("painters-replay", Painter_Tests.Replay_Is_Drawing'Access);
   Run ("painters-clips", Painter_Tests.Clips_Nest'Access);
   Run ("painters-full", Painter_Tests.Full_Recording'Access);

   Run ("semantics-whole", Semantic_Tests.Whole_Tree'Access);
   Run ("semantics-changes", Semantic_Tests.Only_Changes'Access);
   Run ("semantics-hiding", Semantic_Tests.Hiding_And_Showing'Access);
   Run ("semantics-actions", Semantic_Tests.Actions'Access);
   Run ("semantics-ids", Semantic_Tests.Stale_Ids'Access);
   Run ("semantics-menu", Semantic_Tests.Menu_Parts'Access);

   Run ("commands-handlers", Command_Tests.Own_Handlers'Access);
   Run ("commands-validated", Command_Tests.Validated'Access);
   Run ("commands-keys", Command_Tests.Keys'Access);
   Run ("commands-responders", Command_Tests.Responders'Access);
   Run ("commands-payloads", Command_Tests.Event_Payloads'Access);

   Run ("lists-few-rows", List_Tests.Few_Rows_Asked'Access);
   Run ("lists-choosing", List_Tests.Choosing'Access);
   Run ("lists-keys", List_Tests.Keys'Access);
   Run ("lists-rows-change", List_Tests.Rows_Come_And_Go'Access);
   Run ("lists-described", List_Tests.Described'Access);
   Run ("lists-drawn", List_Tests.Drawn'Access);

   Run ("layout-intrinsic", Layout_Tests.Intrinsic_Labels'Access);
   Run ("layout-pruned", Layout_Tests.Only_What_Changed'Access);

   Run ("application-posts", Platform_Tests.Posted_Work'Access);
   Run ("menus-choices", Platform_Tests.Menu_Choices'Access);
   Run ("settings-system", Platform_Tests.System_Settings'Access);

   Run ("animation-time", Animation_Tests.Moves_Over_Time'Access);
   Run ("animation-replaced", Animation_Tests.Replaced'Access);
   Run ("animation-reduced", Animation_Tests.Less_Movement'Access);
   Run ("animation-wakes", Animation_Tests.Wakes_The_Loop'Access);
   Run ("animation-scroll", Animation_Tests.Smooth_Scroll'Access);

   Run ("keyboard-tab", Keyboard_Tests.Tab_Order'Access);
   Run ("keyboard-operate", Keyboard_Tests.Operating_Widgets'Access);
   Run ("keyboard-off", Keyboard_Tests.Off_Until_Asked'Access);

   Run ("widgets-layout", Widget_Tests.Layout'Access);
   Run ("widgets-idle", Widget_Tests.Idle'Access);
   Run ("widgets-buttons", Widget_Tests.Buttons'Access);
   Run ("widgets-focus", Widget_Tests.Focus'Access);
   Run ("widgets-damage", Widget_Tests.Damage'Access);
   Run ("widgets-retained", Widget_Tests.Retained'Access);
   Run ("widgets-resized", Widget_Tests.Resized'Access);
   Run ("widgets-walk", Widget_Tests.Tree_Walk'Access);
   Run ("widgets-caret", Widget_Tests.Caret_Only'Access);
   Run ("widgets-hiding", Widget_Tests.Hiding'Access);
   Run ("widgets-removing", Widget_Tests.Removing'Access);
   Run ("widgets-window", Widget_Tests.Window_Frame'Access);

   Run ("listener-click", Listener_Tests.Click'Access);
   Run ("listener-commands", Listener_Tests.Command_Tags'Access);
   Run ("listener-own", Listener_Tests.Own_Listener'Access);
   Run ("listener-deferred", Listener_Tests.Deferred'Access);
   Run ("listener-controls", Listener_Tests.Controls'Access);
   Run ("layouts-helpers", Listener_Tests.Layout_Helpers'Access);

   Run ("sheet-board", Sheet_Tests.Board'Access);
   Run ("sheet-states", Sheet_Tests.States'Access);
   Run ("sheet-behaviour", Sheet_Tests.Behaviour'Access);

   Run ("pictures-selecting", Picture_Tests.Selecting'Access);
   Run ("pictures-following", Picture_Tests.Following_The_Picture'Access);

   Ada.Text_IO.Put_Line
     (Ran'Image & " tests:" & Natural'Image (Goldens.Passed)
      & " checks passed," & Natural'Image (Goldens.Failed) & " failed");
   if Ran = 0 or else Goldens.Failed > 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Golden;
