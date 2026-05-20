with Ada.Text_IO; with Ada.Integer_Text_IO;

package body Universe with SPARK_Mode is

   use type Spatial.Position;
   use type Spatial.Velocity;

   procedure Init (U : out Universe) is
   begin
      U.item_count := 0;
      U.items := (others =>
                    (pos => Spatial.To_Position
                               ((X => To_Big_Real (0),
                                 Y => To_Big_Real (0))),
                     vel => Spatial.To_Velocity
                               ((X => To_Big_Real (0),
                                 Y => To_Big_Real (0))),
                     rad => To_Big_Real (0)));
   end Init;

   procedure Add_Item
     (U   : in out Universe;
      pos : Spatial.Position;
      vel : Spatial.Velocity;
      rad : Big_Real)
   is
   begin
      U.item_count := U.item_count + 1;
      U.items (U.item_count) := (pos => pos, vel => vel, rad => rad);
   end Add_Item;

   procedure Reflect_Velocity_X
     (U : in out Universe; Index : Integer) is
   begin
      U.items (Index).vel := Spatial.Negate_Vel_X (U.items (Index).vel);
   end Reflect_Velocity_X;

   procedure Reflect_Velocity_Y
     (U : in out Universe; Index : Integer) is
   begin
      U.items (Index).vel := Spatial.Negate_Vel_Y (U.items (Index).vel);
   end Reflect_Velocity_Y;

   procedure Print (U : Universe)
     with SPARK_Mode => Off
   is
   begin
      for I in U.items'First .. U.item_count loop
         Ada.Text_IO.Put ("Item: ");
         Ada.Integer_Text_IO.Put (I);
         Ada.Text_IO.Put (": pos: (");
         Ada.Text_IO.Put
           (To_String (Spatial.Pos_X (U.items (I).pos)));
         Ada.Text_IO.Put (",");
         Ada.Text_IO.Put
           (To_String (Spatial.Pos_Y (U.items (I).pos)));
         Ada.Text_IO.Put (")");
         Ada.Text_IO.New_Line;
      end loop;
   end Print;

   procedure Tick (U : in out Universe) is
   begin
      for I in 1 .. U.item_count loop
         pragma Loop_Invariant (U.item_count = U'Loop_Entry.item_count);
         pragma Loop_Invariant
           (for all J in 1 .. I - 1 =>
              U.items (J).pos =
                Spatial.Move (U'Loop_Entry.items (J).pos,
                              U'Loop_Entry.items (J).vel)
              and then U.items (J).vel = U'Loop_Entry.items (J).vel
              and then U.items (J).rad = U'Loop_Entry.items (J).rad);
         pragma Loop_Invariant
           (for all J in I .. U.item_count =>
              U.items (J).pos = U'Loop_Entry.items (J).pos
              and then U.items (J).vel = U'Loop_Entry.items (J).vel
              and then U.items (J).rad = U'Loop_Entry.items (J).rad);
         U.items (I).pos := Spatial.Move (U.items (I).pos, U.items (I).vel);
      end loop;
   end Tick;

end Universe;
