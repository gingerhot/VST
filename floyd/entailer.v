Require Import floyd.base.
Require Import floyd.assert_lemmas.
Require Import floyd.client_lemmas.
Local Open Scope logic.


Lemma and_solvable_left:
 forall P Q : Prop,   P -> (P /\ Q) = Q.
Proof. intros. apply prop_ext; intuition. Qed.

Ltac and_solvable_left_aux1 :=
  match goal with |- _ /\ _ => fail 1 | |- _ => solve [auto] end.

Lemma and_solvable_right:
 forall Q P : Prop,   Q -> (P /\ Q) = P.
Proof. intros. apply prop_ext; intuition. Qed.

Ltac and_solvable_left P :=
 match P with
  | ?P1 /\ ?P2 => try rewrite (and_solvable_left P1) by auto;
                           and_solvable_left P2
  | _ => match P with
             | _ /\ _ => fail 1 
             | _ => first [ rewrite (and_solvable_right P) by auto
                                | rewrite (prop_true_andp' P) by auto
                                | apply (prop_right P); solve [auto]
                                | idtac
                                ]
             end
  end.

Ltac entailer' :=
 autorewrite with gather_prop;
 repeat ((simple apply go_lower_lem1 || apply derives_extract_prop || apply derives_extract_prop'); intro);
 subst_any;
 match goal with
 |  |- _ |-- _ =>
   repeat rewrite <- sepcon_assoc;
   saturate_local;  subst_any; 
   change SEPx with SEPx'; unfold PROPx, LOCALx, SEPx', local, lift1;
   unfold_lift; simpl;
   autorewrite with gather_prop;
   normalize; saturate_local;
   autorewrite with gather_prop;
   repeat rewrite and_assoc';
   match goal with 
   | |- _ |-- !! ?P && _ => and_solvable_left P
   | |- _ |-- !! ?P => and_solvable_left P; 
                               prop_right_cautious; try apply TT_right
   | |- _ => idtac
   end;
   auto
 | |- _ => normalize
 end.

Ltac entailer :=
 match goal with
 | |- PROPx _ _ |-- _ => 
       go_lower; 
       match goal with |- _ |-- _ => entailer' 
                                 | |- _ => idtac 
       end
 | |- _ |-- _ => entailer'
 | |- _ => fail "The entailer tactic works only on entailments   _ |-- _ "
 end.

Tactic Notation "entailer" "!" := 
  entailer; 
    first [simple apply andp_right; [apply prop_right | cancel ]
           | apply prop_right
           | cancel
           | idtac ].

Lemma ptr_eq_True:
   forall p, is_pointer_or_null p -> ptr_eq p p = True.
Proof. intros.
 apply prop_ext; intuition. destruct p; inv H; simpl; auto.
 rewrite Int.eq_true. auto.
Qed.
Hint Rewrite ptr_eq_True using assumption : norm.

Lemma flip_lifted_eq:
  forall (v1: environ -> val) (v2: val),
    `eq v1 `v2 = `(eq v2) v1.
Proof.
intros. unfold_lift. extensionality rho. apply prop_ext; split; intro; auto.
Qed.
Hint Rewrite flip_lifted_eq : norm.

(************** TACTICS FOR GENERATING AND EXECUTING TEST CASES *******)

Definition EVAR (x: Prop) := x.
Lemma EVAR_e: forall x, EVAR x -> x. 
Proof. intros. apply H. Qed.

Ltac no_evars := match goal with |- ?A => (has_evar A; fail 1) || idtac end.


Ltac gather_entail :=
repeat match goal with
 | A := _ |- _ =>  clear A || (revert A; no_evars)
 | H : ?P |- _ =>
  match type of P with
  | Prop => match P with name _ => fail 2 | _ => revert H; no_evars end
  | _ => clear H || (revert H; no_evars)
  end
end;
repeat match goal with 
 | x := ?X |- _ => is_evar X; clearbody x; revert x; apply EVAR_e
end;
repeat match goal with
  | H : name _ |- _ => revert H
 end.

Lemma admit_dammit : forall P, P.
Admitted.

Lemma EVAR_i: forall P: Prop, P -> EVAR P.
Proof. intros. apply H. Qed.

Ltac ungather_entail :=
match goal with
  | |- EVAR (forall x : ?t, _) => 
       let x' := fresh x in evar (x' : t);
       let x'' := fresh x in apply EVAR_i; intro x'';
       replace x'' with x'; [ungather_entail; clear x'' | apply admit_dammit ]
  | |- _ => intros
 end.

