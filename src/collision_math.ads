with Ada.Numerics.Big_Numbers.Big_Reals;
use Ada.Numerics.Big_Numbers.Big_Reals;
with Vector;

package Collision_Math with SPARK_Mode is

   use type Vector.Vector;

   --  Vector-level collision check: given the position difference S
   --  and velocity difference V between two items, determines whether
   --  they will ever come within squared distance Eps2 of each other.
   function Will_Collide_Vec
      (S, V : Vector.Vector; Eps2 : Big_Real) return Boolean is
        (if Vector.Dot (V, V) = To_Big_Real (0)
            or else Vector.Dot (S, V) >= To_Big_Real (0)
         then Vector.Dot (S, S) <= Eps2
         else Vector.Dot (S, S) * Vector.Dot (V, V)
                - Vector.Dot (S, V) * Vector.Dot (S, V)
              <= Eps2 * Vector.Dot (V, V))
   with
      Pre => Eps2 >= To_Big_Real (0);

   --  Squared distance between two trajectories at time T,
   --  expressed in terms of their difference vectors S and V.
   --  ||S + T*V||^2
   function Sq_Dist_At_Vec
      (S, V : Vector.Vector; T : Big_Real) return Big_Real is
        (Vector.Dot (S, S)
         + To_Big_Real (2) * T * Vector.Dot (S, V)
         + T * T * Vector.Dot (V, V));

   --  The PDF theorem at vector level: if Will_Collide_Vec says
   --  "no collision" then the squared distance exceeds Eps2 at
   --  every future time T >= 0.
   procedure Check_Implies_Safe_Vec
      (S, V : Vector.Vector; Eps2, T : Big_Real)
   with
      Ghost,
      Pre  => Eps2 >= To_Big_Real (0) and then T >= To_Big_Real (0)
              and then not Will_Collide_Vec (S, V, Eps2),
      Post => Sq_Dist_At_Vec (S, V, T) > Eps2;

   --  Bridge lemma: if two positions are the linear evolution of
   --  their initial positions under constant velocities, then
   --  the squared distance between them equals Sq_Dist_At_Vec
   --  applied to the position and velocity differences.
   procedure Lemma_Sq_Dist_Bridge
      (P1, P2, Init1, Init2, Vel1, Vel2 : Vector.Vector;
       T : Big_Real)
   with
      Ghost,
      Pre  => P1 = Vector.Add (Init1, Vector.Scale (Vel1, T))
              and then P2 = Vector.Add (Init2, Vector.Scale (Vel2, T)),
      Post => Vector.Dot
                (Vector.Sub (P1, P2), Vector.Sub (P1, P2))
              = Sq_Dist_At_Vec
                  (Vector.Sub (Init1, Init2),
                   Vector.Sub (Vel1, Vel2), T);

end Collision_Math;
