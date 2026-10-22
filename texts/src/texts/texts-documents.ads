with Ada.Containers.Vectors;
private with Ada.Finalization;
with Ada.Strings.Unbounded;

--  A document: paragraphs of text, each with an id and a kind, edited by
--  replacing what is between two positions; a log of those changes, for
--  views to catch up with; and the history of edits, to undo.
--
--  An edit within a paragraph costs about what it adds or removes, and
--  the distance from the last edit there; one that adds or removes
--  paragraphs costs their length and, once, their number. Converting
--  between bytes and UTF-16 units costs about the distance from the
--  last edit to the paragraph, the first time, and little after.
package Texts.Documents is

   type Document is limited private;

   type Document_Access is access all Document;
   --  For views, which show a document they do not own.

   procedure Load (Item : in out Document; Content : String);
   --  Replace the text with Content, a paragraph to each line (ended by
   --  LF or CR LF), each new and Plain. Forgets the history, and the log:
   --  views start again.

   function Count (Item : Document) return Positive;
   --  How many paragraphs: there is always one, perhaps empty.

   function Text (Item : Document; Para : Positive) return String
     with Pre => Para <= Count (Item);

   function Slice
     (Item : Document; Para : Positive; First, Stop : Positive)
      return String
     with Pre => Para <= Count (Item) and then First <= Stop
                 and then Stop <= Byte_Length (Item, Para) + 1;
   --  The bytes First .. Stop - 1 of the paragraph's text: no more is
   --  copied.

   function Byte_Length (Item : Document; Para : Positive) return Natural
     with Pre => Para <= Count (Item);

   function Length (Item : Document; Para : Positive) return Natural
     with Pre => Para <= Count (Item);
   --  In UTF-16 units. A loaded paragraph's is counted when first asked
   --  for: Byte_Length is quicker, as an estimate.

   function Id (Item : Document; Para : Positive) return Paragraph_Id
     with Pre => Para <= Count (Item);

   function Find (Item : Document; Name : Paragraph_Id) return Natural
     with Post => Find'Result <= Count (Item);
   --  The paragraph with id Name, or 0 if none has it now.

   function Kind (Item : Document; Para : Positive) return Paragraph_Kind
     with Pre => Para <= Count (Item);

   function Inset (Item : Document; Para : Positive) return Paragraph_Inset
     with Pre => Para <= Count (Item);

   type Format is (Bold, Underline, Italic, Strikethrough, Faded, Sized, Faced, Versioned);
   --  Faded is text drawn part see-through. Sized is text of its own size
   --  (a run's Choice is its points) and Faced text of its own family (its
   --  Name): runs of these are told apart by what they say, and never
   --  overlap. Versioned is text that has several versions, one of which is
   --  the text (see Add_Version).
   type Format_Set is array (Format) of Boolean;
   No_Formats : constant Format_Set := [others => False];

   package Version_Lists is new Ada.Containers.Vectors
     (Positive, Ada.Strings.Unbounded.Unbounded_String, "=" => Ada.Strings.Unbounded."=");

   type Format_Run is record
      From, To : Position;
      Style : Format;
      Choice   : Natural := 0;
      Versions : Version_Lists.Vector;
      --  Of a Versioned run: the versions in order, and which is the text,
      --  whose place in Versions is not kept up to date while it is.
      Name     : Ada.Strings.Unbounded.Unbounded_String;
      --  Of a Faced run: the family.
   end record;

   function Run_Count (Item : Document) return Natural;
   function Run (Item : Document; Index : Positive) return Format_Run
     with Pre => Index <= Run_Count (Item);
   function Has_Format (Item : Document; From, To : Position; Style : Format) return Boolean
     with Pre => Is_Position (Item, From) and then Is_Position (Item, To) and then not (To < From);
   procedure Set_Format (Item : in out Document; From, To : Position; Style : Format; Enabled : Boolean)
     with Pre => Is_Position (Item, From) and then Is_Position (Item, To) and then From < To
                 and then Style not in Sized | Faced | Versioned,
          Post => Has_Format (Item, From, To, Style) = Enabled;

   Largest_Size : constant := 999;
   --  Points.

   function Size_At (Item : Document; From, To : Position) return Natural
     with Pre => Is_Position (Item, From) and then Is_Position (Item, To) and then not (To < From);
   function Family_At (Item : Document; From, To : Position) return String
     with Pre => Is_Position (Item, From) and then Is_Position (Item, To) and then not (To < From);
   --  The size in points, or the family, of what is from From to To: of the
   --  text at From, or, if From = To, before it (what is typed there is of
   --  it); 0, or "", if it has none of its own.

   procedure Set_Size (Item : in out Document; From, To : Position; Points : Natural)
     with Pre => Is_Position (Item, From) and then Is_Position (Item, To) and then From < To
                 and then Points <= Largest_Size;
   procedure Set_Family (Item : in out Document; From, To : Position; Name : String)
     with Pre => Is_Position (Item, From) and then Is_Position (Item, To) and then From < To
                 and then (for all C of Name => C not in '"' | '<' | '>' | '&' | ASCII.LF | ASCII.CR);
   --  Make the text from From to To of that size, or family, over any other
   --  there; none (0 or "") to give it back its default. One step to undo.

   --  Versions: a span of one paragraph's text can have several versions,
   --  as of a wording, of which one is the text and the others are kept.

   function Version_At (Item : Document; At_Point : Position) return Natural;
   --  The index (as Run's) of the Versioned run that has At_Point in it
   --  (its end is not), or 0.

   function Version_Overlapping (Item : Document; From, To : Position) return Natural;
   --  The index of the first Versioned run that shares text with From to To
   --  (or, if From = To, has From in it), or 0.

   function Escaped (Raw : String) return String;
   --  Raw as markup: with & < > as &amp; &lt; &gt;, and no line breaks.

   function Fragment (Item : Document; From, To : Position) return String
     with Pre => Is_Position (Item, From) and then Is_Position (Item, To) and then not (To < From)
                 and then From.Paragraph = To.Paragraph;
   --  The text from From to To as markup, with its styles but not versions:
   --  what a version is kept as.

   procedure Add_Version
     (Item : in out Document; From, To : Position; Words : String)
     with Pre => Is_Position (Item, From) and then Is_Position (Item, To) and then From < To
                 and then From.Paragraph = To.Paragraph and then Words'Length > 0;
   --  Make Words, markup as Fragment gives, the text from From to To, and
   --  keep what was there as a version, as one step to undo. If a
   --  Versioned run is exactly From to To, Words is a new version of it;
   --  if not, it is made one, of two.

   procedure Choose_Version (Item : in out Document; Index : Positive; Choice : Positive)
     with Pre => Index <= Run_Count (Item) and then Run (Item, Index).Style = Versioned
                 and then Choice <= Natural (Run (Item, Index).Versions.Length);
   --  Make the text of the Versioned run Index its version Choice, as one
   --  step to undo. What was the text is kept as its version.

   procedure Discard_Redo (Item : in out Document);
   --  Forget the steps taken back.

   --  What is kept of a document, as markup: <version>1</version>, then a
   --  <p> for each paragraph, its text with & < > as &amp; &lt; &gt;, and
   --  <b>, <i>, <u>, <s> and <f> round the runs of bold, italic, underlined,
   --  struck-through and faded text, <z n="14"> and <y n="Georgia"> round
   --  those of a size, in points, and a family, and <v sel="N"> the run of a text with
   --  versions, with the other versions, as markup of their own, in <o> in it before the text; N is
   --  which version, of them all, the text is. Text without a <version> is plain, a paragraph
   --  to each line: Upgraded makes the markup of it, and Load_Stored loads
   --  it so. Markup that is not well formed, or of a version not known, is
   --  rejected with Constraint_Error, and the document left as it was.
   function Stored (Item : Document) return String;
   function Upgraded (Content : String) return String;
   function Plain_Stored (Content : String) return String;
   --  The text of Content alone, a line to each paragraph.
   procedure Load_Stored (Item : in out Document; Content : String);

   --  Positions

   function Is_Boundary
     (Item : Document; Para : Positive; Index : Positive) return Boolean
     with Pre => Para <= Count (Item)
                 and then Index <= Byte_Length (Item, Para) + 1;
   --  Whether byte Index is where a character starts, or the end.

   function Is_Position (Item : Document; At_Point : Position)
      return Boolean
   is (At_Point.Paragraph <= Count (Item)
       and then At_Point.Index <= Byte_Length (Item, At_Point.Paragraph) + 1
       and then Is_Boundary (Item, At_Point.Paragraph, At_Point.Index));

   function Paragraph_End (Item : Document; Para : Positive) return Position
     with Pre => Para <= Count (Item);

   function Text_End (Item : Document) return Position;

   function Between (Item : Document; From, To : Position) return String
     with Pre => Is_Position (Item, From) and then Is_Position (Item, To)
                 and then not (To < From);
   --  The text from From to To, a line to each paragraph.

   function Whole (Item : Document) return String;
   --  All of it, a line to each paragraph.

   function Units_Before
     (Item : Document; Para : Positive; Index : Positive) return Natural
     with Pre  => Para <= Count (Item)
                  and then Index <= Byte_Length (Item, Para) + 1
                  and then Is_Boundary (Item, Para, Index),
          Post => Units_Before'Result <= Length (Item, Para);
   --  The UTF-16 units before byte Index of the paragraph's text.

   function Index_Of
     (Item : Document; Para : Positive; Units : Natural) return Positive
     with Pre  => Para <= Count (Item) and then Units <= Length (Item, Para),
          Post => Index_Of'Result <= Byte_Length (Item, Para) + 1
                  and then Is_Boundary (Item, Para, Index_Of'Result);
   --  The byte index of the character that starts at UTF-16 unit Units,
   --  or that Units is inside, as the second of a surrogate pair is.

   --  Editing

   type Edit_Kind is (Typing, Deleting_Back, Deleting_Forward, Other);
   --  Edits of the first three kinds in a row are undone together.

   procedure Replace
     (Item     : in out Document;
      From, To : Position;
      By       : String;
      Undo_As  : Edit_Kind := Other;
      Recorded : Boolean := True;
      Explicit_Formats : Boolean := False;
      Formats : Format_Set := No_Formats;
      Sizing  : Natural := 0;
      Facing  : String := "")
     with Pre  => Is_Position (Item, From) and then Is_Position (Item, To)
                  and then not (To < From)
                  and then (for all C of By => C /= ASCII.CR),
          Post => Count (Item)
                  = Count (Item)'Old - (To.Paragraph - From.Paragraph)
                    + (End_After (From, By).Paragraph - From.Paragraph)
                  and then Is_Position (Item, End_After (From, By));
   --  Replace the text from From to To with By, a line to each paragraph;
   --  it ends at End_After (From, By). From's paragraph keeps its id and
   --  kind; the rest of those from From to To go; each line feed in By
   --  starts a new Plain paragraph.
   --
   --  Explicit_Formats, the text is in just the Formats, and of size Sizing
   --  and family Facing if they are Sized and Faced.
   --
   --  Recorded, it can be undone. An edit not recorded, as of what an
   --  input method shows before it is typed, must be taken back before
   --  the next recorded one: the history does not allow for it.

   procedure Set_Kind
     (Item : in out Document; Para : Positive; To : Paragraph_Kind)
     with Pre  => Para <= Count (Item),
          Post => Kind (Item, Para) = To;
   --  An edit, which can be undone.

   procedure Set_Inset
     (Item : in out Document; Para : Positive; To : Paragraph_Inset)
     with Pre  => Para <= Count (Item),
          Post => Inset (Item, Para) = To;
   --  An edit, which can be undone. Stored as attributes of the paragraph.

   --  The history of edits

   procedure Begin_Step (Item : in out Document);
   procedure End_Step (Item : in out Document)
     with Pre => In_Step (Item);
   --  The edits between are one step to undo, as for an application's
   --  command. Steps may nest: the outermost is the step.

   function In_Step (Item : Document) return Boolean;

   procedure Seal (Item : in out Document);
   --  Make the next edit a step of its own, not joined to the last, as
   --  when a caret has moved between typing.

   procedure Undo
     (Item : in out Document;
      From, To : out Position)
     with Pre  => Can_Undo (Item) and then not In_Step (Item),
          Post => Is_Position (Item, From) and then Is_Position (Item, To);
   --  Take back the last step not taken back. From and To are around
   --  what it restored, as to select it.

   procedure Redo
     (Item : in out Document;
      From, To : out Position)
     with Pre  => Can_Redo (Item) and then not In_Step (Item),
          Post => Is_Position (Item, From) and then Is_Position (Item, To);
   --  Make the last step taken back again; From and To are around what
   --  it made.

   function Can_Undo (Item : Document) return Boolean;
   function Can_Redo (Item : Document) return Boolean;

   Undo_Depth : constant := 1000;
   --  How many steps back can be undone.

   function State (Item : Document) return Natural;
   --  Names the text as it is: 0 as loaded. Undoing or redoing back to a
   --  state gives the same text, and its name; any other edit gives one
   --  not seen before. So the text is changed since it was saved if its
   --  state is not what it was then.

   --  The log of changes, for views to catch up with: each edit, recorded
   --  or not, is a change.

   type Version is new Natural;

   function Current (Item : Document) return Version;
   --  Of the text: one more for each change.

   function Oldest (Item : Document) return Version
     with Post => Oldest'Result <= Current (Item);
   --  The earliest version the log goes back to: a view that last saw an
   --  earlier one must start again.

   Log_Length : constant := 4096;
   --  Changes kept: the log goes back at least this far, since Load.

   function Serial (Item : Document) return Positive;
   --  Names the document, among all of them, for a view to tell whether
   --  it is showing this one.

   type Change is record
      From, To   : Position;  --  the text replaced, as it was
      Ending     : Position;  --  where what replaced it ends, now
      From_Units : Natural := 0;
      To_Units   : Natural := 0;  --  in To's paragraph, as it was
      End_Units  : Natural := 0;  --  in Ending's paragraph, now
      Old_Length : Natural := 0;  --  of From's paragraph, in units
      Kind_Only  : Boolean := False;
      --  Only From's paragraph's kind changed.
      Formats_Only : Boolean := False;
      --  Formatting changed; character positions remain unchanged.
   end record;
   --  Positions in UTF-8 bytes, and the same in UTF-16 units, for
   --  layout.

   function Change_After (Item : Document; Seen : Version) return Change
     with Pre => Seen >= Oldest (Item) and then Seen < Current (Item);
   --  The change that made the version after Seen.

   function Map (Item : Change; At_Point : Position) return Position;
   --  Where a position in the text before the change is after it: one
   --  in what was replaced goes to its start, one after it moves with
   --  the text.

private

   type Text_Access is access String;

   type Mark_Array is array (Natural range <>) of Natural;
   type Mark_Access is access Mark_Array;

   Mark_Spacing : constant := 256;
   --  Bytes between the UTF-16 offsets kept of a paragraph's text.

   type Paragraph is limited record
      Buffer    : Text_Access;
      Gap_First : Positive := 1;
      Gap_Size  : Natural := 0;
      --  The text is Buffer without Buffer (Gap_First .. Gap_First +
      --  Gap_Size - 1): edits are made at the gap, which moves to them,
      --  so that typing in a long paragraph moves little of it.
      Units     : Natural := 0;
      Counted   : Boolean := True;
      --  Units is the text's UTF-16 length: counted when first wanted,
      --  not when loaded.
      Id        : Paragraph_Id := 1;
      Kind      : Paragraph_Kind := Plain;
      Inset     : Paragraph_Inset;
      Marks     : Mark_Access;
      Marked    : Natural := 0;
      --  Marks (K): the units of the first K * Mark_Spacing bytes, right
      --  for K < Marked; made as far as wanted.
   end record;

   type Paragraph_Access is access Paragraph;

   package Paragraph_Vectors is new Ada.Containers.Vectors
     (Positive, Paragraph_Access);

   type Named is record
      Id    : Paragraph_Id := 1;
      Kind  : Paragraph_Kind := Plain;
      Inset : Paragraph_Inset;
   end record;

   package Named_Vectors is new Ada.Containers.Vectors (Positive, Named);

   package Format_Vectors is new Ada.Containers.Vectors (Positive, Format_Run);

   type Edit is record
      Formats_Only : Boolean := False;
      Format_End : Position;
      Old_Formats, New_Formats : Format_Vectors.Vector;
      From      : Position;
      Removed   : Ada.Strings.Unbounded.Unbounded_String;
      Inserted  : Ada.Strings.Unbounded.Unbounded_String;
      Gone      : Named_Vectors.Vector;
      --  The paragraphs Removed's line feeds ended, which went.
      Made      : Named_Vectors.Vector;
      --  Those Inserted's started.
      Kind      : Edit_Kind := Other;
      Kind_Only : Boolean := False;
      Old_Kind, New_Kind : Paragraph_Kind := Plain;
      Old_Inset, New_Inset : Paragraph_Inset;
      --  Of From's paragraph, if Kind_Only (which is of its inset too).
   end record;
   --  Removed was replaced by Inserted, at From.

   package Edit_Vectors is new Ada.Containers.Vectors (Positive, Edit);

   type Step is record
      Edits : Edit_Vectors.Vector;
      Id    : Positive := 1;  --  the state it makes
   end record;

   package Step_Vectors is new Ada.Containers.Vectors (Positive, Step);

   package Change_Vectors is new Ada.Containers.Vectors (Positive, Change);

   type Document is new Ada.Finalization.Limited_Controlled with record
      Formats : Format_Vectors.Vector;
      Paragraphs : Paragraph_Vectors.Vector;
      Next_Id    : Paragraph_Id := 1;

      Undos      : Step_Vectors.Vector;
      Redos      : Step_Vectors.Vector;
      Last_State : Natural := 0;
      Depth      : Natural := 0;  --  of Begin_Step
      Joining    : Boolean := False;
      --  The next edit may join the last.

      Log        : Change_Vectors.Vector;
      Base       : Version := 0;  --  the version before Log's first
      Serial     : Positive := 1;
   end record;

   overriding procedure Initialize (Item : in out Document);
   overriding procedure Finalize (Item : in out Document);

end Texts.Documents;
