(** * Relating axiomatic SC semantics to the Erased machine (operational SC) *)

Require Import concurrency.Machine_ax.
Require Import concurrency.Executions_ax.
Require Import Coq.Sets.Ensembles.
Require Import Coq.Relations.Relations.
Require Import concurrency.Ensembles_util.


(** This proof is done in two steps:
    1. Valid SC executions ([validSC]) generated by the axiomatic semantics
       [step_po] are related to valid SC executions generated by an intermediate
       axiomatic semantics that follow the [sc] order instead.
    2. The intermediate axiomatic semantics are related to the operational
       SC semantics. *)

(** * Part 1 *)
Module AxiomaticIntermediate.

  Import Execution.
  Import ValidSC.
  Import AxSem.

  Section AxiomaticIntermediate.
    Context
      {lbl : Labels}
      {sem : Semantics}
      {threadpool : ThreadPool C}
      {genv : G}
      {exec : Execution}
      {po sc : relation id}.

    Variable cstep: G -> C ->  C -> list E -> Prop.

    Notation " '[' tp1 , Ex1 ']'   '==>{' n  '}'  '[' tp2 , Ex2 ']' " :=
      (stepN (Rstep cstep genv po sc) n tp1 Ex1 tp2 Ex2) (at level 40).

    Notation " '[' tp1 , Ex1 ']'  '==>po' '[' tp2 , Ex2 ']' " :=
      (step_po cstep genv po tp1 Ex1 tp2 Ex2) (at level 40).

    Notation " '[' tp1 , Ex1 ']'  '==>sc' '[' tp2 , Ex2 ']' " :=
      (Rstep cstep genv po sc tp1 Ex1 tp2 Ex2) (at level 40).

    Notation "tp1 '[' i , ls ']==>' tp2" :=
      (AxSem.step cstep genv tp1 i ls tp2) (at level 40).
    
    Record sim (n:nat) (Ex : events) (tp1 : t) (Ex1 : events) (tp2 : t) (Ex2 : events) :=
      { set_dis  : Disjoint _ Ex1 Ex2;
        set_inv  : Ex <--> Union _ Ex1 Ex2;
        sc_steps : [tp2, Ex2] ==>{n} [tp1, Empty_set _];
        ex_po    : forall e2, e2 \in Ex2 ->
                               forall e1, e1 \in Ex1 ->
                                            ~ po e1 e2;
        sc_tot   : strict_total_order sc Ex;
        po_sc    : inclusion _ po sc
      }.


    Lemma enumerate_In:
      forall {A:Type} R es es' e
        (Henum: enumerate R es es'),
        List.In e es' <-> In A es e.
    Proof.
      intros.
      induction Henum.
      - simpl.
        split; intros HIn;
          [now exfalso | inv HIn].
      - simpl.
        split; intros HIn.
        destruct HIn; subst;
          [now eauto | now exfalso].
        inversion HIn;
          now auto.
      - destruct IHHenum as [IHHIn IHHIn'].
        split; intros HIn.
        + apply List.in_inv in HIn.
          destruct HIn; subst;
            now eauto with Ensembles_DB.
        + apply In_Union_inv in HIn.
          destruct HIn as [HIn | HIn];
            [right; now eauto| inv HIn; left; reflexivity].
    Qed.

    Lemma enumerate_spec:
      forall {A:Type} R es es' es'' e e'
        (Htrans: transitive A R)
        (Henum: enumerate R es (es' ++ (e::nil) ++ es'')) 
        (HIn: List.In e' es''),
        R e e'.
    Proof.
      intros A R es es'.
      generalize dependent es.
      induction es'; intros; simpl in Henum.
      - destruct es''.
        simpl in HIn; now exfalso.
        simpl in HIn.
        destruct HIn; subst.
        inv Henum. now eapply HR.
        generalize dependent es.
        generalize dependent a.
        generalize dependent e.
        induction es''; intros.
        + simpl in H; now exfalso.
        + inv Henum.
          simpl in H.
          destruct H; subst.
          * inv Henum0.
            eapply Htrans;
              [now apply HR | now apply HR0].
          * eapply Htrans;
              [now apply HR| now eauto].
      - destruct es'.
        + simpl in *.
          inv Henum.
          now eauto.
        + inv Henum.
          eapply (IHes' _ _ _ _ Htrans Henum0 HIn).
    Qed.

    Import PeanoNat.Nat.

    (** Not in [po] implies different threads *)
    Lemma no_po_thread_neq:
      forall e e'
        (Hneq: e <> e')
        (HpoWF: po_well_formed po)
        (Hpo1: ~ po e e')
        (Hpo2: ~ po e' e),
        thread e <> thread e'.
    Proof.
      intros.
      destruct (eq_dec (thread e) (thread e')) as [Htid_eq | Htid_neq];
        [destruct (po_same_thread _ HpoWF _ _ Htid_eq);
         now auto | assumption].
    Qed.

    (** Not in po implies that events are not related by Spawn *)
    Lemma no_po_spawn_neq:
      forall e e' es
        (Hneq: e <> e')
        (HpoWF: po_well_formed po)
        (Hpo1: ~ po e e')
        (Hpo2: ~ po e' e)
        (Henum: forall e'', List.In e'' es -> po e e''),
        ~ List.In (Spawn (thread e')) (List.map lab (e :: es)).
    Proof.
      intros.
      intros Hcontra.
      (** Since there was a [Spawn (thread e')] event in the trace (say e''),
              it is the case that (e'', e') \in po and (e, e'') \in po? *)
      assert (He'': lab e = Spawn (thread e') \/
                    exists e'', List.In e'' es /\ lab e'' = Spawn (thread e')).
      { clear - Hcontra.
        simpl in Hcontra.
        destruct Hcontra.
        eauto.
        right.
        apply List.in_map_iff in H.
        destruct H as [? [? ?]]; eexists; eauto.
      }
      destruct He'' as [? | [e'' [HIn Heq]]]; [destruct HpoWF; now eauto|].
      pose proof (po_spawn _ HpoWF _ _ Heq).
      specialize (Henum _ HIn).
      apply Hpo1.
      eapply trans;
        now eauto with Relations_db Po_db.
    Qed.

    (** ThreadPool invariant with respect to thread of event e' when
            thread of event e steps and the two events are not in [po]. *)
    Lemma no_po_gsoThread:
      forall e e' es tp tp'
        (Hneq: e <> e')
        (HpoWF: po_well_formed po)
        (Hpo1: ~ po e e')
        (Hpo2: ~ po e' e)
        (Henum: forall e'', List.In e'' es -> po e e'') 
        (Hstep: tp [thread e, List.map lab (e :: es) ]==> tp'),
        getThread (thread e') tp' = getThread (thread e') tp.
    Proof.
      intros.
      assert (Htid_neq: thread e <> thread e')
        by (eapply no_po_thread_neq; eauto).
      inv Hstep;
        try (erewrite gsoThread; now eauto).
      (** Spawn thread case*)
      erewrite! gsoThread; eauto.
      intros Hcontra; subst.
      eapply no_po_spawn_neq with (e' := e') (e := e);
        eauto.
      simpl (List.map lab (e :: es)).
      rewrite <- H0.
      apply List.in_or_app;
        simpl; now eauto.
    Qed.

    Lemma step_gsoThread:
      forall e e' es tp tp'
        (Hneq: thread e <> thread e')
        (Hspawn:  ~ List.In (Spawn (thread e')) (List.map lab (e :: es)))
        (Hstep: tp [thread e, List.map lab (e :: es) ]==> tp'),
        getThread (thread e') tp' = getThread (thread e') tp.
    Proof.
      intros.
      inv Hstep;
        try (erewrite gsoThread; now eauto).
      (** Spawn thread case*)
      erewrite! gsoThread; eauto.
      intros Hcontra; subst.
      apply Hspawn.
      simpl (List.map lab (e :: es)).
      rewrite <- H0.
      apply List.in_or_app;
        simpl; now eauto.
    Qed.

    (** [step] is invariant to [updThread] when the thread updated is
                not the stepping thread or a thread spawned by the stepping thread *)
    Lemma step_updThread:
      forall tp e es tp' e' c'
        (Hneq: thread e <> thread e')
        (Hspawn: ~List.In (Spawn (thread e')) (List.map lab (e :: es)))
        (Hstep: tp [thread e, List.map lab (e :: es)]==> tp'),
        updThread (thread e') c' tp [thread e, List.map lab (e :: es)]==>
                  updThread (thread e') c' tp'.
    Proof.
      intros.
      inv Hstep.
      - simpl. rewrite <- H0.
        erewrite updComm by eauto.
        econstructor; eauto.
        erewrite gsoThread by eauto.
        assumption.
      - simpl. rewrite <- H0.
        erewrite updComm by eauto.
        econstructor 2; eauto.
        erewrite gsoThread by eauto;
          eassumption.
      - simpl. rewrite <- H0.
        assert (j <> thread e').
        { intros Hcontra.
          subst.
          clear - H0 Hspawn.
          apply Hspawn; auto.
          simpl (List.map lab (e :: es)).
          rewrite <- H0.
          eapply List.in_or_app; simpl;
            now eauto.
        }
        assert (j <> thread e)
          by (intros Hcontra;
              subst; congruence). 
        assert (Hupd: updThread j c'' (updThread (thread e) c'0 tp) =
                      updThread (thread e) c'0 (updThread j c'' tp))
          by (erewrite updComm; eauto).
        rewrite Hupd.
        erewrite updComm by eauto.
        assert (Hupd': updThread j c'' (updThread (thread e') c' tp) =
                       updThread (thread e') c' (updThread j c'' tp))
          by (erewrite updComm; eauto).
        rewrite <- Hupd'.
        erewrite updComm by eauto.
        econstructor 3; eauto.
        erewrite gsoThread by eauto;
          eassumption.
        erewrite gsoThread by eauto;
          assumption.
    Qed.
    
    Lemma commute_step_sc:
      forall tp Ex Ex' tp' es e' es' tp''
        (HstepSC: [tp, Ex] ==>sc [tp', Ex'])
        (Hstep: tp' [thread e', List.map lab (e' :: es')]==> tp'')
        (Henum: enumerate po es (e' :: es')%list)
        (Hdisjoint: Disjoint _ es Ex)
        (HminSC: forall e, e \in Ex -> sc e' e)
        (Hpo: forall e, e \in Ex -> ~ po e' e)
        (HpoWF: po_well_formed po)
        (HscPO: strict_partial_order sc)
        (Hposc: inclusion _ po sc),
      exists tp0,
        [tp, Union _ Ex es] ==>sc [tp0, Ex] /\
        [tp0, Ex] ==>sc [tp'', Ex'].
    Proof.
      intros.
      inv HstepSC.
      assert (HIn0: In _ es0 e'0)
        by (eapply enumerate_In; eauto; simpl; auto).
      (** e'0 <> e' *)
      assert (Hneq_ev: e'0 <> e').
      { intros Hcontra; subst.
        apply Disjoint_sym in Hdisjoint.
        apply Disjoint_Union_r in Hdisjoint.
        inversion Hdisjoint as [Hdisjoint'].
        specialize (Hdisjoint' e').
        apply Hdisjoint'.
        eapply enumerate_In with (e := e') in Henum0.
        eapply enumerate_In with (e := e') in Henum.
        simpl in Henum, Henum0.
        pose proof (proj1 Henum0 ltac:(auto)).
        pose proof (proj1 Henum ltac:(auto)).
        eauto with Ensembles_DB.
      }
      (** ~ po e'0 e *)
      assert (Hnot_po1: ~po e'0 e').
      { specialize (HminSC e'0 ltac:(eauto with Ensembles_DB)).
        intros Hcontra.
        apply Hposc in Hcontra.
        pose proof (antisym _ HscPO _ _ Hcontra HminSC).
        subst.
        eapply (strict _ HscPO);
          now eauto.
      }
      (** Every element in es'0 is po-after e'0 by the spec of [enumerate]*)
      assert (Henum_spec: forall e'' : id, List.In e'' es'0 -> po e'0 e'')
        by (intros;
            eapply @enumerate_spec with (es := es0) (es' := nil);
            simpl; eauto with Po_db Relations_db).

      (** The state of (thread e') is unchanged by the step of (thread e'0) *)
      assert (Hget_e': getThread (thread e') tp'= getThread (thread e') tp)
        by (eapply no_po_gsoThread with (e := e'0) (e' := e'); eauto).
  
      (** [tp''] is tp' with the update that's caused by the step of thread e' (OUTDATED) *)
      (** First prove commutativity for program steps *)
      assert (exists tp0, tp [thread e', List.map lab (e' :: es')]==> tp0 /\
                     tp0 [thread e'0, List.map lab (e'0 :: es'0)]==> tp'').
      { inv Hstep.
        - exists (updThread (thread e') c' tp).
          split.
          + simpl. rewrite <- H0.
            econstructor; eauto.
            rewrite <- Hget_e'.
            assumption.
          + simpl.
            apply step_updThread;
              eauto using no_po_thread_neq, no_po_spawn_neq.
        - exists (updThread (thread e') c' tp).
          split.
          + simpl. rewrite <- H0.
            econstructor 2; eauto.
            rewrite <- Hget_e'.
            assumption.
          + simpl.
            apply step_updThread;
              eauto using no_po_thread_neq, no_po_spawn_neq.
        - (* RETURN HERE FOR SPAWN CASE *)
      
      tp''[e] = tp'[e].


      assert (tp [thread e', List.map lab (e' :: es')]==> updThread (thread e') 
      inv Hstep.

          
      inversion HstepSC; subst.

      assert 


      Lemma step_gsoThread:
        forall tp i ev tp' j
          (Hstep: tp [i, es]==> tp')


      Notation " c '[' ls ']'-->' c' " :=
        (tstep genv po sc tp1 Ex1 tp2 Ex2) (at level 40).
          
    Lemma commute_sc:
      forall n tp Ex es e' es' tp' Ex' tp''
        (Hsc_steps: [tp, Ex] ==>{n} [tp', Ex'])
        (Hp_step: tp' [thread e', List.map lab (e' :: es')]==> tp'')
        (Henum: enumerate po es (e' :: es'))
        (Hmin: e' \in min sc (Union _ Ex es))
        (Hincl: inclusion id po sc)
        (Hdis: Disjoint _ Ex es),
        [tp, Union _ Ex es] ==>{S n} [tp'', Ex'].
    Proof.
      intro n.
      induction n; intros.
      - (** Base case *)
        inv Hsc_steps.
        eapply StepN with (x1 := tp') (y1 := Union _ Ex' es)
                                      (x2 := tp'') (y2 := Ex');
          simpl.
        eapply @RStep; eauto.
        now constructor.
      - (** Inductive case *)
        inversion Hsc_steps as [|? ? ? tp0 Ex0 ? ?]; subst.
        assert (e' \in (min sc (Union _ Ex0 es)))
          by admit.
        assert (Disjoint _ Ex0 es)
          by admit.
        specialize (IHn _ _ _ _ _ _ _ _ HRstepN' Hp_step Henum H Hincl H0).



        specialize (IHn _ 
                        
        econstructor.
        
    Lemma step_po_sim:
      forall n Ex tp1 Ex1 tp2 Ex2 tp1' Ex1'
        (Hsim: sim n Ex tp1 Ex1 tp2 Ex2)
        (Hstep_po: (tp1, Ex1) ==>po (tp1', Ex1')),
      exists G2',
        sim n Ex tp1' Ex1' tp2 G2'.
    Proof.
      intros.
      assert (HstepsSC := steps _ _ _ _ _ _ Hsim).
      inv Hstep_po.


      Lemma steps_sc_split_at:
        forall n tp1 Ex1 tp2 Ex2 e
          (Hsteps_sc: (tp1, Ex1) ==>{n} (tp2, Ex2))
....          


      


    (* Goal *)
    Theorem axiomaticToIntermediate:
      forall n tp tp' Ex
        (Hexec: Rsteps cstep genv po po n (tp, Ex) (tp', Empty_set _))
        (Hvalid: validSC Ex po sc),
        Rsteps cstep genv po sc n (tp, Ex) (tp', Empty_set _).
    Proof.
      Admitted.

  
