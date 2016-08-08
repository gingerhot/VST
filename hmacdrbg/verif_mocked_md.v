Require Import floyd.proofauto.
Import ListNotations.
Local Open Scope logic.
Require Import floyd.sublist.

Require Import hmacdrbg.hmac_drbg.
Require Import hmacdrbg.spec_hmac_drbg.

(*TEMPORARRY FIX TO DEAL WITH NAME SPACES*)

Axiom FINALNAME:_HMAC_Final = hmac._HMAC_Final. 
Axiom UPDATENAME:_HMAC_Update = hmac._HMAC_Update. 
Axiom INITNAME: _HMAC_Init = hmac._HMAC_Init. 
Axiom CTX_Struct: Tstruct hmac_drbg._hmac_ctx_st noattr = spec_hmac.t_struct_hmac_ctx_st.

Lemma body_md_get_size: semax_body HmacDrbgVarSpecs HmacDrbgFunSpecs
       f_mbedtls_md_get_size md_get_size_spec.
Proof. 
  start_function.
  forward.
Qed.

(*replaced by reference to (new) lemmas FULL_isptr and REP_isptr
Lemma derive_helper4: forall A B C D P, A  |-- !!P -> (A * B * C * D) |-- !!P.
Proof.
  intros.
  specialize (saturate_aux20 A (B * C * D) P True).
  intros.
  eapply derives_trans with (Q:=!!(P /\ True)).
  do 2 rewrite <- sepcon_assoc in H0.
  apply H0. assumption. entailer!. entailer.
Qed.*)

Lemma FULL_isptr k q:
  UNDER_SPEC.FULL k q = !!isptr q && UNDER_SPEC.FULL k q.
Proof.
unfold UNDER_SPEC.FULL. apply pred_ext; normalize.
+ Exists h. entailer.
  unfold spec_hmac.hmacstate_PreInitNull; normalize.
  rewrite data_at_isptr. normalize. 
+ Exists h. normalize.
Qed.

Lemma EMPTY_isptr q:
  UNDER_SPEC.EMPTY q = !!isptr q && UNDER_SPEC.EMPTY q.
Proof.
unfold UNDER_SPEC.EMPTY. apply pred_ext; normalize.
rewrite data_at__isptr. normalize. 
Qed.

Lemma REP_isptr abs q:
  UNDER_SPEC.REP abs q = !!isptr q && UNDER_SPEC.REP abs q.
Proof.
unfold UNDER_SPEC.REP. apply pred_ext; normalize.
+ Exists r. rewrite data_at_isptr with (p:=q). normalize.
+ Exists r. normalize.
Qed. 
(*
Lemma body_md_start: semax_body HmacDrbgVarSpecs (malloc_spec::HmacDrbgFunSpecs)
       f_mbedtls_md_hmac_starts md_starts_spec.
Proof.
  start_function. 

  destruct r as [r1 [r2 r3]]. simpl.
  rewrite EMPTY_isptr; Intros.
  unfold_data_at 1%nat.
  forward. 

  rewrite INITNAME, CTX_Struct.
Check (r3, l, key, kv, b, i).
Locate f_mbedtls_md_hmac_starts.
unfold UNDER_SPEC.EMPTY.
assert ().
(*Parameter hh:spec_hmac.hmacabs.*)
  forward_call (r3, l, key(*map Vint (map Int.repr key)*), kv, b, i). , Zlength key, key, kv, hh).
  Intros. normalize. (*FAIL*)
  apply extract_exists_pre. intros vret. (*SUCCESS*)
 
  forward_if (PROP () LOCAL (temp _sha_ctx vret; temp _md_info info; 
   temp _ctx c; temp _hmac h) 
      SEP (memory_block Tsh (sizeof (Tstruct _hmac_ctx_st noattr)) vret;
           data_at Tsh (Tstruct _mbedtls_md_context_t noattr) md_ctx c)).
  { destruct (Memory.EqDec_val vret nullval).
    + subst vret; entailer!.
    + eapply derives_trans; try apply valid_pointer_weak.
      apply sepcon_valid_pointer1.
      apply memory_block_valid_ptr. apply top_share_nonidentity. omega.
      entailer!. 
  }
  { (*null*) 
    subst vret. simpl. forward.
    Exists (-20864). entailer!. apply orp_right1. entailer!.
  }
  { destruct (eq_dec vret nullval); subst. elim H; trivial. clear n.
    forward. entailer!.
  }
  rewrite memory_block_isptr. Intros.
  unfold_data_at 1%nat.
  forward. forward. Exists 0. entailer!. apply orp_right2.
  Exists vret. unfold_data_at 1%nat. entailer!. 
Qed.

*)
Lemma body_md_update: semax_body HmacDrbgVarSpecs HmacDrbgFunSpecs
       f_mbedtls_md_hmac_update md_update_spec.
Proof.
  start_function. 
  
  unfold md_relate; unfold convert_abs.
  destruct r as [r1 [r2 internal_r]].
  simpl.
  rewrite REP_isptr; Intros. 

  (* HMAC_CTX * hmac_ctx = ctx->hmac_ctx; *)
  forward.

  (* HMAC_Update(hmac_ctx, input, ilen); *)
  rewrite data_at_isptr with (p:=d); Intros.
  destruct d; try contradiction.

  rewrite UPDATENAME, CTX_Struct.  
  forward_call (key, internal_r, Vptr b i, data, data1, kv).
  {
    unfold spec_sha.data_block.
    entailer!.
  }

  (* return 0 *)
  forward.

  (* prove the post condition *)
  unfold spec_sha.data_block.
  unfold md_relate; unfold convert_abs.
  entailer!.
Qed.

Lemma body_md_final: semax_body HmacDrbgVarSpecs HmacDrbgFunSpecs
       f_mbedtls_md_hmac_finish md_final_spec.
Proof.
  start_function.

  unfold md_relate; unfold convert_abs.
  destruct r as [r1 [r2 internal_r]].
  simpl.
  rewrite REP_isptr; Intros. 

  (* HMAC_CTX * hmac_ctx = ctx->hmac_ctx; *)
  forward.

  (* HMAC_Final(hmac_ctx, output); *)
  rewrite FINALNAME, CTX_Struct.
  forward_call (data, key, internal_r, md, shmd, kv).

  (* return 0 *)
  unfold spec_sha.data_block.
  forward.
  cancel.
Qed.

Lemma body_md_reset: semax_body HmacDrbgVarSpecs HmacDrbgFunSpecs
       f_mbedtls_md_hmac_reset md_reset_spec.
Proof.
  start_function.

  destruct r as [r1 [r2 internal_r]].
  simpl.
  rewrite FULL_isptr; Intros. 

  (* HMAC_CTX * hmac_ctx = ctx->hmac_ctx; *)
  forward.

  rewrite INITNAME, CTX_Struct.
  forward_call (internal_r, 32, key, kv).
  forward.

  unfold md_relate.
  unfold convert_abs.
  entailer!.
Qed.

Lemma body_md_setup: semax_body HmacDrbgVarSpecs (malloc_spec::HmacDrbgFunSpecs)
       f_mbedtls_md_setup md_setup_spec.
Proof.
  start_function.

  forward_call (sizeof (Tstruct _hmac_ctx_st noattr)).
  Intros. normalize. (*FAIL*)
  apply extract_exists_pre. intros vret. (*SUCCESS*)
 
  forward_if (PROP () LOCAL (temp _sha_ctx vret; temp _md_info info; 
   temp _ctx c; temp _hmac h) 
      SEP (!!field_compatible spec_hmac.t_struct_hmac_ctx_st [] vret &&
           memory_block Tsh (sizeof (Tstruct _hmac_ctx_st noattr)) vret;
           data_at Tsh (Tstruct _mbedtls_md_context_t noattr) md_ctx c)).
  { destruct (Memory.EqDec_val vret nullval).
    + subst vret; entailer!.
    + normalize. eapply derives_trans; try apply valid_pointer_weak.
      apply sepcon_valid_pointer1.
      apply memory_block_valid_ptr. apply top_share_nonidentity. omega.
      entailer!. 
  }
  { (*null*) 
    subst vret. simpl. forward.
    Exists (-20864). entailer!. simpl. cancel.
  }
  { destruct (eq_dec vret nullval); subst. elim H; trivial. clear n.
    forward. entailer!.
  }
  rewrite memory_block_isptr. Intros.
  unfold_data_at 1%nat.
  forward. forward. Exists 0. simpl. entailer!. 
  Exists vret. unfold_data_at 1%nat. entailer!. admit. (*new spec-needs insertion of filed assignment in code*) 
Admitted.