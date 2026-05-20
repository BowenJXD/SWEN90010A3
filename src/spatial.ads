with Ada.Numerics.Big_Numbers.Big_Reals;
use Ada.Numerics.Big_Numbers.Big_Reals;
with Vector;

package Spatial with SPARK_Mode is

   type Position is private;
   type Velocity is private;

   function Pos_X (P : Position) return Big_Real;
   function Pos_Y (P : Position) return Big_Real;

   function To_Position (V : Vector.Vector) return Position;
   function To_Velocity (V : Vector.Vector) return Velocity;

   function To_Vector (P : Position) return Vector.Vector;
   function Vel_To_Vector (V : Velocity) return Vector.Vector;

   function Move (P : Position; V : Velocity) return Position;

   function Negate_Vel_X (V : Velocity) return Velocity;

   function Negate_Vel_Y (V : Velocity) return Velocity;

private
   type Position is new Vector.Vector;
   type Velocity is new Vector.Vector;

   --  Expression functions so the prover can see through these
   function Pos_X (P : Position) return Big_Real is
     (Vector.Vector (P).X);

   function Pos_Y (P : Position) return Big_Real is
     (Vector.Vector (P).Y);

   function To_Position (V : Vector.Vector) return Position is
     (Position (V));

   function To_Velocity (V : Vector.Vector) return Velocity is
     (Velocity (V));

   function To_Vector (P : Position) return Vector.Vector is
     (Vector.Vector (P));

   function Vel_To_Vector (V : Velocity) return Vector.Vector is
     (Vector.Vector (V));

   function Move (P : Position; V : Velocity) return Position is
     (Position (Vector.Add (Vector.Vector (P), Vector.Vector (V))));

   function Negate_Vel_X (V : Velocity) return Velocity is
     (Velocity (Vector.Vector'(X => To_Big_Real (0) - Vector.Vector (V).X,
                                Y => Vector.Vector (V).Y)));

   function Negate_Vel_Y (V : Velocity) return Velocity is
     (Velocity (Vector.Vector'(X => Vector.Vector (V).X,
                                Y => To_Big_Real (0) - Vector.Vector (V).Y)));

end Spatial;
