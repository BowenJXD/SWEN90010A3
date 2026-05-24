with Universe;
with Spatial;
with Vector; use Vector;
with Collision_Math;
with Display;
with Ada.Text_IO;
with Ada.Numerics.Big_Numbers.Big_Reals;
use Ada.Numerics.Big_Numbers.Big_Reals;

--  ============================================================
--  Task 1: Code Understanding
--  ============================================================
--
--  Question 1: Advantage of separate Position and Velocity types
--  -------------------------------------------------------------
--  Both Position and Velocity are derived from Vector.Vector, but Ada's
--  derived types are distinct: the compiler treats them as incompatible
--  and rejects any implicit conversion between them.
--
--  This prevents a whole class of unit-confusion bugs at compile time.
--  For example, consider Add_Item's signature:
--
--     procedure Add_Item (U : in out Universe;
--                         pos : Spatial.Position;
--                         vel : Spatial.Velocity; ...);
--
--  With separate types, accidentally swapping the arguments:
--
--     Univ.Add_Item (U, Initial_Velocities (1), Initial_Positions (1), r);
--                         ^^^^^^^^^^^^^^^^^^^^   ^^^^^^^^^^^^^^^^^^^
--                         Velocity passed as     Position passed as
--                         Position               Velocity
--
--  is a compile-time type error. If both parameters were Vector.Vector,
--  this compiles silently: the object starts with the wrong initial
--  position (the velocity value) and the wrong velocity (the position
--  value), producing incorrect simulation output with no error.
--
--  More generally, the type system prevents: passing a velocity to Move
--  twice, storing a computed displacement (a Vector) directly as a
--  Position without an explicit conversion, or using Negate_Vel_X on
--  a Position by mistake. Each of these would be a silent semantic error
--  if all three types were the same.
--
--  Question 2: Preconditions in universe.ads and why each is needed
--  ----------------------------------------------------------------
--  (a) Get_Position, Get_Velocity, Get_Radius, Reflect_Velocity_X, Reflect_Velocity_Y:
--        Pre => Index >= 1 and then Index <= Item_Count (U)
--      The backing array is declared as
--        items : array (1 .. Max_Items) of Universe_Item
--      but only indices 1 .. item_count are initialised. Without the
--      precondition, a caller could pass Index = 0 or any value greater
--      than item_count (up to or exceeding Max_Items), causing a
--      Constraint_Error (array index out of range) at runtime.
--
--  (b) Add_Item:
--        Pre => Item_Count (U) < Max_Items
--      The implementation increments item_count and then writes to
--      items (item_count). If item_count is already Max_Items,
--      incrementing it would exceed the Integer range 0 .. Max_Items
--      declared for the field, raising Constraint_Error. The write to
--      items (Max_Items + 1) would also be an out-of-bounds array
--      access, which is a second independent Constraint_Error.
--
--  ============================================================
--  Task 7: Reflection
--  ============================================================
--
--  The proof (Task 6) establishes that on every frame the simulation
--  actually executes, the squared distance between the two objects
--  strictly exceeds Pair_Sep2 -- that is, they are not currently
--  colliding. It does NOT guarantee that a collision would definitely
--  have occurred had the simulation continued past an early halt.
--
--  Will_Collide_Vec is a conservative over-approximation: it checks
--  whether the minimum squared distance along the infinite future
--  trajectory (treating velocities as constant forever) ever falls at
--  or below the threshold. In the real simulation, velocities change at
--  every bounce. The check is performed on the current straight-line
--  trajectory, so it may predict a "collision" that the next wall
--  bounce would have deflected the objects away from before it occurred.
--
--  Therefore the simulation can halt early even when no actual collision
--  would have taken place -- the system is sound (it never lets a real
--  collision through) but not complete (it may stop unnecessarily).
--  What the proof does guarantee is the contrapositive safety property:
--  every frame that is shown is provably collision-free.

procedure Main with SPARK_Mode is
   use type Spatial.Position;
   use type Spatial.Velocity;
   package Univ is new Universe (10);

   package FC is new Float_Conversions (Float);
   package Disp is new Display (Univ, Max_Frames => 5500);

   U : Univ.Universe;

   Arena_X_Min : constant Big_Real := FC.To_Big_Real (-100.0);
   Arena_X_Max : constant Big_Real := FC.To_Big_Real (100.0);
   Arena_Y_Min : constant Big_Real := FC.To_Big_Real (-50.0);
   Arena_Y_Max : constant Big_Real := FC.To_Big_Real (50.0);

   Initial_Positions : array (1 .. 2) of Spatial.Position :=
     (Spatial.To_Position
        ((X => FC.To_Big_Real (0.0), Y => FC.To_Big_Real (5.0))),
      Spatial.To_Position
        ((X => FC.To_Big_Real (0.0), Y => FC.To_Big_Real (-5.0))));

   Initial_Velocities : array (1 .. 2) of Spatial.Velocity :=
     (Spatial.To_Velocity
        ((X => FC.To_Big_Real (0.4), Y => FC.To_Big_Real (0.3))),
      Spatial.To_Velocity
        ((X => FC.To_Big_Real (1.0), Y => FC.To_Big_Real (-0.7))));

   Initial_Radii : constant array (1 .. 2) of Big_Real :=
     (FC.To_Big_Real (2.0), FC.To_Big_Real (2.0));

   Tick_Count : Big_Real := To_Big_Real (0);

   --  For each item I, position = Initial_Positions(I) + Initial_Velocities(I) * Tick_Count.
   --  Velocities and radii are pinned to their initial values between bounces.
   function Position_Invariant (U : Univ.Universe) return Boolean is
     (Univ.Item_Count (U) = 2
      and then Tick_Count >= To_Big_Real (0)
      and then (for all I in 1 .. 2 =>
        Univ.Get_Position (U, I) =
          Spatial.To_Position (
            Vector.Add (
              Spatial.To_Vector (Initial_Positions (I)),
              Vector.Scale (Spatial.Vel_To_Vector (Initial_Velocities (I)),
                            Tick_Count)))
        and then Univ.Get_Velocity (U, I) = Initial_Velocities (I)
        and then Univ.Get_Radius (U, I) = Initial_Radii (I)));

   function Squared_Dist
     (U : Univ.Universe; I, J : Integer) return Big_Real is
       (Vector.Dot
          (Vector.Sub
             (Spatial.To_Vector (Univ.Get_Position (U, I)),
              Spatial.To_Vector (Univ.Get_Position (U, J))),
           Vector.Sub
             (Spatial.To_Vector (Univ.Get_Position (U, I)),
              Spatial.To_Vector (Univ.Get_Position (U, J))))) with
      Pre => I >= 1 and then I <= Univ.Item_Count (U)
             and then J >= 1 and then J <= Univ.Item_Count (U);

   function Pair_Sep2
     (I, J : Integer) return Big_Real is
       ((Initial_Radii (I) + Initial_Radii (J)) *
        (Initial_Radii (I) + Initial_Radii (J))) with
      Pre => I in 1 .. 2 and J in 1 .. 2;

   function No_Future_Collision_Pair (I, J : Integer) return Boolean is
     (not Collision_Math.Will_Collide_Vec
        (Vector.Sub (Spatial.To_Vector (Initial_Positions (I)),
                     Spatial.To_Vector (Initial_Positions (J))),
         Vector.Sub (Spatial.Vel_To_Vector (Initial_Velocities (I)),
                     Spatial.Vel_To_Vector (Initial_Velocities (J))),
         Pair_Sep2 (I, J)))
   with Pre => I in 1 .. 2 and then J in 1 .. 2;

   procedure Lemma_No_Collision_Pair
     (U : Univ.Universe; I, J : Integer)
   with
     Ghost,
     Pre =>
       Position_Invariant (U)
       and then I in 1 .. 2
       and then J in 1 .. 2
       and then Tick_Count >= To_Big_Real (0)
       and then No_Future_Collision_Pair (I, J),
     Post => Squared_Dist (U, I, J) > Pair_Sep2 (I, J);

   procedure Lemma_No_Collision_Pair
     (U : Univ.Universe; I, J : Integer)
   is
      S : constant Vector.Vector :=
        Vector.Sub (Spatial.To_Vector (Initial_Positions (I)),
                    Spatial.To_Vector (Initial_Positions (J)));
      V : constant Vector.Vector :=
        Vector.Sub (Spatial.Vel_To_Vector (Initial_Velocities (I)),
                    Spatial.Vel_To_Vector (Initial_Velocities (J)));
      Eps2 : constant Big_Real := Pair_Sep2 (I, J);
   begin
      -- Check_Implies_Safe_Vec(S, V, Eps2, T)
      Collision_Math.Check_Implies_Safe_Vec (S, V, Eps2, Tick_Count);
      -- Lemma_Sq_Dist_Bridge(P1, P2, Init1, Init2, Vel1, Vel2, T)
      Collision_Math.Lemma_Sq_Dist_Bridge
        (Spatial.To_Vector (Univ.Get_Position (U, I)),
         Spatial.To_Vector (Univ.Get_Position (U, J)),
         Spatial.To_Vector (Initial_Positions (I)),
         Spatial.To_Vector (Initial_Positions (J)),
         Spatial.Vel_To_Vector (Initial_Velocities (I)),
         Spatial.Vel_To_Vector (Initial_Velocities (J)),
         Tick_Count);
   end Lemma_No_Collision_Pair;

   type Bounce_Flags is record
      X : Boolean := False;
      Y : Boolean := False;
   end record;

   type Bounce_Array is array (1 .. 2) of Bounce_Flags;

   function Detect_Bounces
     (U : Univ.Universe) return Bounce_Array
     with Pre => Univ.Item_Count (U) = 2;

   function Detect_Bounces
     (U : Univ.Universe) return Bounce_Array
   is
      Result : Bounce_Array := (others => (X => False, Y => False));
   begin
      for Item in 1 .. 2 loop
         declare
            P : constant Spatial.Position :=
              Univ.Get_Position (U, Item);
            R : constant Big_Real := Univ.Get_Radius (U, Item);
         begin
            if Spatial.Pos_X (P) + R > Arena_X_Max
              or else Spatial.Pos_X (P) - R < Arena_X_Min
            then
               Result (Item).X := True;
            end if;
            if Spatial.Pos_Y (P) + R > Arena_Y_Max
              or else Spatial.Pos_Y (P) - R < Arena_Y_Min
            then
               Result (Item).Y := True;
            end if;
         end;
      end loop;
      return Result;
   end Detect_Bounces;

   procedure Print_Collision (Frame : Integer);

   procedure Print_Collision (Frame : Integer)
     with SPARK_Mode => Off
   is
   begin
      Ada.Text_IO.Put_Line
        ("Collision will occur after bounce at frame"
         & Integer'Image (Frame));
      for Item in 1 .. 2 loop
         declare
            V : constant Vector.Vector :=
              Spatial.Vel_To_Vector (Initial_Velocities (Item));
            P : constant Spatial.Position :=
              Initial_Positions (Item);
         begin
            Ada.Text_IO.Put_Line
              ("  Item" & Integer'Image (Item)
               & " pos=("
               & To_String (Spatial.Pos_X (P)) & ", "
               & To_String (Spatial.Pos_Y (P)) & ")"
               & " vel=("
               & To_String (V.X) & ", "
               & To_String (V.Y) & ")");
         end;
      end loop;
      Ada.Text_IO.Put_Line
        ("  Sep2=" & To_String (Pair_Sep2 (1, 2)));
   end Print_Collision;

   procedure Reset_Universe
     with Post => Position_Invariant (U)
   is
   begin
      Tick_Count := To_Big_Real (0);
      Univ.Init (U);
      Univ.Add_Item (U,
                     Initial_Positions (1),
                     Initial_Velocities (1),
                     Initial_Radii (1));
      Univ.Add_Item (U,
                     Initial_Positions (2),
                     Initial_Velocities (2),
                     Initial_Radii (2));
   end Reset_Universe;

begin
   Reset_Universe;

   if not No_Future_Collision_Pair (1, 2) then
      Print_Collision (0);
      return;
   end if;

   for Frame in 1 .. 5000 loop
      pragma Loop_Invariant (Position_Invariant (U));
      pragma Loop_Invariant (No_Future_Collision_Pair (1, 2));

      Lemma_No_Collision_Pair (U, 1, 2);
      pragma Assert (Squared_Dist (U, 1, 2) > Pair_Sep2 (1, 2));

      Disp.Capture (U);
      Univ.Tick (U);
      Tick_Count := Tick_Count + To_Big_Real (1);

      declare
         Flags : constant Bounce_Array := Detect_Bounces (U);
      begin
         if Flags (1).X or else Flags (1).Y
           or else Flags (2).X or else Flags (2).Y
         then
            for Item in 1 .. 2 loop
               pragma Loop_Invariant (Univ.Item_Count (U) = 2);
               if Flags (Item).X then
                  Univ.Reflect_Velocity_X (U, Item);
               end if;
               if Flags (Item).Y then
                  Univ.Reflect_Velocity_Y (U, Item);
               end if;
            end loop;
            Initial_Positions :=
              (Univ.Get_Position (U, 1),
               Univ.Get_Position (U, 2));
            Initial_Velocities :=
              (Univ.Get_Velocity (U, 1),
               Univ.Get_Velocity (U, 2));

            Reset_Universe;

            if not No_Future_Collision_Pair (1, 2) then
               Print_Collision (Frame);
               return;
            end if;
         end if;
      end;
   end loop;

   Disp.Capture (U);
   Disp.Save ("simulation.html",
              Arena_X_Min, Arena_X_Max,
              Arena_Y_Min, Arena_Y_Max);
   Ada.Text_IO.Put_Line ("Wrote simulation.html");
end Main;
